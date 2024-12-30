const std = @import("std");
const enc = @import("m68k/cpu/enc.zig");
const cpu_testing = @import("m68k/cpu/testing.zig");

pub const cpu = @import("m68k/cpu/cpu.zig");

// Goes through reset procedure
pub fn reset(state: *cpu.State) void {
    state.pending_exception = @intFromEnum(cpu.Vector.reset);
    state.handleException();
}

// Run one instruction (and potentially handle exceptions (but not run their code))
pub fn runInstr(state: *cpu.State) void {
    if (state.halted) return;
    @setEvalBranchQuota(256 * 256);
    
    // Generate table of lut bytes to instruction functions
    const LutEntry = struct {
        instr: type,
        args: comptime_int,
    };
    const lut_to_instr: [0x100]?LutEntry = comptime blk: {
        var lut = [1]?LutEntry{null} ** 0x100;
        var iter = InstrIterator.init();
        var instr = iter.next();
        while (instr != void) : (instr = iter.next()) {
            const Args = InstrArgs(instr);
            for (0..1 << Args.numBits()) |permutation| {
                // See if we can even encode this
                if (Args.fromPacked(permutation)) |_| {
                    lut[iter.base + permutation] = .{
                        .instr = instr,
                        .args = permutation,
                    };
                }
            }
        }
        break :blk lut;
    };
    
    // Handle exceptions generated since last instruction
    state.handleException();
    
    // Get lut byte from instruction word and jump to instruction function (with comptime args)
    switch (decode_lut[state.ir]) {
        inline else => |lut_byte| {
            if (lut_to_instr[lut_byte]) |info| {
                info.instr.run(state, comptime InstrArgs(info.instr).fromPacked(info.args).?.args);
            } else {
                state.pending_exception = @intFromEnum(cpu.Vector.illegal_instr);
            }
        }
    }
}

// Get compile time instruction arguments from instruction type and first word
fn InstrArgs(comptime instr: type) type {
    const Args = instr.ComptimeArgs;
    const Encoding = instr.Encoding;
    
    return struct {
        args: Args,
        
        const Self = @This();
        const Bits = std.meta.Int(.unsigned, Self.numBits());
        const ShiftAmount = std.math.Log2Int(Bits);
        
        // Initialize from raw bits
        fn fromPacked(comptime all_bits: Bits) ?Self {
            var args: Args = undefined;
            var bits = all_bits;
            for (std.meta.fields(Args)) |field| {
                const arg = @as(enc.ToInt(field.type), @truncate(bits));
                @field(args, field.name) = switch (@typeInfo(field.type)) {
                    .Enum => blk: {
                        if (std.meta.intToEnum(field.type, arg)) |e| {
                            break :blk e;
                        } else |_| {
                            return null;
                        }
                    },
                    else => @bitCast(arg),
                };
                bits >>= @as(ShiftAmount, @truncate(@bitSizeOf(field.type)));
            }
            return .{ .args = args };
        }
        
        // Create the arguments from the encoding
        fn fromEncoding(comptime encoding: Encoding) Self {
            var args: Args = undefined;
            for (std.meta.fields(Args)) |field| {
                @field(args, field.name) = @field(encoding, field.name);
            }
            return .{ .args = args };
        }
        
        // Get the packed version back
        fn toPacked(comptime self: Self) Bits {
            var bits: Bits = 0;
            for (std.meta.fields(Args)) |field| {
                const field_val = @field(self.args, field.name);
                const as_bits: enc.ToInt(field.type) = switch (@typeInfo(field.type)) {
                    .Enum => @intFromEnum(field_val),
                    else => @bitCast(field_val),
                };
                bits <<= @as(ShiftAmount, @truncate(@bitSizeOf(field.type)));
                bits |= as_bits;
            }
            return bits;
        }
        
        // Get number of bits needed to represent this argument
        fn numBits() comptime_int {
            var bits = 0;
            for (std.meta.fields(Args)) |field| bits += @bitSizeOf(field.type);
            return bits;
        }
    };
}

// Iterates over instructions
const InstrIterator = struct {
    instr: comptime_int,
    base: u8,
    
    fn init() InstrIterator {
        return .{
            .instr = -1,
            .base = 0,
        };
    }
    
    fn next(self: *InstrIterator) type {
        // Get by how much we need to advance base
        if (self.instr >= 0 and self.instr < instrs.len) {
            const instr = instrs[self.instr];
            self.base += 1 << InstrArgs(instr).numBits();
        }
        
        // Now advance instr and return
        self.instr += 1;
        if (self.instr < instrs.len) {
            return instrs[self.instr];
        } else {
            return void;
        }
    }
};

// Cpu instruction decode lookup table
// If you index the table by the first word of an instruction, it gives you the correct run function
// to run for the instruction. Index 0xFF is for invalid instruction encodings and should run the
// illegal instruction exception handler.
const decode_lut: [0x10000]u8 = compute_lut: {
    var lut = [1]u8{0xFF} ** 0x10000;
    @setEvalBranchQuota(lut.len * 256);
    
    var iter = InstrIterator.init();
    while (true) {
        const instr = iter.next();
        if (instr == void) break;
        
        if (@bitSizeOf(instr.Encoding) != 16) {
            @compileError("instruction encodings must be 16 bits!");
        }
        for (0..lut.len) |i| {
            const word: u16 = i;
            if (!enc.matchChildren(instr.Encoding, word)) continue;
            const encoding: instr.Encoding = @bitCast(word);
            lut[i] = iter.base + InstrArgs(instr).fromEncoding(encoding).toPacked();
        }
    }
    break :compute_lut lut;
};

test "Instructions" {
    var bus = cpu_testing.Bus{};
    var state = cpu.State.init(&bus);
    
    inline for (instrs) |instr| {
        // Write program
        @memset(&bus.bytes, 0);
        bus.wr32(0, 0x100); // Write stack pointer address
        bus.wr32(4, 0x8); // Write program start address
        var addr: u24 = 8;
        
        // Write program code
        for (instr.Tester.code) |word| {
            bus.wr16(addr, word);
            addr += 2;
        }
        
        // Reset and validate instruction
        reset(&state);
        state.cycles = 0;
        while (state.regs.pc <= 8 + instr.Tester.code.len * 2 and !state.halted) {
            runInstr(&state);
        }
        try instr.Tester.validate(&state);
    }
}

// List of cpu instructions (as types of structs)
const instrs = .{
    @import("m68k/abcd.zig"),
    @import("m68k/add_to_dn.zig"),
    //@import("m68k/add_to_ea.zig"),
    //@import("m68k/adda.zig"),
    //@import("m68k/addi.zig"),
    //@import("m68k/addq.zig"),
    //@import("m68k/addx.zig"),
    //@import("m68k/and_to_dn.zig"),
    //@import("m68k/and_to_ea.zig"),
    //@import("m68k/andi.zig"),
    //@import("m68k/andi_to_ccr.zig"),
    //@import("m68k/asd_reg.zig"),
    //@import("m68k/asd_mem.zig"),
    //@import("m68k/b_cc.zig"),
    //@import("m68k/bchg_reg.zig"),
    //@import("m68k/bchg_imm.zig"),
};
