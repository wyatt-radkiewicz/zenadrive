const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.MatchEffAddr(&[_]enc.AddrMode{ .data_reg, .addr_reg, .imm, .pc_idx, .pc_disp }),
    size: enc.Size,
    dir: enc.MatchBits(1, 1),
    src: u3,
    line: enc.MatchBits(4, 0b1100),
};

pub const Tester = struct {
    const expect = @import("std").testing.expect;
    
    //    0:	c150           	and.w d0,(a0) ; 12 cycles
    //    2:	c590           	and.l d2,(a0) ; 20 cycles
    pub const code = [_]u16{ 0xC150, 0xC590 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 32);
    }
};

pub fn runWithSize(state: *cpu.State, comptime sz: enc.Size) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const dst_ea = cpu.EffAddr(sz).calc(state, instr.dst.m, instr.dst.xn);

    // Set flags and store result
    const res = dst_ea.load(state) & state.loadReg(.data, sz, instr.src);
    state.setLogicalFlags(sz, res);
    dst_ea.store(state, res);

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
