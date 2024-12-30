const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    ea: enc.EffAddr,
    size: enc.Size,
    dir: enc.OpDir,
    dn: u3,
    line: enc.BitPattern(4, 0b1101),
};
pub const Variant = packed struct {
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
        if (encoding.size == .byte and mode == .addr_reg) return false;
    } else {
        if (std.mem.indexOfScalar(enc.AddrMode, &[_]enc.AddrMode{
            .data_reg, .addr_reg, .imm, .pc_idx, .pc_disp,
        }, mode)) |_| {
            return false;
        }
    }
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const ea = cpu.EffAddr(args.size).calc(state, instr.ea);

    // Set flags and store result
    if (args.dir == .dn_ea_store_dn) {
        const dst = state.loadReg(.data, args.size, instr.dn);
        const res = state.addWithFlags(args.size, ea.load(state), dst);
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
        const res = state.addWithFlags(args.size, ea.load(state), src);
        ea.store(state, res);
    }
    
    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
