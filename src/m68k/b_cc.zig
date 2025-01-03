const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    disp: i8,
    cond: enc.Cond,
    line: enc.BitPattern(4, 0b0110),

    pub fn getLen(self: Encoding) usize {
        return if (self.disp == 0) 2 else 1;
    }

    pub fn match(comptime self: Encoding) bool {
        _ = self;
        return true;
    }
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	6700 0002      	beqw 4 <end> ; 12 cycles (not taken)
    pub const code = [_]u16{ 0x6700, 0x0002 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 12);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    // Get encoding
    const instr: Encoding = @bitCast(state.ir);

    // Get base pc counter
    const base = state.regs.pc;

    // Different paths based on instruction displacement size
    switch (instr.disp) {
        0 => {
            const disp_word: i16 = @bitCast(state.programFetch(enc.Size.word));
            const disp: u32 = @bitCast(@as(i32, disp_word));

            // Check if the branch succeeded
            if (state.regs.sr.satisfiesCond(instr.cond)) {
                state.cycles += 2;
                state.regs.pc = base +% disp;
            } else if (instr.cond == .false) {
                // Do branch to subroutine
                state.cycles += 2;
                state.pushVal(enc.Size.long, state.regs.pc);
                state.regs.pc = base +% disp;
            } else {
                state.cycles += 4;
            }

            // Get next instruction
            state.ir = state.programFetch(enc.Size.word);
        },
        else => {
            // Prefetch next instruction it seems
            state.ir = state.programFetch(enc.Size.word);

            // Check if the branch succeeded
            const disp: u32 = @bitCast(@as(i32, instr.disp));
            if (state.regs.sr.satisfiesCond(instr.cond)) {
                state.cycles += 2;
                state.regs.pc = base +% disp;
                state.ir = state.programFetch(enc.Size.word);
            } else if (instr.cond == .false) {
                // Do branch to subroutine
                state.cycles += 2;
                state.pushVal(enc.Size.long, state.regs.pc);
                state.regs.pc = base +% disp;
                state.ir = state.programFetch(enc.Size.word);
            } else {
                state.cycles += 4;
            }
        },
    }
}
