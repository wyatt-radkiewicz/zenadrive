const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

// Move specific versions of effective address encodings
pub const EffAddr = packed struct {
    m: u3,
    xn: u3,

    pub fn match(bits: u6) bool {
        const self: EffAddr = @bitCast(bits);
        return enc.AddrMode.fromEffAddr(self.toEffAddr()) != null;
    }

    pub fn toEffAddr(self: EffAddr) enc.EffAddr {
        return .{
            .m = self.m,
            .xn = self.xn,
        };
    }
};
pub const Encoding = packed struct {
    src: enc.EffAddr,
    dst: EffAddr,
    size: enc.MoveSize,
    line: enc.BitPattern(2, 0),

    pub fn getLen(self: Encoding) usize {
        const size = self.size.toSize();
        const dst = self.dst.toEffAddr();
        return 1 + enc.AddrMode.fromEffAddr(self.src).?.getAdditionalSize(size) + enc.AddrMode.fromEffAddr(dst).?.getAdditionalSize(size);
    }

    pub fn match(comptime self: Encoding) bool {
        return switch (enc.AddrMode.fromEffAddr(self.dst.toEffAddr()).?) {
            .addr_reg, .imm, .pc_idx, .pc_disp => false,
            else => true,
        };
    }
};
pub const Variant = packed struct {
    size: enc.MoveSize,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	303c ffff      	movew #-1,%d0
    pub const code = [_]u16{ 0x303C, 0xFFFF };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 8);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    const size = comptime args.size.toSize();
    const instr: Encoding = @bitCast(state.ir);
    const dst = cpu.EffAddr(size).calc(state, instr.dst.toEffAddr());
    const src = cpu.EffAddr(size).calc(state, instr.src).load(state);
    state.setNegAndZeroFlags(size, src);
    state.regs.sr.c = false;
    state.regs.sr.v = false;
    dst.store(state, src);
    state.ir = state.programFetch(enc.Size.word);
}
