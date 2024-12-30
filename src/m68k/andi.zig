const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.MatchEffAddr(&[_]enc.AddrMode{ .addr_reg, .imm, .pc_idx, .pc_disp }),
    size: enc.Size,
    pattern: enc.MatchBits(8, 0b0000_0010),
};

pub const Tester = struct {
    const expect = @import("std").testing.expect;
    
    // 0:	0241 f0f0      	andi.w #-3856,d1         ; 8 cycles
    // 4:	0280 f0f0 f0f0 	andi.l #-252645136,d0    ; 16 cycles
    pub const code = [_]u16{
        0x0241, 0xF0F0,
        0x0280, 0xF0F0,
        0xF0F0,
    };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 24);
    }
};

pub fn runWithSize(state: *cpu.State, comptime sz: enc.Size) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const imm = state.programFetch(sz);
    const dst = cpu.EffAddr(sz).calc(state, instr.dst.m, instr.dst.xn);

    // Set flags and store result
    const res = imm & dst.load(state);
    state.setLogicalFlags(sz, res);
    dst.store(state, res);

    // Add processing time
    if (sz == .long) {
        switch (dst) {
            .data_reg => state.cycles += 4,
            else => {},
        }
    }

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
