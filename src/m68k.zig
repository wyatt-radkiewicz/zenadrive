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
    switch (decode_lut[state.ir]) {
        inline else => |val| Instr.fromDecodeByte(val).run(state),
    }
    state.handleException();
}

// Used to run an instruction from an decode look up table value
const Instr = struct {
    instr: type,
    size: ?enc.Size,
    
    // Run an instruction
    inline fn run(comptime self: Instr, state: *cpu.State) void {
        if (self.instr == void) {
            state.pending_exception = @intFromEnum(cpu.Vector.illegal_instr);
            return;
        }
        if (self.size) |size| {
            self.instr.runWithSize(state, size);
        } else {
            self.instr.run(state);
        }
    }
     
    // Finds the correct instruction struct from the decode byte
    fn fromDecodeByte(comptime lut_byte: u8) Instr {
        var idx = 0;
        var left = lut_byte;
        while (left >= permutations(instrs[idx])) {
            left -= permutations(instrs[idx]);
            idx += 1;
            if (idx >= instrs.len) return .{ .instr = void, .size = null };
        }
        return .{
            .instr = instrs[idx],
            .size = if (@hasDecl(instrs[idx], "runWithSize")) @enumFromInt(left) else null,
        };
    }
    
    // Get number of run permutations for a instruction runner
    fn permutations(comptime instr: type) comptime_int {
        return if (@hasDecl(instr, "runWithSize")) 3 else 1;
    }
};

// Cpu instruction decode lookup table
// If you index the table by the first word of an instruction, it gives you the correct run function
// to run for the instruction. Index 0xFF is for invalid instruction encodings and should run the
// illegal instruction exception handler.
const decode_lut: [0x10000]u8 = compute_lut: {
    var lut = [1]u8{0xFF} ** 0x10000;
    @setEvalBranchQuota(lut.len * 256);
    
    var decode_byte_base = 0;
    for (instrs) |instr| {
        const withSize = @hasDecl(instr, "runWithSize");
        if (@bitSizeOf(instr.Encoding) != 16) {
            @compileError("instruction encodings must be 16 bits!");
        }
        for (0..lut.len) |i| {
            const word: u16 = i;
            if (!enc.matchChildren(instr.Encoding, word)) continue;
            if (withSize) {
                const encoding: instr.Encoding = @bitCast(word);
                lut[i] = decode_byte_base + @as(comptime_int, @intFromEnum(encoding.size));
            } else {
                lut[i] = decode_byte_base;
            }
        }
        decode_byte_base += Instr.permutations(instr);
    }
    break :compute_lut lut;
};

test "Instructions" {
    var bus = cpu_testing.Bus{};
    var state = cpu.State.init(&bus);
    inline for (instrs) |instr| {
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
        try std.testing.expect(instr.Tester.validate(&state));
    }
}

// List of cpu instructions (as types of structs)
const instrs = .{
    //@import("m68k/abcd.zig"),
    //@import("m68k/add_to_dn.zig"),
    //@import("m68k/add_to_ea.zig"),
    //@import("m68k/adda.zig"),
    //@import("m68k/addi.zig"),
    //@import("m68k/addq.zig"),
    //@import("m68k/addx.zig"),
    @import("m68k/and_to_dn.zig"),
    @import("m68k/and_to_ea.zig"),
    @import("m68k/andi.zig"),
    @import("m68k/andi_to_ccr.zig"),
};
