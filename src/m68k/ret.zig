const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    pattern: u3,
    line: enc.BitPattern(16, 0b0100_1110_0111_0),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    pub const code = [_]u16{ };
    pub fn validate(state: *const cpu.State) !void {
        _ = state;
    }
};

pub fn match(comptime encoding: Encoding) bool {
    return switch (encoding.pattern) {
        0b011, 0b101, 0b111 => true,
        else => false,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    switch (instr.pattern) {
        0b111 => {
            var sr: u16 = @bitCast(state.regs.sr);
            sr = sr & 0xFF00 | state.popVal(enc.Size.byte);
            state.regs.sr = @bitCast(sr);
        },
        0b011 => {
            if (!state.checkPrivlege(true)) return;
            state.regs.sr = @bitCast(state.popVal(enc.Size.word));
        },
        else => {},
    }
    state.regs.pc = state.popVal(enc.Size.long);
    state.cycles += 4;
    state.ir = state.programFetch(enc.Size.word);
}
