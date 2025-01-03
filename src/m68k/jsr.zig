const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    loc: enc.EffAddr,
    line: enc.BitPattern(10, 0b0100_1110_10),

    pub fn getLen(self: Encoding) usize {
        return enc.AddrMode.fromEffAddr(self.loc).?.getAdditionalSize(enc.Size.long) + 1;
    }

    pub fn match(comptime self: Encoding) bool {
        return switch (enc.AddrMode.fromEffAddr(self.loc).?) {
            .data_reg, .addr_reg, .addr_postinc, .addr_predec, .imm => false,
            else => true,
        };
    }
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	4eba 0002      	jsr %pc@(4 <end>)
    pub const code = [_]u16{ 0x4EBA, 0x0002 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 18);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    const new_pc = cpu.EffAddr(enc.Size.word).calc(state, instr.loc).mem;
    state.pushVal(enc.Size.long, state.regs.pc);
    state.regs.pc = new_pc;
    state.ir = state.programFetch(enc.Size.word);
    state.cycles += switch (enc.AddrMode.fromEffAddr(instr.loc).?) {
        .addr_disp, .abs_word, .pc_disp => 2,
        .addr_idx, .pc_idx => 4,
        else => 0,
    };
}
