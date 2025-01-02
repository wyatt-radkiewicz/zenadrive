const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    pattern: enc.BitPattern(16, 0b0100111001110000),
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
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    if (!state.checkPrivlege(true)) return;
    state.cycles += 512;
    state.ir = state.programFetch(enc.Size.word);
}
