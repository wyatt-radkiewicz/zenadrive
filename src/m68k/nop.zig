const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    pattern: enc.BitPattern(16, 0b0100111001110001),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    // 0: 4e71 nop
    pub const code = [_]u16{ 0x4E71 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 4);
    }
};

pub fn getLen(encoding: Encoding) usize {
    _ = encoding;
    return 1;
}
pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    state.ir = state.programFetch(enc.Size.word);
}
