const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    src: enc.MatchEffAddr(&[0]enc.AddrMode{}),
    size: enc.Size,
    dir: enc.MatchBits(1, 0),
    dst: u3,
    line: enc.MatchBits(4, 0b1101),
};

pub const Tester = struct {
    //    0:	d240           	addw %d0,%d1  ; 4 cycles
    //    2:	d682           	addl %d2,%d3  ; 8 cycles
    pub const code = [_]u16{ 0xD240, 0xD682 };
    pub fn validate(state: *const cpu.State) bool {
        if (state.cycles != 12) return false;
        return true;
    }
};

pub fn runWithSize(state: *cpu.State, comptime sz: enc.Size) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const src_ea = cpu.EffAddr(sz).calc(state, instr.src.m, instr.src.xn);
    
    // Don't run if size if byte and we are using address register direct mode
    if (sz == .byte) {
        switch (src_ea) {
            .addr_reg => {
                state.pending_exception = @intFromEnum(cpu.Vector.illegal_instr);
                return;
            },
            else => {},
        }
    }
    
    // Set flags and store result
    const res = cpu.AddFlags(sz).add(src_ea.load(state), state.loadReg(.data, sz, instr.dst));
    state.setArithFlags(sz, res);
    state.storeReg(.data, sz, instr.dst, res.val);

    // Add processing time and fetch next instruction
    state.cycles += switch (sz) {
        .byte, .word => 0,
        .long => switch (src_ea) {
            .data_reg, .addr_reg => 4,
            else => 2,
        },
    };
    state.ir = state.programFetch(enc.Size.word);
}
