const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    pattern: enc.BitPattern(9, 0b0_0011_1100),
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

pub fn match(comptime encoding: Encoding) bool {
    return switch (encoding.op) {
        .andi, .eori, .ori => true,
        else => false,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    
    // Compute effective addresses
    const imm = state.programFetch(enc.Size.byte);

    // Set flags and store result
    var sr: u16 = @bitCast(state.regs.sr);
    switch (instr.op) {
        .andi => sr &= imm,
        .eori => sr ^= imm,
        .ori => sr |= imm,
        else => unreachable,
    }
    state.regs.sr = @bitCast(sr);

    // Add processing time
    state.cycles += 12;
    
    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
