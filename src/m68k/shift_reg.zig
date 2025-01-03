const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    dst: u3,
    op: enc.ShiftOp,
    isreg: bool,
    size: enc.Size,
    dir: enc.ShiftDir,
    cnt: u3,
    line: enc.BitPattern(4, 0b1110),

    pub fn getLen(self: Encoding) usize {
        _ = self;
        return 1;
    }

    pub fn match(comptime self: Encoding) bool {
        _ = self;
        return true;
    }
};
pub const Variant = packed struct {
    op: enc.ShiftOp,
    size: enc.Size,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	e900           	asl.b #4,d0   ; 14 cycles
    // 2:	e420           	asr.b d2,d0   ; 6+2(m = 0) cycles
    pub const code = [_]u16{ 0xE900, 0xE420 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 20);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Get encoding
    const instr: Encoding = @bitCast(state.ir);

    // Do operation
    const by: u6 = if (instr.isreg) @truncate(state.regs.d[instr.cnt]) else instr.cnt;
    const reg = state.loadReg(.data, args.size, instr.dst);
    state.storeReg(.data, args.size, instr.dst, switch (instr.dir) {
        inline else => |dir| switch (args.op) {
            .shift_arith, .shift_logic => state.shiftWithFlags(args.size, args.op, dir, reg, by),
            .rotate, .rotate_extended => state.rotateWithFlags(args.size, args.op, dir, reg, by),
        },
    });

    // Add processing time and fetch next instruction
    state.cycles += if (args.size == .long) 4 else 2;
    state.ir = state.programFetch(enc.Size.word);
}
