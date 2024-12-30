const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.MatchEffAddr(&[_]enc.AddrMode{ .addr_reg, .imm, .pc_idx, .pc_disp }),
    size: enc.Size,
    pattern: enc.MatchBits(8, 0b0000_0110),
};

pub const Tester = struct {
    // 0:	0650 ffff      	addi.w #-1,(a0)    ; 16 cycles
    // 4:	0680 ffff ffff 	addi.l #-1,d0      ; 16 cycles
    pub const code = [_]u16{
        0x0650, 0xFFFF,
        0x0680, 0xFFFF,
        0xFFFF,
    };
    pub fn validate(state: *const cpu.State) bool {
        if (state.cycles != 32) return false;
        return true;
    }
};

pub fn runWithSize(state: *cpu.State, comptime sz: enc.Size) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const imm = state.programFetch(sz);
    const dst = cpu.EffAddr(sz).calc(state, instr.dst.m, instr.dst.xn);

    // Set flags and store result
    const res = state.addWithFlags(sz, imm, dst.load(state));
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