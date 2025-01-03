const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.EffAddr,
    op: enc.BitOp,
    line: enc.BitPattern(8, 0b0000_1000),
};
pub const Variant = packed struct {
    op: enc.BitOp,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	0840 00ff      	bchg #-1,d0 ; 12 cycles
    // 4:	0878 0002 0020 	bchg #2,$20 ; 20 cycles
    pub const code = [_]u16{
        0x0840, 0x00FF,
        0x0878, 0x0002,
        0x0020,
    };
    pub fn validate(state: *cpu.State) !void {
        try expect(state.cycles == 32);
        try expect(state.regs.d[0] == 0x8000_0000);
        try expect(state.rdBus(enc.Size.byte, 0x20) == 0x04);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    return enc.AddrMode.fromEffAddr(encoding.dst).?.getAdditionalSize(enc.Size.byte) + 1;
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

    const bit_idx = state.programFetch(enc.Size.byte) % 32;
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
        .data_reg => {
            state.cycles += switch (args.op) {
                .btst => 2,
                .bclr => if (bit_idx < 16) 4 else 6,
                else => if (bit_idx < 16) 2 else 4,
            };
        },
        else => {},
    }

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
