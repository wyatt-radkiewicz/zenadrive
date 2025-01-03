const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    ea: enc.EffAddr,
    size: enc.Size,
    pattern: enc.BitPattern(8, 0b0100_1010),
};
pub const Variant = packed struct {
    size: enc.Size,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    pub const code = [_]u16{ };
    pub fn validate(state: *const cpu.State) !void {
        _ = state;
    }
};

pub fn getLen(encoding: Encoding) usize {
    return enc.AddrMode.fromEffAddr(encoding.ea).?.getAdditionalSize(encoding.size) + 1;
}
pub fn match(comptime encoding: Encoding) bool {
    const mode = enc.AddrMode.fromEffAddr(encoding.ea).?;
    return switch (mode) {
        .addr_reg, .imm, .pc_idx, .pc_disp => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    const byte = cpu.EffAddr(enc.Size.byte).calc(state, instr.ea).load(state);
    state.regs.sr.c = false;
    state.regs.sr.v = false;
    state.setNegAndZeroFlags(enc.Size.byte, byte);
    state.ir = state.programFetch(enc.Size.word);
}
