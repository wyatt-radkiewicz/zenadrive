const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    ea: enc.MatchEffAddr(&[]enc.AddrMode{.addr_reg, .imm, .pc_disp, .pc_idx}),
    size: enc.Size,
    pattern: enc.MatchBits(8, 0b0000_0110),
};

pub fn run(state: *cpu.State, instr: Encoding, comptime sz: enc.Size) void {
    // Fetch immidiate data
    const imm = state.programFetch(sz);
    
    // Calculate effective address
    const ea = cpu.EffAddr(sz).calc(state, instr.ea.m, instr.ea.xn);
    
    // Do the calculation
    const result: sz.getType() = ea.load(state) +% imm;
    
    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
    
    // Store the results
    ea.store(result);
    
    // Add extra cycles for long calculation
    if (sz == .long) state.cycles += 4;
}

