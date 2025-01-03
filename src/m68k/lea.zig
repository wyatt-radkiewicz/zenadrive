const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    loc: enc.EffAddr,
    pattern: enc.BitPattern(3, 0b111),
    reg: u3,
    line: enc.BitPattern(4, 0b0100),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	43d0           	lea %a0@,%a1
    pub const code = [_]u16{ 0x43D0 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 4);
    }
};

pub fn getLen(encoding: Encoding) usize {
    return enc.AddrMode.fromEffAddr(encoding.loc).?.getAdditionalSize(enc.Size.long) + 1;
}
pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(encoding.loc).?) {
        .data_reg, .addr_reg, .addr_postinc, .addr_predec, .imm => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    state.regs.a[instr.reg] = cpu.EffAddr(enc.Size.word).calc(state, instr.loc).mem;
    state.ir = state.programFetch(enc.Size.word);
    state.cycles += switch (enc.AddrMode.fromEffAddr(instr.loc).?) {
        .addr_idx, .pc_idx => 2,
        else => 0,
    };
}
