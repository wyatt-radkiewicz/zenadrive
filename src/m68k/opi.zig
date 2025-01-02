const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: enc.EffAddr,
    size: enc.Size,
    pattern: enc.BitPattern(1, 0),
    op: enc.ImmOp,
    line: enc.BitPattern(4, 0b0000),
};
pub const Variant = packed struct {
    size: enc.Size,
    op: enc.ImmOp,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	0650 ffff      	addi.w #-1,(a0)    ; 16 cycles
    // 4:	0680 ffff ffff 	addi.l #-1,d0      ; 16 cycles
    pub const code = [_]u16{
        0x0650, 0xFFFF,
        0x0680, 0xFFFF,
        0xFFFF,
    };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 32);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(encoding.dst).?) {
        .addr_reg, .imm, .pc_idx, .pc_disp => false,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const imm = state.programFetch(args.size);
    const dst = cpu.EffAddr(args.size).calc(state, instr.dst);

    // Set flags and store result
    switch (args.op) {
        .addi => {
            const res = state.addWithFlags(args.size, imm, dst.load(state));
            state.regs.sr.x = state.regs.sr.c;
            dst.store(state, res);
        },
        .andi => {
            const res = imm & dst.load(state);
            state.setLogicalFlags(args.size, res);
            dst.store(state, res);
        },
        .eori => {
            const res = imm ^ dst.load(state);
            state.setLogicalFlags(args.size, res);
            dst.store(state, res);
        },
        .ori => {
            const res = imm | dst.load(state);
            state.setLogicalFlags(args.size, res);
            dst.store(state, res);
        },
        .subi => {
            // TODO:
            const res = state.addWithFlags(args.size, imm, dst.load(state));
            state.regs.sr.x = state.regs.sr.c;
            dst.store(state, res);
        },
    }

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
