const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.MatchEffAddr(&[_]enc.AddrMode{ .addr_reg, .imm, .pc_idx, .pc_disp }),
    pattern: enc.MatchBits(3, 0b101),
    reg: u3,
    line: enc.MatchBits(4, 0b0000),
};

pub const Tester = struct {
    const expect = @import("std").testing.expect;

    // 0:	0141           	bchg d0,d1     ; 6 cycles
    // 2:	0178 0020      	bchg d0,$20    ; 16 cycles
    pub const code = [_]u16{ 0x0141, 0x0178, 0x0020 };
    pub fn validate(state: *cpu.State) !void {
        try expect(state.cycles == 22);
        try expect(state.regs.d[1] == 1);
        try expect(state.rdBus(enc.Size.byte, 0x20) == 1);
    }
};

pub fn run(state: *cpu.State) void {
    // Get encoding
    const instr: Encoding = @bitCast(state.ir);

    const bit_idx = state.regs.d[instr.reg] % 32;
    switch (state.bitOpWithFlags(
        instr.dst.m,
        instr.dst.xn,
        bit_idx,
        struct {
            fn inner(dst: u32, mask: u32) u32 {
                return dst ^ mask;
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
