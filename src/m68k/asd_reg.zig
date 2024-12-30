const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: u3,
    pattern: enc.MatchBits(2, 0b00),
    isreg: bool,
    size: enc.Size,
    dir: enc.ShiftDir,
    cnt: u3,
    line: enc.MatchBits(4, 0b1110),
};

pub const Tester = struct {
    const expect = @import("std").testing.expect;
    
    // 0:	e900           	asl.b #4,d0   ; 14 cycles
    // 2:	e420           	asr.b d2,d0   ; 6+2(m = 0) cycles
    pub const code = [_]u16{ 0xE900, 0xE420 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 20);
    }
};

pub fn runWithSize(state: *cpu.State, comptime sz: enc.Size) void {
    // Get encoding
    const instr: Encoding = @bitCast(state.ir);

    // Do operation
    const shift_amount: u6 = if (instr.isreg) @truncate(state.regs.d[instr.cnt]) else instr.cnt;
    state.storeReg(.data, sz, instr.dst, switch (instr.dir) {
        inline else => |dir| state.arithShiftWithFlags(
            sz,
            dir,
            state.loadReg(.data, sz, instr.dst),
            shift_amount,
        ),
    });

    // Add processing time and fetch next instruction
    state.cycles += if (sz == .long) 4 else 2;
    state.ir = state.programFetch(enc.Size.word);
}
