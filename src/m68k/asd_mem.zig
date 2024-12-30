const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.MatchEffAddr(&[_]enc.AddrMode{.data_reg, .addr_reg, .imm, .pc_disp, .pc_idx}),
    pattern1: enc.MatchBits(2, 0b11),
    dir: enc.ShiftDir,
    pattern2: enc.MatchBits(7, 0b1110_000),
};

pub const Tester = struct {
    // 0:	e1d0           	asl.w (a0) ; 12 cycles
    // 2:	e0d0           	asr.w (a0) ; 12 cycles
    pub const code = [_]u16{ 0xE1D0, 0xE0D0 };
    pub fn validate(state: *const cpu.State) bool {
        if (state.cycles != 24) return false;
        return true;
    }
};

pub fn run(state: *cpu.State) void {
    // Get encoding
    const instr: Encoding = @bitCast(state.ir);
    const dst_ea = cpu.EffAddr(enc.Size.word).calc(state, instr.dst.m, instr.dst.xn);

    // Do operation
    dst_ea.store(state, switch (instr.dir) {
        inline else => |dir| state.arithShiftWithFlags(
            enc.Size.word,
            dir,
            dst_ea.load(state),
            1,
        ),
    });

    // Micro-code for asD <ea> is sligtly different and doesn't cost any shift cycles
    state.cycles -= 2;
    
    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
