const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    ea: enc.EffAddr,
    pattern: enc.BitPattern(10, 0b0100100001),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	4850           	pea %a0@
    pub const code = [_]u16{ 0x4850 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 12);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(encoding.ea).?) {
        .data_reg, .addr_reg, .addr_postinc, .addr_predec, .imm => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    state.ir = state.programFetch(enc.Size.word);
    state.pushVal(enc.Size.long, cpu.EffAddr(enc.Size.long).calc(state, instr.ea).mem);
    state.cycles += switch (enc.AddrMode.fromEffAddr(instr.ea).?) {
        .addr_idx, .pc_idx => 2,
        else => 0,
    };
}
