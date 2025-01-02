const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

const Op = enum(u1) { addx, subx };
pub const Encoding = packed struct {
    src: u3,
    rm: bool,
    pattern2: enc.BitPattern(2, 0),
    size: enc.Size,
    pattern1: enc.BitPattern(1, 1),
    dst: u3,
    line: enc.BitPattern(2, 0b01),
    op: Op,
    line_msb: enc.BitPattern(1, 1),
};
pub const Variant = packed struct {
    size: enc.Size,
};

pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	d348           	addx.w -(a0),-(a1)  ; 18 cycles
    // 2:	d181           	addx.l d1,d0        ; 8 cycles
    pub const code = [_]u16{ 0xD348, 0xD181 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 26);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const addrmode = if (instr.rm)
        enc.AddrMode.addr_predec
    else
        enc.AddrMode.data_reg;
    const mode = addrmode.toEffAddr().m;
    const src_ea = cpu.EffAddr(args.size).calc(state, .{ .m = mode, .xn = instr.src });
    const dst_ea = cpu.EffAddr(args.size).calc(state, .{ .m = mode, .xn = instr.dst });

    // Set flags and store result
    const extend: args.size.getType(.unsigned) = @intFromBool(state.regs.sr.x);
    const mathop = switch (instr.op) {
        .addx => &cpu.State.addWithFlags,
        .subx => &cpu.State.subWithFlags,
    };
    const with_one = mathop(state, args.size, extend, dst_ea.load(state));
    const sr = state.regs.sr;
    const res = mathop(state, args.size, src_ea.load(state), with_one);
    state.regs.sr.c = state.regs.sr.c or sr.c;
    state.regs.sr.v = state.regs.sr.v or sr.v;
    if (res != 0) state.regs.sr.z = false;
    state.regs.sr.n = @as(args.size.getType(.signed), @bitCast(res)) < 0;
    state.regs.sr.x = state.regs.sr.c;
    dst_ea.store(state, res);

    // Add processing time
    switch (dst_ea) {
        // Addx seems to have some sort of optimization in the microcode for this so we
        // automatically remove 2 of the cycles that were added in effective address calculation
        .mem => state.cycles -= 2,
        else => state.cycles += if (args.size == .long) 4 else 0,
    }

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
