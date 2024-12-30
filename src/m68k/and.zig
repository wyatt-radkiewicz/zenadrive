const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    ea: enc.EffAddr,
    size: enc.Size,
    dir: enc.OpDir,
    dn: u3,
    line: enc.BitPattern(4, 0b1100),
};
pub const Variant = packed struct {
    size: enc.Size,
    dir: enc.OpDir,
};

pub const Tester = struct {
    const expect = @import("std").testing.expect;

    // 1100_001_0_01_000_000
    // 0:	c240           	and.w d0,d1      ; 4 cycles
    // 2:	c0a0           	and.l -(a0),d0   ; 16 cycles
    pub const code = [_]u16{ 0xC240, 0xC0A0 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 20);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    if (encoding.dir == .dn_ea_store_dn) {
        return enc.AddrMode.fromEffAddr(encoding.ea).? != .addr_reg;
    } else {
        _ = std.mem.indexOfScalar(enc.AddrMode, &[_]enc.AddrMode{
            .data_reg, .addr_reg, .imm, .pc_idx, .pc_disp,
        }, enc.AddrMode.fromEffAddr(encoding.ea).?) orelse return true;
        return false;
    }
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    
    // Set flags and store result
    if (args.dir == .dn_ea_store_dn) {
        const src_ea = cpu.EffAddr(args.size).calc(state, instr.ea);
        const res = src_ea.load(state) & state.loadReg(.data, args.size, instr.dn);
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
        const res = dst_ea.load(state) & state.loadReg(.data, args.size, instr.dn);
        state.setLogicalFlags(args.size, res);
        dst_ea.store(state, res);
    }
    
    state.ir = state.programFetch(enc.Size.word);
}