const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

const Op = enum(u1) { addq, subq };
pub const Encoding = packed struct {
    dst: enc.EffAddr,
    size: enc.Size,
    op: Op,
    data: u3,
    line: enc.BitPattern(4, 0b0101),
};
pub const Variant = packed struct {
    size: enc.Size,
    op: Op,
};

pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	5648           	addqw #3,%a0 ; 8 cycles
    // 2:	5680           	addql #3,%d0 ; 8 cycles
    pub const code = [_]u16{ 0x5648, 0x5680 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 16);
    }
};

pub fn getLen(encoding: Encoding) usize {
    return enc.AddrMode.fromEffAddr(encoding.dst).?.getAdditionalSize(encoding.size) + 1;
}
pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(encoding.dst).?) {
        .imm, .pc_idx, .pc_disp => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const imm: args.size.getType(.unsigned) = instr.data;
    const dst = cpu.EffAddr(args.size).calc(state, instr.dst);

    // Set flags and store result
    const sr_backup = state.regs.sr;
    const res = switch (args.op) {
        .addq => state.addWithFlags(args.size, imm, dst.load(state)),
        .subq => state.subWithFlags(args.size, dst.load(state), imm),
    };
    state.regs.sr.x = state.regs.sr.c;

    // Only update flags if we are not adding to an address register
    switch (dst) {
        .addr_reg => state.regs.sr = sr_backup,
        else => {},
    }
    dst.store(state, res);

    // Add processing time
    state.cycles += switch (dst) {
        .data_reg => if (args.size == .long) 4 else 0,
        .addr_reg => 4,
        else => 0,
    };

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
