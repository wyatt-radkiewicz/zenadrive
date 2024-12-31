const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    src: enc.EffAddr,
    pattern: enc.BitPattern(10, 0b0100010011),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	44fc 00ff      	movew #255,%ccr
    pub const code = [_]u16{ 0x44FC, 0x00FF };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 16);
        try expect(state.regs.sr.c);
        try expect(state.regs.sr.v);
        try expect(state.regs.sr.z);
        try expect(state.regs.sr.n);
        try expect(state.regs.sr.x);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    const src = cpu.EffAddr(enc.Size.word).calc(state, instr.src).load(state);
    const sr: u16 = @bitCast(state.regs.sr);
    state.regs.sr = @bitCast(sr & 0xFF00 | src & 0x00FF);
    state.cycles += 8;
    state.ir = state.programFetch(enc.Size.word);
}