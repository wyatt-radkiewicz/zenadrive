const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    ea: enc.EffAddr,
    pattern: enc.BitPattern(2, 0b11),
    is_signed: bool,
    reg: u3,
    line: enc.BitPattern(4, 0b1100),

    pub fn getLen(self: Encoding) usize {
        return enc.AddrMode.fromEffAddr(self.ea).?.getAdditionalSize(enc.Size.word) + 1;
    }

    pub fn match(comptime self: Encoding) bool {
        return enc.AddrMode.fromEffAddr(self.ea).? != .addr_reg;
    }
};
pub const Variant = packed struct {
    is_signed: bool,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	c2c0           	muluw %d0,%d1
    pub const code = [_]u16{0xC2C0};
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 38);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    const instr: Encoding = @bitCast(state.ir);
    const ea = cpu.EffAddr(.word).calc(state, instr.ea).load(state);
    const res = @as(u32, ea) * state.loadReg(.data, .word, instr.reg);
    state.regs.sr.c = false;
    state.regs.sr.v = false;
    state.setNegAndZeroFlags(enc.Size.long, res);
    state.regs.d[instr.reg] = res;
    state.ir = state.programFetch(enc.Size.word);

    // Compute computation time
    state.cycles += 34;
    if (args.is_signed) {
        state.cycles += @popCount(ea) * 2;
    } else {
        var src = @as(u32, ea) << 1;
        for (0..16) |_| {
            const lsb = src & 3;
            if (lsb == 0b10 or lsb == 0b01) state.cycles += 2;
            src >>= 1;
        }
    }
}
