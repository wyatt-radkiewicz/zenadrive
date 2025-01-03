const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    pattern2: enc.BitPattern(6, 0b111_100),
    supervisor: bool,
    pattern1: enc.BitPattern(2, 0),
    op: enc.ImmOp,
    line: enc.BitPattern(4, 0b0000),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;
    
    // 0:	023c 00f0      	andi.b #-16,ccr
    pub const code = [_]u16{ 0x023C, 0x00F0 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 20);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    const size = if (encoding.supervisor) enc.Size.word else enc.Size.byte;
    return enc.AddrMode.fromEffAddr(encoding.dst).?.getAdditionalSize(size);
}
pub fn match(comptime encoding: Encoding) bool {
    return switch (encoding.op) {
        .andi, .eori, .ori => true,
        else => false,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    if (!state.checkPrivlege(instr.supervisor)) return;
    
    // Compute effective addresses
    const imm = state.programFetch(enc.Size.word);

    // Set flags and store result
    var sr: u16 = @bitCast(state.regs.sr);
    const backup_ssr = sr;
    switch (instr.op) {
        .andi => sr &= imm,
        .eori => sr ^= imm,
        .ori => sr |= imm,
        else => unreachable,
    }
    if (!instr.supervisor) {
        sr = backup_ssr & 0xFF00 | sr & 0x00FF;
    }
    state.regs.sr = @bitCast(sr);

    // Add processing time
    state.cycles += 12;
    
    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
