const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    pattern: enc.MatchBits(16, 0),
};

pub const Tester = struct {
    pub const code = [_]u16 { 0x0640, 0x002D };
    pub fn validate(state: *const cpu.State) bool {
        _ = state;
        return true;
    }
};

pub fn run(state: *cpu.State) void {
    _ = state;
}