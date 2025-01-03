const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");
const fmt = @import("cpu/fmt.zig");

const Op = enum(u1) { abcd, sbcd };
pub const Encoding = packed struct {
    src: u3,
    rm: bool,
    pattern: enc.BitPattern(5, 0b10000),
    dst: u3,
    line: enc.BitPattern(2, 0b00),
    op: Op,
    line_msb: enc.BitPattern(1, 0b1),

    pub fn getLen(self: Encoding) usize {
        _ = self;
        return 1;
    }

    pub fn match(comptime self: Encoding) bool {
        _ = self;
        return true;
    }
};
pub const Fmt = struct {
    fmt: Encoding,
    data: *fmt.State,

    pub fn format(self: Fmt, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const addrmode = if (self.fmt.rm) enc.AddrMode.addr_predec else enc.AddrMode.data_reg;
        const mode = addrmode.toEffAddr().m;
        try writer.print("{s}.b {s},{s}", .{
            @tagName(self.fmt.op),
            fmt.EffAddr.init(self.data, .{ .m = mode, .xn = self.fmt.src }, null),
            fmt.EffAddr.init(self.data, .{ .m = mode, .xn = self.fmt.dst }, null),
        });
    }
};
pub const Variant = packed struct {};
pub const Tester = struct {
    const expect = std.testing.expect;

    // abcd.b d0,d1 ; 6 cycles
    pub const code = [_]u16{0xC300};
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 6);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Get instruction encoding
    const instr: Encoding = @bitCast(state.ir);
    _ = args;

    // Get effective addressing mode
    const addrmode = if (instr.rm) enc.AddrMode.addr_predec else enc.AddrMode.data_reg;
    const mode = addrmode.toEffAddr().m;

    // Get source and destination ready
    const src = cpu.EffAddr(enc.Size.byte).calc(state, .{ .m = mode, .xn = instr.src }).load(state);
    const dst_ea = cpu.EffAddr(enc.Size.byte).calc(state, .{ .m = mode, .xn = instr.dst });

    // Compute addition
    const lhs: cpu.Bcd = @bitCast(dst_ea.load(state));
    const rhs: cpu.Bcd = @bitCast(src);
    const ext = @intFromBool(state.regs.sr.x);
    const res = switch (instr.op) {
        .abcd => cpu.Bcd.add(lhs, rhs, ext),
        .sbcd => cpu.Bcd.sub(lhs, rhs, ext),
    };

    // Save flags
    state.regs.sr.c = res[1];
    state.regs.sr.x = res[1];
    const byte = @as(u8, @bitCast(res[0]));
    if (byte != 0) state.regs.sr.z = false;

    // Store back to destination
    dst_ea.store(state, byte);

    // Add processing time and fetch next instruction
    switch (dst_ea) {
        // Abcd seems to have some sort of optimization in the microcode for this so we
        // automatically remove 2 of the cycles that were added in effective address calculation
        .mem => state.cycles -= 2,

        // Otherwise it seems to add 2 cycles
        else => state.cycles += 2,
    }
    state.ir = state.programFetch(enc.Size.word);
}
