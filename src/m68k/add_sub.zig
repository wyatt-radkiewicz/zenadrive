const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");
const fmt = @import("cpu/fmt.zig");

const Op = enum(u1) { sub, add };
pub const Encoding = packed struct {
    ea: enc.EffAddr,
    size: enc.Size,
    dir: enc.OpDir,
    dn: u3,
    line: enc.BitPattern(2, 0b01),
    op: Op,
    line_msb: enc.BitPattern(1, 1),

    pub fn getLen(self: Encoding) usize {
        return enc.AddrMode.fromEffAddr(self.ea).?.getAdditionalSize(self.size) + 1;
    }

    pub fn match(comptime self: Encoding) bool {
        const mode = enc.AddrMode.fromEffAddr(self.ea).?;
        if (self.dir == .dn_ea_store_dn) {
            return self.size != .byte or mode != .addr_reg;
        } else {
            return switch (mode) {
                .data_reg, .addr_reg, .imm, .pc_idx, .pc_disp => false,
                else => true,
            };
        }
    }
};
pub const Fmt = struct {
    fmt: Encoding,
    data: *fmt.State,
    
    pub fn format(self: Fmt, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        var src: enc.EffAddr = undefined;
        var dst: enc.EffAddr = undefined;
        switch (self.fmt.dir) {
            .dn_ea_store_dn => {
                src = self.fmt.ea;
                dst = .{ .m = 0, .xn = self.fmt.dn };
            },
            .ea_dn_store_ea => {
                dst = self.fmt.ea;
                src = .{ .m = 0, .xn = self.fmt.dn };
            },
        }
        try writer.print("{s}.{c} {},{}", .{
            @tagName(self.fmt.op),
            self.fmt.size.toChar(),
            fmt.EffAddr.init(self.data, src, self.fmt.size),
            fmt.EffAddr.init(self.data, dst, null),
        });
    }
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
