const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.EffAddr,
    pattern: enc.BitPattern(10, 0b0100_1000_00),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;
    
    // 0:	7213           	moveq #19,%d1  ; 4 cycles
    // 2:	4801           	nbcd %d1       ; 6 cycles
    pub const code = [_]u16{ 0x7213, 0x4801 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 10);
        try expect(state.regs.d[1] == 0x87);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    _ = encoding;
    return 0;
}
pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(encoding.dst).?) {
        .addr_reg, .imm, .pc_idx, .pc_disp => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    const dst = cpu.EffAddr(enc.Size.byte).calc(state, instr.dst);
    const dst_bcd: cpu.Bcd = @bitCast(dst.load(state));
    const res = cpu.Bcd.sub(@bitCast(@as(u8, 0)), dst_bcd, @intFromBool(state.regs.sr.x));
    dst.store(state, @bitCast(res[0]));
    state.regs.sr.c = res[1];
    state.regs.sr.x = res[1];
    state.regs.sr.z = res[0].ones == 0 and res[0].tens == 0;
    if (dst == .data_reg) state.cycles += 2;
    state.ir = state.programFetch(enc.Size.word);
}
