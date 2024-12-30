const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    src: enc.EffAddr,
    pattern: enc.BitPattern(2, 0b11),
    size: u1,
    dst: u3,
    line: enc.BitPattern(4, 0b1101),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = @import("std").testing.expect;
    
    // 0:	d0c0           	adda.w d0,a0      ; 8 cycles
    // 2:	d1d0           	adda.l (a0),a0    ; 14 cycles
    pub const code = [_]u16{ 0xD0C0, 0xD1D0 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 22);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    const instr: Encoding = @bitCast(state.ir);
    _ = args;

    // Compute source effective address and sign extend
    const src = get_src: {
        switch (enc.Size.fromBit(instr.size)) {
            inline else => |sz| {
                const ea = cpu.EffAddr(sz).calc(state, instr.src);
                state.cycles += switch (sz) {
                    .byte => unreachable,
                    .word => 4,
                    .long => switch (ea) {
                        .mem => 2,
                        else => 4,
                    },
                };
                break :get_src cpu.extendFull(sz, ea.load(state));
            },
        }
    };

    // Set flags and store result
    const res = src +% state.loadReg(.addr, enc.Size.long, instr.dst);
    state.storeReg(.addr, enc.Size.long, instr.dst, res);

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
