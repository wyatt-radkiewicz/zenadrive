const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.EffAddr,
    size: enc.Size,
    pattern: enc.BitPattern(8, 0b0000_0010),
};
pub const Variant = packed struct {
    size: enc.Size,
};
pub const Tester = struct {
    const expect = @import("std").testing.expect;
    
    // 0:	0241 f0f0      	andi.w #-3856,d1         ; 8 cycles
    // 4:	0280 f0f0 f0f0 	andi.l #-252645136,d0    ; 16 cycles
    pub const code = [_]u16{
        0x0241, 0xF0F0,
        0x0280, 0xF0F0,
        0xF0F0,
    };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 24);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    _ = std.mem.indexOfScalar(enc.AddrMode, &[_]enc.AddrMode{
        .addr_reg,
        .imm,
        .pc_idx,
        .pc_disp,
    }, enc.AddrMode.fromEffAddr(encoding.dst).?) orelse return true;
    return false;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const imm = state.programFetch(args.size);
    const dst = cpu.EffAddr(args.size).calc(state, instr.dst);

    // Set flags and store result
    const res = imm & dst.load(state);
    state.setLogicalFlags(args.size, res);
    dst.store(state, res);

    // Add processing time
    if (args.size == .long) {
        switch (dst) {
            .data_reg => state.cycles += 4,
            else => {},
        }
    }

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
