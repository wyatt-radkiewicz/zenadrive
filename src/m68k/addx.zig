const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    src: u3,
    rm: bool,
    pattern2: enc.MatchBits(2, 0),
    size: enc.Size,
    pattern1: enc.MatchBits(1, 1),
    dst: u3,
    line: enc.MatchBits(4, 0b1101),
};

pub const Tester = struct {
    const expect = @import("std").testing.expect;
    
    // 0:	d348           	addx.w -(a0),-(a1)  ; 18 cycles
    // 2:	d181           	addx.l d1,d0        ; 8 cycles
    pub const code = [_]u16{ 0xD348, 0xD181 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 26);
    }
};

pub fn runWithSize(state: *cpu.State, comptime sz: enc.Size) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const mode = enc.AddrMode.toModeBits(if (instr.rm)
        enc.AddrMode.addr_predec
    else
        enc.AddrMode.data_reg)[0];
    const src_ea = cpu.EffAddr(sz).calc(state, mode, instr.src);
    const dst_ea = cpu.EffAddr(sz).calc(state, mode, instr.dst);

    // Set flags and store result
    const extend: sz.getType(.unsigned) = @intFromBool(state.regs.sr.x);
    const with_one = state.addWithFlags(sz, extend, dst_ea.load(state));
    const sr = state.regs.sr;
    const res = state.addWithFlags(sz, src_ea.load(state), with_one);
    state.regs.sr.c = state.regs.sr.c or sr.c;
    state.regs.sr.v = state.regs.sr.v or sr.v;
    if (res != 0) state.regs.sr.z = false;
    state.regs.sr.n = @as(sz.getType(.signed), @bitCast(res)) < 0;
    state.regs.sr.x = state.regs.sr.c;
    dst_ea.store(state, res);

    // Add processing time
    switch (dst_ea) {
        // Addx seems to have some sort of optimization in the microcode for this so we
        // automatically remove 2 of the cycles that were added in effective address calculation
        .mem => state.cycles -= 2,
        else => state.cycles += if (sz == .long) 4 else 0,
    }
    
    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}