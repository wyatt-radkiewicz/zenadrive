const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.EffAddr,
    size: enc.Size,
    pattern: enc.BitPattern(8, 0b0100_0100),
};
pub const Variant = packed struct {
    size: enc.Size,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	7039           	moveq #57,%d0   ; 4 cycles
    // 2:	4440           	negw %d0        ; 4 cycles
    pub const code = [_]u16{ 0x7039, 0x4440 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 8);
        try expect(state.regs.d[0] == 0xFFC7);
        try expect(state.regs.sr.c);
        try expect(!state.regs.sr.v);
        try expect(!state.regs.sr.z);
        try expect(state.regs.sr.n);
        try expect(state.regs.sr.x);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(encoding.dst).?) {
        .addr_reg, .imm, .pc_idx, .pc_disp => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    const S = args.size.getType(.signed);
    const instr: Encoding = @bitCast(state.ir);
    const dst = cpu.EffAddr(args.size).calc(state, instr.dst);

    // Set flags and store result
    const val: S = @bitCast(dst.load(state));
    const res = @subWithOverflow(0, val);
    state.regs.sr.c = res[0] != 0;
    state.regs.sr.x = state.regs.sr.c;
    state.regs.sr.z = res[0] == 0;
    state.regs.sr.v = res[1] == 1;
    state.regs.sr.n = res[0] < 0;
    dst.store(state, @bitCast(res[0]));
    if (args.size == .long and dst == .data_reg) state.cycles += 2;
    state.ir = state.programFetch(enc.Size.word);
}
