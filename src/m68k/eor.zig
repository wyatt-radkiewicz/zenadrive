const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.EffAddr,
    size: enc.Size,
    dir: enc.BitPattern(1, 1),
    src: u3,
    line: enc.BitPattern(4, 0b1011),

    pub fn getLen(self: Encoding) usize {
        return enc.AddrMode.fromEffAddr(self.dst).?.getAdditionalSize(self.size) + 1;
    }

    pub fn match(comptime self: Encoding) bool {
        return switch (enc.AddrMode.fromEffAddr(self.dst).?) {
            .addr_reg, .imm, .pc_idx, .pc_disp => false,
            else => true,
        };
    }
};
pub const Variant = packed struct {
    size: enc.Size,
};

pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	b141           	eorw %d0,%d1
    pub const code = [_]u16{0xB141};
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 4);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);

    // Set flags and store result
    const dst_ea = cpu.EffAddr(args.size).calc(state, instr.dst);
    const res = dst_ea.load(state) ^ state.loadReg(.data, args.size, instr.src);
    state.setLogicalFlags(args.size, res);
    dst_ea.store(state, res);

    // Add processing time and fetch next instruction
    if (args.size == .long) {
        state.cycles += switch (dst_ea) {
            .data_reg => 4,
            else => 0,
        };
    }

    state.ir = state.programFetch(enc.Size.word);
}
