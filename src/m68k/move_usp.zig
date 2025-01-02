const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

const Dir = enum(u1){ to_usp, to_an };
pub const Encoding = packed struct {
    an: u3,
    dr: Dir,
    pattern: enc.BitPattern(12, 0b010011100110),
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
    //const instr: Encoding = @bitCast(state.ir);
    if (!state.checkPrivlege(true)) return;
    state.handleException(@intFromEnum(cpu.Vector.illegal_instr));
    //switch (instr.dr) {
    //    .to_usp => {},
    //    .to_an => {},
    //}
    //state.ir = state.programFetch(enc.Size.word);
}
