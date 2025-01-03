const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    src: enc.EffAddr,
    pattern_m: enc.BitPattern(3, 0b001),
    reg: u3,
    size: enc.MoveSize,
    line: enc.BitPattern(2, 0),
};
pub const Variant = packed struct {
    size: enc.MoveSize,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	307c ffff      	moveaw #-1,%a0
    pub const code = [_]u16{ 0x307C, 0xFFFF };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 8);
        try expect(state.regs.a[0] == 0xFFFFFFFF);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    _ = encoding;
    return 0;
}
pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    const size = comptime args.size.toSize();
    const instr: Encoding = @bitCast(state.ir);
    const src = cpu.extendFull(size, cpu.EffAddr(size).calc(state, instr.src).load(state));
    state.setNegAndZeroFlags(enc.Size.long, src);
    state.regs.sr.c = false;
    state.regs.sr.v = false;
    state.regs.a[instr.reg] = src;
    state.ir = state.programFetch(enc.Size.word);
}
