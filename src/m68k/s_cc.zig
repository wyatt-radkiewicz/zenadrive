const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    ea: enc.EffAddr,
    pattern: enc.BitPattern(2, 0b11),
    cond: enc.Cond,
    line: enc.BitPattern(4, 0b0101),

    pub fn getLen(self: Encoding) usize {
        return enc.AddrMode.fromEffAddr(self.ea).?.getAdditionalSize(enc.Size.byte) + 1;
    }

    pub fn match(comptime self: Encoding) bool {
        const mode = enc.AddrMode.fromEffAddr(self.ea).?;
        return switch (mode) {
            .addr_reg, .imm, .pc_disp, .pc_idx => false,
            else => true,
        };
    }
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	56c0           	sne %d0
    pub const code = [_]u16{0x56C0};
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 6);
        try expect(state.regs.d[0] == 0xFF);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    const dst = cpu.EffAddr(enc.Size.byte).calc(state, instr.ea);
    _ = dst.load(state);
    var val: u8 = 0;
    if (state.regs.sr.satisfiesCond(instr.cond)) {
        val = 0xFF;
        if (dst == .data_reg) state.cycles += 2;
    }
    dst.store(state, val);
    state.ir = state.programFetch(enc.Size.word);
}
