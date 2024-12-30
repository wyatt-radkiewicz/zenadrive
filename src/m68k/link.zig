const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    reg: u3,
    line: enc.BitPattern(13, 0b0100111001010),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	4e50 002d      	linkw %a0,#45
    pub const code = [_]u16{ 0x4E50, 0x002D };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 16);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    const disp: u32 = cpu.extendFull(enc.Size.word, state.programFetch(enc.Size.word));
    state.pushVal(enc.Size.long, state.regs.a[instr.reg]);
    state.regs.a[instr.reg] = state.regs.a[cpu.Regs.sp];
    state.regs.a[cpu.Regs.sp] +%= disp;
    state.ir = state.programFetch(enc.Size.word);
}
