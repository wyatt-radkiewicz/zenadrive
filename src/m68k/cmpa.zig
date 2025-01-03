const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    rhs: enc.EffAddr,
    pattern: enc.BitPattern(2, 0b11),
    size: u1,
    lhs: u3,
    line: enc.BitPattern(4, 0b1011),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;
    
    // 0:	b0c0           	cmpaw %d0,%a0
    pub const code = [_]u16{ 0xB0C0 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 6);
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
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    const rhs = switch (enc.Size.fromBit(instr.size)) {
        .byte => unreachable,
        .word => cpu.extendFull(enc.Size.word, cpu.EffAddr(enc.Size.word).calc(state, instr.rhs).load(state)),
        .long => cpu.EffAddr(enc.Size.long).calc(state, instr.rhs).load(state),
    };
    _ = state.subWithFlags(enc.Size.long, state.loadReg(.addr, enc.Size.long, instr.lhs), rhs);
    state.cycles += 2;
    state.ir = state.programFetch(enc.Size.word);
}
