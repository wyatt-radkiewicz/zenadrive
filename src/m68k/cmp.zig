const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    rhs: enc.EffAddr,
    size: enc.Size,
    pattern: enc.BitPattern(1, 0),
    lhs: u3,
    line: enc.BitPattern(4, 0b1011),
};
pub const Variant = packed struct {
    size: enc.Size,
};
pub const Tester = struct {
    const expect = std.testing.expect;
    
    // 0:	b050           	cmpw %a0@,%d0
    pub const code = [_]u16{ 0xB050 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 8);
    }
};

pub fn getLen(encoding: Encoding) usize {
    return enc.AddrMode.fromEffAddr(encoding.rhs).?.getAdditionalSize(encoding.size) + 1;
}
pub fn match(comptime encoding: Encoding) bool {
    return enc.AddrMode.fromEffAddr(encoding.rhs).? != .addr_reg or encoding.size != .byte;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    const instr: Encoding = @bitCast(state.ir);
    const rhs = cpu.EffAddr(args.size).calc(state, instr.rhs).load(state);
    _ = state.subWithFlags(args.size, state.loadReg(.data, args.size, instr.lhs), rhs);
    if (args.size == .long) state.cycles += 2;
    state.ir = state.programFetch(enc.Size.word);
}
