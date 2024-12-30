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
        variant: comptime_int,
    };
    const lut_to_instr: [0x100]?LutEntry = comptime blk: {
        var lut = [1]?LutEntry{null} ** 0x100;
        var iter = InstrIterator.init();
        var instr = iter.next();
        while (instr != void) : (instr = iter.next()) {
            const Variant = instr.Variant;
            for (0..1 << @bitSizeOf(Variant)) |permutation| {
                // See if we can even encode this
                if (!validatePackedStruct(Variant, permutation)) continue;
                lut[iter.base + permutation] = .{
                    .instr = instr,
                    .variant = permutation,
                };
            }
        }
        break :blk lut;
    };

    // Handle exceptions generated since last instruction
    state.handleException();

    // Get lut byte from instruction word and jump to instruction function (with comptime variant)
    switch (decode_lut[state.ir]) {
        inline else => |lut_byte| {
            if (lut_to_instr[lut_byte]) |info| {
                const bits: AsInt(info.instr.Variant) = comptime info.variant;
                info.instr.run(state, @bitCast(bits));
            } else {
                state.pending_exception = @intFromEnum(cpu.Vector.illegal_instr);
            }
        },
    }
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
            self.base += 1 << @bitSizeOf(instr.Variant);
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

fn AsInt(comptime T: type) type {
    return std.meta.Int(.unsigned, @bitSizeOf(T));
}

// Create the arguments from the encoding
fn encodingToVariant(comptime instr: type, comptime encoding: anytype) instr.Variant {
    var variant: instr.Variant = undefined;
    for (std.meta.fields(instr.Variant)) |field| {
        @field(variant, field.name) = @field(encoding, field.name);
    }
    return variant;
}

// Makes sure that the packed struct can be represented by bits
fn validatePackedStruct(comptime T: type, bits: comptime_int) bool {
    var idx = 0;
    for (std.meta.fields(T)) |field| {
        const as_int: AsInt(field.type) = @truncate(bits >> idx);
        switch (@typeInfo(field.type)) {
            .Enum, .Struct, .Union => {
                if (@hasDecl(field.type, "match") and !field.type.match(as_int)) return false;
            },
            else => {},
        }
        idx += @bitSizeOf(field.type);
    }
    return true;
}

// Make sure encoding is valid
fn validateEncoding(comptime instr: type, comptime word: u16) bool {
    const Encoding = instr.Encoding;

    // Validate encoding layout with word to make sure enums and other types cast over correctly
    if (!validatePackedStruct(Encoding, word)) return false;

    // Now use per instruction matching since we know that the encoding can be represented (even if
    // it doesn't make any sense at the moment).
    const encoding: Encoding = @bitCast(word);
    return instr.match(encoding);
}

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
            if (!validateEncoding(instr, word)) continue;
            const encoding: instr.Encoding = @bitCast(word);
            const as_bits: AsInt(instr.Variant) = @bitCast(encodingToVariant(instr, encoding));
            lut[i] = iter.base + as_bits;
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
        while (state.regs.pc <= addr and !state.halted) {
            runInstr(&state);
        }
        try instr.Tester.validate(&state);
    }
}

// List of cpu instructions (as types of structs)
const instrs = .{
    //@import("m68k/abcd.zig"),
    //@import("m68k/add.zig"),
    //@import("m68k/adda.zig"),
    //@import("m68k/addi.zig"),
    //@import("m68k/addq.zig"),
    //@import("m68k/addx.zig"),
    //@import("m68k/and.zig"),
    //@import("m68k/andi.zig"),
    //@import("m68k/andi_to_ccr.zig"),
    //@import("m68k/asd_reg.zig"),
    //@import("m68k/asd_mem.zig"),
    //@import("m68k/b_cc.zig"),
    //@import("m68k/b_xxx_reg.zig"),
    //@import("m68k/b_xxx_imm.zig"),
};
