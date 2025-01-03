const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    loc: enc.EffAddr,
    line: enc.BitPattern(10, 0b0100_1110_11),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	4efa 0008      	jmp %pc@(4 <end>)
    pub const code = [_]u16{ 0x4EFA, 0x0008 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 10);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    _ = encoding;
    return 0;
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
    state.regs.pc = cpu.EffAddr(enc.Size.word).calc(state, instr.loc).mem;
    state.ir = state.programFetch(enc.Size.word);
    state.cycles += switch (enc.AddrMode.fromEffAddr(instr.loc).?) {
        .addr_disp, .abs_word, .pc_disp => 2,
        .addr_idx, .pc_idx => 4,
        else => 0,
    };
}
