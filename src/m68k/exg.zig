const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

const Mode = enum(u5) {
    data = 0b01000,
    addr = 0b01001,
    both = 0b10001,
    
    pub fn match(bits: u5) bool {
        _ = std.meta.intToEnum(Mode, bits) catch return false;
        return true;
    }
};
pub const Encoding = packed struct {
    y: u3,
    mode: Mode,
    pattern: enc.BitPattern(1, 1),
    x: u3,
    line: enc.BitPattern(4, 0b1100),
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;
    
    //    0:	c188           	exg %d0,%a0
    pub const code = [_]u16{ 0xC188 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 6);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    _ = encoding;
    return 0;
}
pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    _ = args;
    const instr: Encoding = @bitCast(state.ir);
    switch (instr.mode) {
        .data => {
            const tmp = state.regs.d[instr.x];
            state.regs.d[instr.x] = state.regs.d[instr.y];
            state.regs.d[instr.y] = tmp;
        },
        .addr => {
            const tmp = state.regs.a[instr.x];
            state.regs.a[instr.x] = state.regs.a[instr.y];
            state.regs.a[instr.y] = tmp;
        },
        .both => {
            const tmp = state.regs.d[instr.x];
            state.regs.d[instr.x] = state.regs.a[instr.y];
            state.regs.a[instr.y] = tmp;
        },
    }
    state.cycles += 2;
    state.ir = state.programFetch(enc.Size.word);
}