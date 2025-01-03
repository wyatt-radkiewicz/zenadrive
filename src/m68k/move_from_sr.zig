const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.EffAddr,
    pattern: enc.BitPattern(10, 0b0100000011),

    pub fn getLen(self: Encoding) usize {
        return enc.AddrMode.fromEffAddr(self.dst).?.getAdditionalSize(enc.Size.word) + 1;
    }

    pub fn match(comptime self: Encoding) bool {
        return switch (enc.AddrMode.fromEffAddr(self.dst).?) {
            .addr_reg, .imm, .pc_idx, .pc_disp => false,
            else => true,
        };
    }
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	40c0           	movew %sr,%d0
    pub const code = [_]u16{0x40C0};
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 6);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    const dst = cpu.EffAddr(enc.Size.word).calc(state, instr.dst);
    const sr: u16 = @bitCast(state.regs.sr);
    dst.store(state, sr);
    if (dst == .data_reg) state.cycles += 2;
    state.ir = state.programFetch(enc.Size.word);
}
