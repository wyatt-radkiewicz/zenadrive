const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    src: u3,
    rm: bool,
    pattern: enc.MatchBits(5, 0b10000),
    dst: u3,
    line: enc.MatchBits(4, 0b1100),
};
pub const ComptimeArgs = struct {};

pub const Tester = struct {
    const expect = @import("std").testing.expect;
    
    // abcd.b d0,d1 ; 6 cycles
    pub const code = [_]u16{ 0xC300 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 6);
    }
};

pub fn run(state: *cpu.State, comptime args: ComptimeArgs) void {
    // Get instruction encoding
    const instr: Encoding = @bitCast(state.ir);
    _ = args;

    // Get addressing mode
    const mode = enc.AddrMode.toModeBits(if (instr.rm)
        enc.AddrMode.addr_predec
    else
        enc.AddrMode.data_reg)[0];

    // Get source and destination ready
    const src = cpu.EffAddr(enc.Size.byte).calc(state, mode, instr.src).load(state);
    const dst_ea = cpu.EffAddr(enc.Size.byte).calc(state, mode, instr.dst);

    // Compute addition
    const extend: cpu.Bcd = @bitCast(@as(u8, @intFromBool(state.regs.sr.x)));
    var carry: u1 = 0;
    var bcd: cpu.Bcd = @bitCast(src);
    
    // Add the destination to source
    {
        const carry_res = cpu.Bcd.add(bcd, @bitCast(dst_ea.load(state)));
        bcd = carry_res[0];
        carry |= carry_res[1];
    }
    
    // Add extend bit
    {
        const carry_res = cpu.Bcd.add(bcd, extend);
        bcd = carry_res[0];
        carry |= carry_res[1];
    }
    
    // Save flags
    state.regs.sr.c = carry == 1;
    state.regs.sr.x = carry == 1;
    const byte = @as(u8, @bitCast(bcd));
    if (byte != 0) state.regs.sr.z = false;
    
    // Store back to destination
    dst_ea.store(state, byte);

    // Add processing time and fetch next instruction
    switch (dst_ea) {
        // Abcd seems to have some sort of optimization in the microcode for this so we
        // automatically remove 2 of the cycles that were added in effective address calculation
        .mem => state.cycles -= 2,
        
        // Otherwise it seems to add 2 cycles
        else => state.cycles += 2,
    }
    state.ir = state.programFetch(enc.Size.word);
}
