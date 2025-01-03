const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

const Op = enum(u2) {
    negx,
    clr,
    neg,
    not,
};
pub const Encoding = packed struct {
    dst: enc.EffAddr,
    size: enc.Size,
    pattern: enc.BitPattern(1, 0),
    op: Op,
    line: enc.BitPattern(5, 0b0100_0),
};
pub const Variant = packed struct {
    op: Op,
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

pub fn getLen(encoding: Encoding) usize {
    return enc.AddrMode.fromEffAddr(encoding.dst).?.getAdditionalSize(encoding.size) + 1;
}
pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(encoding.dst).?) {
        .addr_reg, .imm, .pc_idx, .pc_disp => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    const instr: Encoding = @bitCast(state.ir);
    const dst = cpu.EffAddr(args.size).calc(state, instr.dst);

    switch (args.op) {
        .neg, .negx => {
            const S = args.size.getType(.signed);
            const val: S = @bitCast(dst.load(state));
            const base: S = blk: {
                if (args.op == .neg) {
                    break :blk 0;
                } else {
                    break :blk if (state.regs.sr.x) -1 else 0;
                }
            };
            const res = @subWithOverflow(base, val);
            state.regs.sr.c = res[0] != 0;
            state.regs.sr.x = state.regs.sr.c;
            state.regs.sr.v = res[1] == 1;
            state.regs.sr.n = res[0] < 0;
            if (args.op == .neg) {
                state.regs.sr.z = res[0] == 0;
            } else if (res[0] != 0) {
                state.regs.sr.z = false;
            }
            dst.store(state, @bitCast(res[0]));
        },
        .clr => {
            _ = dst.load(state); // Random read always for some reason idk m68k weird
            state.regs.sr.c = false;
            state.regs.sr.v = false;
            state.regs.sr.z = true;
            state.regs.sr.n = false;
            dst.store(state, 0);
        },
        .not => {
            const res = ~dst.load(state);
            state.regs.sr.c = false;
            state.regs.sr.v = false;
            state.setNegAndZeroFlags(args.size, res);
            dst.store(state, res);
        },
    }
    
    // Set flags and store result
    if (args.size == .long and dst == .data_reg) state.cycles += 2;
    state.ir = state.programFetch(enc.Size.word);
}
