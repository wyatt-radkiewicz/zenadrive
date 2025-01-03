const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    reg: u3,
    pattern2: enc.BitPattern(3, 0),
    size: u1,
    pattern1: enc.BitPattern(9, 0b0100_1000_1),

    pub fn getLen(self: Encoding) usize {
        _ = self;
        return 1;
    }

    pub fn match(comptime self: Encoding) bool {
        _ = self;
        return true;
    }
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	4880           	extw %d0
    pub const code = [_]u16{0x4880};
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 4);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    state.regs.sr.c = false;
    state.regs.sr.v = false;
    switch (instr.size) {
        0 => {
            const reg = state.loadReg(.data, .byte, instr.reg);
            const res: u16 = @bitCast(@as(i16, @as(i8, @bitCast(reg))));
            state.setNegAndZeroFlags(enc.Size.word, res);
            state.storeReg(.data, .word, instr.reg, res);
        },
        1 => {
            const reg = state.loadReg(.data, .word, instr.reg);
            const res: u32 = @bitCast(@as(i32, @as(i16, @bitCast(reg))));
            state.setNegAndZeroFlags(enc.Size.long, res);
            state.storeReg(.data, .long, instr.reg, res);
        },
    }

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
