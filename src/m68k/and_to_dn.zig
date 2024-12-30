const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    src: enc.MatchEffAddr(&[_]enc.AddrMode{.addr_reg}),
    size: enc.Size,
    dir: enc.MatchBits(1, 0),
    dst: u3,
    line: enc.MatchBits(4, 0b1100),
};

pub const Tester = struct {
    const expect = @import("std").testing.expect;
    
    // 1100_001_0_01_000_000
    // 0:	c240           	and.w d0,d1      ; 4 cycles
    // 2:	c0a0           	and.l -(a0),d0   ; 16 cycles
    pub const code = [_]u16{ 0xC240, 0xC0A0 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 20);
    }
};

pub fn runWithSize(state: *cpu.State, comptime sz: enc.Size) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const src_ea = cpu.EffAddr(sz).calc(state, instr.src.m, instr.src.xn);
    
    // Set flags and store result
    const res = src_ea.load(state) & state.loadReg(.data, sz, instr.dst);
    state.setLogicalFlags(sz, res);
    state.storeReg(.data, sz, instr.dst, res);

    // Add processing time and fetch next instruction
    if (sz == .long) {
        state.cycles += switch(src_ea) {
            .mem => 2,
            else => 4,
        };
    }
    state.ir = state.programFetch(enc.Size.word);
}
