const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    src: enc.MatchEffAddr(&[0]enc.AddrMode{}),
    size: enc.Size,
    dir: enc.MatchBits(1, 0),
    dst: u3,
    line: enc.MatchBits(4, 0b1101),
};
pub const ComptimeArgs = struct {
    size: enc.Size,
};

pub const Tester = struct {
    const expect = @import("std").testing.expect;
    
    //    0:	d240           	addw %d0,%d1  ; 4 cycles
    //    2:	d682           	addl %d2,%d3  ; 8 cycles
    pub const code = [_]u16{ 0xD240, 0xD682 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 12);
    }
};

pub fn run(state: *cpu.State, comptime args: ComptimeArgs) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const src_ea = cpu.EffAddr(args.size).calc(state, instr.src.m, instr.src.xn);
    
    // Don't run if size if byte and we are using address register direct mode
    if (args.size == .byte) {
        switch (src_ea) {
            .addr_reg => {
                state.pending_exception = @intFromEnum(cpu.Vector.illegal_instr);
                return;
            },
            else => {},
        }
    }
    
    // Set flags and store result
    const dst = state.loadReg(.data, args.size, instr.dst);
    const res = state.addWithFlags(args.size, src_ea.load(state), dst);
    state.storeReg(.data, args.size, instr.dst, res);

    // Add processing time and fetch next instruction
    if (args.size == .long) {
        state.cycles += switch (src_ea) {
            .mem => 2,
            else => 4,
        };
    }
    state.ir = state.programFetch(enc.Size.word);
}
