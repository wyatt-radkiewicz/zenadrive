const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    reg: u3,
    pattern: enc.BitPattern(5, 0b11001),
    cond: enc.Cond,
    line: enc.BitPattern(4, 0b0101),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;
    
    //    0:	56c8 0002      	dbne %d0,4 <end> ; (not taken)
    pub const code = [_]u16{ 0x56C8, 0x0002 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 12);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    // Get encoding
    const instr: Encoding = @bitCast(state.ir);

    // Get base pc counter
    const base = state.regs.pc;
    const disp: u32 = cpu.extendFull(enc.Size.word, state.programFetch(enc.Size.word));
    if (state.regs.sr.satisfiesCond(instr.cond)) {
        state.cycles += 4;
    } else {
        const dec = state.loadReg(.data, enc.Size.word, instr.reg) -% 1;
        state.storeReg(.data, enc.Size.word, instr.reg, dec);
        if (dec != std.math.maxInt(@TypeOf(dec))) {
            state.regs.pc = base +% disp;
            state.cycles += 2;
        } else {
            state.cycles += 6;
        }
    }
    
    state.ir = state.programFetch(enc.Size.word);
}
