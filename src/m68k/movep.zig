const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

const Dir = enum(u1) {
    mem_to_reg,
    reg_to_mem,
};
pub const Encoding = packed struct {
    an: u3,
    pattern: enc.BitPattern(3, 0b001),
    size: u1,
    dir: Dir,
    pattern1: enc.BitPattern(1, 1),
    dn: u3,
    line: enc.BitPattern(4, 0b0000),
};
pub const Variant = packed struct {
    size: u1,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	0188 0000      	movepw %d0,%a0@(0)
    pub const code = [_]u16{ 0x0188, 0x0000 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 16);
    }
};

pub fn match(comptime encoding: Encoding) bool {
    _ = encoding;
    return true;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    const size = comptime enc.Size.fromBit(args.size);
    const instr: Encoding = @bitCast(state.ir);
    const disp = cpu.extendFull(enc.Size.word, state.programFetch(enc.Size.word));
    const Data = size.getType(.unsigned);
    const nbytes = @sizeOf(Data);
    var addr = state.regs.a[instr.an] +% disp;
    switch (instr.dir) {
        .reg_to_mem => {
            const bytes = blk: {
                var bytes: [nbytes]u8 = undefined;
                std.mem.writeInt(Data, &bytes, state.loadReg(.data, size, instr.dn), .big);
                break :blk bytes;
            };
            for (bytes) |byte| {
                state.wrBus(size, addr, byte);
                addr += 2;
            }
        },
        .mem_to_reg => {
            var bytes: [nbytes]u8 = undefined;
            for (&bytes) |*byte| {
                byte.* = state.rdBus(enc.Size.byte, addr);
                addr += 2;
            }
            state.storeReg(.data, size, instr.dn, std.mem.readInt(Data, &bytes, .big));
        },
    }
    state.ir = state.programFetch(enc.Size.word);
}
