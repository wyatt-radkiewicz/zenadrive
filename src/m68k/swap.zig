const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    reg: u3,
    pattern: enc.BitPattern(13, 0b0100_1000_0100_0),

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

    // 0: 4840 swap,%d0
    pub const code = [_]u16{0x4840};
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 4);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    const reg = state.regs.d[instr.reg];
    state.regs.d[instr.reg] = reg << 16 | reg >> 16;
    state.ir = state.programFetch(enc.Size.word);
}
