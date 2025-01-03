const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    vector: u4,
    pattern: enc.BitPattern(12, 0b010011100100),

    pub fn getLen(self: Encoding) usize {
        _ = self;
        return 1;
    }

    pub fn match(comptime self: Encoding) bool {
        _ = self;
        return true;
    }
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    pub const code = [_]u16{};
    pub fn validate(state: *const cpu.State) !void {
        _ = state;
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    state.trapException(instr.vector);
}
