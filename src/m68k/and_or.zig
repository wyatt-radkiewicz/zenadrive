const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

const Op = enum(u1) { @"or", @"and" };
pub const Encoding = packed struct {
    ea: enc.EffAddr,
    size: enc.Size,
    dir: enc.OpDir,
    dn: u3,
    line: enc.BitPattern(2, 0b00),
    op: Op,
    line_msb: enc.BitPattern(1, 0b1),
};
pub const Variant = packed struct {
    size: enc.Size,
    dir: enc.OpDir,
};

pub const Tester = struct {
    const expect = std.testing.expect;

    // 1100_001_0_01_000_000
    // 0:	c240           	and.w d0,d1      ; 4 cycles
    // 2:	c0a0           	and.l -(a0),d0   ; 16 cycles
    pub const code = [_]u16{ 0xC240, 0xC0A0 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 20);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    return enc.AddrMode.fromEffAddr(encoding.ea).?.getAdditionalSize(encoding.size);
}
pub fn match(comptime encoding: Encoding) bool {
    if (encoding.dir == .dn_ea_store_dn) {
        return enc.AddrMode.fromEffAddr(encoding.ea).? != .addr_reg;
    } else {
        return switch (enc.AddrMode.fromEffAddr(encoding.ea).?) {
            .data_reg, .addr_reg, .imm, .pc_idx, .pc_disp => false,
            else => true,
        };
    }
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);

    // Set flags and store result
    if (args.dir == .dn_ea_store_dn) {
        const src_ea = cpu.EffAddr(args.size).calc(state, instr.ea);
        const lhs = src_ea.load(state);
        const rhs = state.loadReg(.data, args.size, instr.dn);
        const res = switch (instr.op) {
            .@"and" => lhs & rhs,
            .@"or" => lhs | rhs,
        };
        state.setLogicalFlags(args.size, res);
        state.storeReg(.data, args.size, instr.dn, res);

        // Add processing time and fetch next instruction
        if (args.size == .long) {
            state.cycles += switch (src_ea) {
                .mem => 2,
                else => 4,
            };
        }
    } else {
        const dst_ea = cpu.EffAddr(args.size).calc(state, instr.ea);
        const lhs = dst_ea.load(state);
        const rhs = state.loadReg(.data, args.size, instr.dn);
        const res = switch (instr.op) {
            .@"and" => lhs & rhs,
            .@"or" => lhs | rhs,
        };
        state.setLogicalFlags(args.size, res);
        dst_ea.store(state, res);
    }

    state.ir = state.programFetch(enc.Size.word);
}
