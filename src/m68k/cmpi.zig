const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    lhs: enc.EffAddr,
    size: enc.Size,
    pattern: enc.BitPattern(8, 0b0000_1100),
};
pub const Variant = packed struct {
    size: enc.Size,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	0c40 0032      	cmpiw #50,%d0
    pub const code = [_]u16{ 0x0C40, 0x0032 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 8);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    _ = encoding;
    return 0;
}
pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(encoding.lhs).?) {
        .addr_reg, .imm => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const imm = state.programFetch(args.size);
    const lhs = cpu.EffAddr(args.size).calc(state, instr.lhs);

    // Set flags and store result
    _ = state.subWithFlags(args.size, lhs.load(state), imm);

    // Add processing time
    if (args.size == .long) {
        switch (lhs) {
            .data_reg => state.cycles += 2,
            else => {},
        }
    }

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
