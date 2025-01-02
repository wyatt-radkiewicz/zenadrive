const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

const Op = enum(u1) { sub, add };
pub const Encoding = packed struct {
    ea: enc.EffAddr,
    size: enc.Size,
    dir: enc.OpDir,
    dn: u3,
    line: enc.BitPattern(2, 0b01),
    op: Op,
    line_msb: enc.BitPattern(1, 1),
};
pub const Variant = packed struct {
    op: Op,
    dir: enc.OpDir,
    size: enc.Size,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	d240           	add.w d0,d1   ; 4 cycles
    //    2:	d682           	add.l d2,d3   ; 8 cycles
    //    4:	d150           	add.w d0,(a0) ; 12 cycles
    //    6:	d590           	add.l d2,(a0) ; 20 cycles
    pub const code = [_]u16{ 0xD240, 0xD682, 0xD150, 0xD590 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 44);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    const mode = enc.AddrMode.fromEffAddr(encoding.ea).?;
    if (encoding.dir == .dn_ea_store_dn) {
        return encoding.size != .byte or mode != .addr_reg;
    } else {
        return switch (mode) {
            .data_reg, .addr_reg, .imm, .pc_idx, .pc_disp => false,
            else => true,
        };
    }
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const ea = cpu.EffAddr(args.size).calc(state, instr.ea);

    // Set flags and store result
    if (args.dir == .dn_ea_store_dn) {
        const dst = state.loadReg(.data, args.size, instr.dn);
        const res = switch (args.op) {
            .add => state.addWithFlags(args.size, ea.load(state), dst),
            .sub => state.subWithFlags(args.size, ea.load(state), dst),
        };
        state.regs.sr.x = state.regs.sr.c;
        state.storeReg(.data, args.size, instr.dn, res);

        // Add processing time
        if (args.size == .long) {
            state.cycles += switch (ea) {
                .mem => 2,
                else => 4,
            };
        }
    } else {
        const src = state.loadReg(.data, args.size, instr.dn);
        const res = switch (args.op) {
            .add => state.addWithFlags(args.size, ea.load(state), src),
            .sub => state.subWithFlags(args.size, ea.load(state), src),
        };
        ea.store(state, res);
    }

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
