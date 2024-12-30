const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.EffAddr,
    pattern1: enc.BitPattern(2, 0b11),
    dir: enc.ShiftDir,
    pattern2: enc.BitPattern(7, 0b1110_000),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;
    
    // 0:	e1d0           	asl.w (a0) ; 12 cycles
    // 2:	e0d0           	asr.w (a0) ; 12 cycles
    pub const code = [_]u16{ 0xE1D0, 0xE0D0 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 24);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    _ = std.mem.indexOfScalar(enc.AddrMode, &[_]enc.AddrMode{
        .data_reg,
        .addr_reg,
        .imm,
        .pc_idx,
        .pc_disp,
    }, enc.AddrMode.fromEffAddr(encoding.dst).?) orelse return true;
    return false;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    // Get encoding
    const instr: Encoding = @bitCast(state.ir);
    const dst_ea = cpu.EffAddr(enc.Size.word).calc(state, instr.dst);

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
