const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.MatchEffAddr(&[_]enc.AddrMode{ .data_reg, .addr_reg, .imm, .pc_idx, .pc_disp }),
    size: enc.Size,
    dir: enc.MatchBits(1, 1),
    src: u3,
    line: enc.MatchBits(4, 0b1101),
};

pub const Tester = struct {
    //    0:	d150           	add.w d0,(a0) ; 12 cycles
    //    2:	d590           	add.l d2,(a0) ; 20 cycles
    pub const code = [_]u16{ 0xD150, 0xD590 };
    pub fn validate(state: *const cpu.State) bool {
        if (state.cycles != 32) return false;
        return true;
    }
};

pub fn runWithSize(state: *cpu.State, comptime sz: enc.Size) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const dst_ea = cpu.EffAddr(sz).calc(state, instr.dst.m, instr.dst.xn);

    // Set flags and store result
    const res = state.addWithFlags(sz, dst_ea.load(state), state.loadReg(.data, sz, instr.src));
    dst_ea.store(state, res);

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
