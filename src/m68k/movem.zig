const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

const Dir = enum(u1) {
    reg_to_mem,
    mem_to_reg,
};
pub const Encoding = packed struct {
    ea: enc.EffAddr,
    size: u1,
    pattern: enc.BitPattern(3, 0b001),
    dir: Dir,
    line: enc.BitPattern(5, 0b01001),
};
pub const Variant = packed struct {
    size: u1,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	4240           	clrw %d0 ; 4 cycles
    pub const code = [_]u16{ 0x4240 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 4);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    const mode = enc.AddrMode.fromEffAddr(encoding.ea).?;
    if (std.mem.indexOfScalar(enc.AddrMode, &[_]enc.AddrMode{
        .data_reg,
        .addr_reg,
        .imm,
    }, mode)) return false;
    if (encoding.dir == .mem_to_reg) {
        return mode != .addr_predec;
    } else {
        return mode != .addr_postinc and mode != .pc_idx and mode != .pc
    }
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const dst = cpu.EffAddr(args.size).calc(state, instr.dst);
    _ = dst.load(state); // Random read always for some reason idk m68k weird

    // Set flags and store result
    state.regs.sr.c = false;
    state.regs.sr.v = false;
    state.regs.sr.z = true;
    state.regs.sr.n = false;
    dst.store(state, 0);

    // Add processing time
    if (args.size == .long) {
        switch (dst) {
            .data_reg => state.cycles += 2,
            else => {},
        }
    }

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
