const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    ea: enc.MatchEffAddr(&[_]enc.AddrMode{.addr_reg, .imm, .pc_disp, .pc_idx}),
    size: enc.Size,
    pattern: enc.MatchBits(8, 0b0000_0110),
};

pub const Tester = struct {
    // addi.w #45,d0
    pub const code = [_]u16 { 0x0640, 0x002D };
    pub fn validate(state: *const cpu.State) bool {
        return state.regs.d[0] == 45 and state.cycles == 8;
    }
};

pub fn runWithSize(state: *cpu.State, comptime sz: enc.Size) void {
    // Get encoding
    const instr: Encoding = @bitCast(state.ir);
    
    // Fetch immidiate data
    const imm = state.programFetch(sz);
    
    // Calculate effective address
    const ea = cpu.EffAddr(sz).calc(state, instr.ea.m, instr.ea.xn);
    
    // Do the calculation
    const result: sz.getType(.unsigned) = ea.load(state) +% imm;
    
    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
    
    // Store the results
    ea.store(state, result);
    
    // Add extra cycles for long calculation
    if (sz == .long) state.cycles += 4;
}
