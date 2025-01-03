const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    rhs: u3,
    pattern2: enc.BitPattern(3, 0b001),
    size: enc.Size,
    pattern1: enc.BitPattern(1, 1),
    lhs: u3,
    line: enc.BitPattern(4, 0b1011),
};
pub const Variant = packed struct {
    size: enc.Size,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	b348           	cmpmw %a0@+,%a1@+
    pub const code = [_]u16{ 0xB348 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 12);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    _ = encoding;
    return 0;
}
pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const mode = enc.AddrMode.addr_postinc.toEffAddr().m;
    const rhs = cpu.EffAddr(args.size).calc(state, .{ .m = mode, .xn = instr.rhs });
    const lhs = cpu.EffAddr(args.size).calc(state, .{ .m = mode, .xn = instr.lhs });

    // Set flags and store result
    _ = state.subWithFlags(args.size, lhs.load(state), rhs.load(state));

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
