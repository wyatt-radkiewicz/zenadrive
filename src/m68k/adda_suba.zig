const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");
const fmt = @import("cpu/fmt.zig");

const Op = enum(u1) { suba, adda };
pub const Encoding = packed struct {
    src: enc.EffAddr,
    pattern: enc.BitPattern(2, 0b11),
    size: u1,
    dst: u3,
    line: enc.BitPattern(2, 0b01),
    op: Op,
    line_msb: enc.BitPattern(1, 1),

    pub fn getLen(self: Encoding) usize {
        const size = enc.Size.fromBit(self.size);
        return enc.AddrMode.fromEffAddr(self.src).?.getAdditionalSize(size) + 1;
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
        const size = enc.Size.fromBit(self.fmt.size);
        try writer.print("{s}.{c} {},{}", .{
            @tagName(self.fmt.op),
            size.toChar(),
            fmt.EffAddr.init(self.data, self.fmt.src, size),
            fmt.Addr.from(self.fmt.dst),
        });
    }
};
pub const Variant = packed struct {
    op: Op,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    // 0:	d0c0           	adda.w d0,a0      ; 8 cycles
    // 2:	d1d0           	adda.l (a0),a0    ; 14 cycles
    pub const code = [_]u16{ 0xD0C0, 0xD1D0 };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 22);
    }
};

pub fn run(state: *cpu.State, comptime args: Variant) void {
    const instr: Encoding = @bitCast(state.ir);

    // Compute source effective address and sign extend
    const src = get_src: {
        switch (enc.Size.fromBit(instr.size)) {
            inline else => |sz| {
                const ea = cpu.EffAddr(sz).calc(state, instr.src);
                state.cycles += switch (sz) {
                    .byte => unreachable,
                    .word => 4,
                    .long => switch (ea) {
                        .mem => 2,
                        else => 4,
                    },
                };
                break :get_src cpu.extendFull(sz, ea.load(state));
            },
        }
    };

    // Set flags and store result
    const addr = state.loadReg(.addr, enc.Size.long, instr.dst);
    const res = switch (args.op) {
        .adda => src +% addr,
        .suba => src -% addr,
    };
    state.storeReg(.addr, enc.Size.long, instr.dst, res);

    // Fetch next instruction
    state.ir = state.programFetch(enc.Size.word);
}
