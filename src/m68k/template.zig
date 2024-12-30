const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct { pattern: enc.MatchBits(16, 0) };
pub const ComptimeArgs = struct {};

pub const Tester = struct {
    const expect = @import("std").testing.expect;
    pub const code = [_]u16{ 0x0640, 0x002D };
    pub fn validate(state: *const cpu.State) !void {
        _ = state;
    }
};

pub fn run(state: *cpu.State, comptime args: ComptimeArgs) void {
    // Get encoding
    const instr: Encoding = @bitCast(state.ir);
    _ = instr;
    _ = args;

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
