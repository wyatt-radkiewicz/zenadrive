const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    data: i8,
    pattern: enc.BitPattern(1, 0),
    dn: u3,
    line: enc.BitPattern(4, 0b0111),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    //   0:	70ff           	moveq #-1,%d0
    pub const code = [_]u16{ 0x70FF };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 4);
        try expect(state.regs.d[0] == 0xFFFFFFFF);
    }
};

pub fn getLen(encoding: Encoding) usize {
    _ = encoding;
    return 1;
}
pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    const val: u32 = @bitCast(@as(i32, instr.data));
    state.regs.d[instr.dn] = val;
    state.regs.sr.c = false;
    state.regs.sr.v = false;
    state.setNegAndZeroFlags(enc.Size.long, val);
    state.ir = state.programFetch(enc.Size.word);
}
