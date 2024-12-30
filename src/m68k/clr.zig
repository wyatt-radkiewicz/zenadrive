const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.EffAddr,
    size: enc.Size,
    pattern: enc.BitPattern(8, 0b0100_0010),
};
pub const Variant = packed struct {
    size: enc.Size,
};
pub const Tester = struct {
    const expect = @import("std").testing.expect;

    // 0:	4240           	clrw %d0 ; 4 cycles
    pub const code = [_]u16{ 0x4240 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 4);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    _ = std.mem.indexOfScalar(enc.AddrMode, &[_]enc.AddrMode{
        .addr_reg,
        .imm,
        .pc_idx,
        .pc_disp,
    }, enc.AddrMode.fromEffAddr(encoding.dst).?) orelse return true;
    return false;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const dst = cpu.EffAddr(args.size).calc(state, instr.dst);
    _ = dst.load(state); // Random read always for some reason idk m68k weird

    // Set flags and store result
    state.regs.sr.c = false;
    state.regs.sr.v = false;
    state.regs.sr.z = true;
    state.regs.sr.n = false;
    dst.store(state, 0);

    // Add processing time
    if (args.size == .long) {
        switch (dst) {
            .data_reg => state.cycles += 2,
            else => {},
        }
    }

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
