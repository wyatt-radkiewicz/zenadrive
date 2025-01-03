const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    ea: enc.EffAddr,
    pattern: enc.BitPattern(10, 0b0100101011),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    pub const code = [_]u16{ };
    pub fn validate(state: *const cpu.State) !void {
        _ = state;
    }
};

pub fn getLen(encoding: Encoding) usize {
    return enc.AddrMode.fromEffAddr(encoding.ea).?.getAdditionalSize(enc.Size.byte) + 1;
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
    const dst = cpu.EffAddr(enc.Size.byte).calc(state, instr.ea);
    const byte = dst.load(state);
    state.regs.sr.c = false;
    state.regs.sr.v = false;
    state.setNegAndZeroFlags(enc.Size.byte, byte);
    state.cycles += 2;
    dst.store(state, byte | 0x80);
    state.ir = state.programFetch(enc.Size.word);
}
