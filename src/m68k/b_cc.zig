const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    disp: i8,
    cond: enc.MatchCond(&[_]enc.Cond{ .true, .false }),
    line: enc.MatchBits(4, 0b0110),
};

pub const Tester = struct {
    // 0:	6700 0002      	beqw 4 <end> ; 12 cycles (not taken)
    pub const code = [_]u16{ 0x6700, 0x0002 };
    pub fn validate(state: *const cpu.State) bool {
        if (state.cycles != 12) return false;
        return true;
    }
};

pub fn run(state: *cpu.State) void {
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
            if (state.regs.sr.satisfiesCond(instr.cond.val)) {
                state.cycles += 2;
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
            if (state.regs.sr.satisfiesCond(instr.cond.val)) {
                const disp: u32 = @bitCast(@as(i32, instr.disp));
                state.cycles += 2;
                state.regs.pc = base +% disp;
                state.ir = state.programFetch(enc.Size.word);
            } else {
                state.cycles += 4;
            }
        }
    }
}
