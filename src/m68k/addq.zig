const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.MatchEffAddr(&[_]enc.AddrMode{ .imm, .pc_idx, .pc_disp }),
    size: enc.Size,
    padding: enc.MatchBits(1, 0),
    data: u3,
    line: enc.MatchBits(4, 0b0101),
};

pub const Tester = struct {
    // 0:	5648           	addqw #3,%a0 ; 8 cycles
    // 2:	5680           	addql #3,%d0 ; 8 cycles
    pub const code = [_]u16{ 0x5648, 0x5680 };
    pub fn validate(state: *const cpu.State) bool {
        if (state.cycles != 16) return false;
        return true;
    }
};

pub fn runWithSize(state: *cpu.State, comptime sz: enc.Size) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const imm: sz.getType(.unsigned) = instr.data;
    const dst = cpu.EffAddr(sz).calc(state, instr.dst.m, instr.dst.xn);

    // Set flags and store result
    const sr_backup = state.regs.sr;
    const res = state.addWithFlags(sz, imm, dst.load(state));
    
    // Only update flags if we are not adding to an address register
    switch (dst) {
        .addr_reg => state.regs.sr = sr_backup,
        else => {},
    }
    dst.store(state, res);

    // Add processing time
    state.cycles += switch (dst) {
        .data_reg => if (sz == .long) 4 else 0,
        .addr_reg => 4,
        else => 0,
    };
    
    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}