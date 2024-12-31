const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    src: enc.EffAddr,
    dst_m: u3,
    dst_xn: u3,
    size: enc.MoveSize,
    line: enc.BitPattern(2, 0),
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

pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(.{ .m = encoding.dst_m, .xn = encoding.dst_xn })) {
        null, .addr_reg, .imm, .pc_idx, .pc_disp => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    const size = comptime args.size.toSize();
    const instr: Encoding = @bitCast(state.ir);
    const dst = cpu.EffAddr(size).calc(state, .{ .m = instr.dst_m, .xn = instr.dst_xn });
    const src = cpu.EffAddr(size).calc(state, instr.src).load(state);
    state.setNegAndZeroFlags(size, src);
    state.regs.sr.c = false;
    state.regs.sr.v = false;
    dst.store(state, src);
    state.ir = state.programFetch(enc.Size.word);
}
