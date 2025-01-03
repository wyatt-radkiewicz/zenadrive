const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.EffAddr,
    op: enc.BitOp,
    pattern: enc.BitPattern(1, 1),
    reg: u3,
    line: enc.BitPattern(4, 0b0000),
};
pub const Variant = packed struct {
    op: enc.BitOp,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	0141           	bchg d0,d1     ; 6 cycles
    // 2:	0178 0020      	bchg d0,$20    ; 16 cycles
    pub const code = [_]u16{ 0x0141, 0x0178, 0x0020 };
    pub fn validate(state: *cpu.State) !void {
        try expect(state.cycles == 22);
        try expect(state.regs.d[1] == 1);
        try expect(state.rdBus(enc.Size.byte, 0x20) == 1);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    _ = encoding;
    return 0;
}
pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(encoding.dst).?) {
        .addr_reg, .imm, .pc_idx, .pc_disp => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Get encoding
    const instr: Encoding = @bitCast(state.ir);

    const bit_idx = state.regs.d[instr.reg] % 32;
    switch (state.bitOpWithFlags(
        instr.dst,
        bit_idx,
        args.op != .btst,
        struct {
            fn inner(dst: u32, mask: u32) u32 {
                return switch (args.op) {
                    .btst => unreachable,
                    .bclr => dst & ~mask,
                    .bset => dst | mask,
                    .bchg => dst ^ mask,
                };
            }
        }.inner,
    )) {
        // Add cycles
        .data_reg => state.cycles += if (bit_idx < 16) 2 else 4,
        else => {},
    }

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
