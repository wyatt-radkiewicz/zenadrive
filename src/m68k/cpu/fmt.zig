const std = @import("std");
const enc = @import("enc.zig");
const cpu = @import("cpu.zig");

// Used to get values for immediate data
pub const State = struct {
    bus: *const cpu.Bus,
    addr: u32,

    pub fn next(self: *State, comptime size: enc.Size) size.getType(.unsigned) {
        const addr: u24 = @truncate(self.addr);
        self.*.addr +%= switch (size) {
            .byte, .word => 2,
            .long => 4,
        };
        return switch (size) {
            .byte => @as(u8, @truncate(self.bus.rd16(addr))),
            .word => self.bus.rd16(addr),
            .long => self.bus.rd32(addr),
        };
    }

    pub fn nextExtend(self: *State, size: enc.Size) i32 {
        switch (size) {
            inline else => |sz| {
                const S = sz.getType(.signed);
                const val: i32 = @as(S, self.next(self, sz));
                return val;
            },
        }
    }
};

// Helper struct used to format addresses
pub const Addr = struct {
    reg: u3,

    pub fn from(reg: u3) Addr {
        return .{ .reg = reg };
    }

    pub fn format(
        self: Addr,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        if (self.reg == 7) {
            try writer.print("sp", .{});
        } else {
            try writer.print("a{}", .{self.reg});
        }
    }
};

pub const EffAddr = struct {
    ea: enc.EffAddr,
    size: ?enc.Size,
    state: *State,

    pub fn init(state: *State, ea: enc.EffAddr, size: ?enc.Size) EffAddr {
        return .{ .ea = ea, .size = size, .state = state };
    }

    pub fn format(
        self: EffAddr,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        const mode = enc.AddrMode.fromEffAddr(self.ea) orelse {
            try writer.print("<invalid>", .{});
            return;
        };

        switch (mode) {
            // Normal
            .data_reg => try writer.print("d{}", .{self.ea.xn}),
            .addr_reg => try writer.print("{}", .{Addr.from(self.ea.xn)}),
            .addr => try writer.print("({})", .{Addr.from(self.ea.xn)}),
            .addr_postinc => try writer.print("({})+", .{Addr.from(self.ea.xn)}),
            .addr_predec => try writer.print("-({})", .{Addr.from(self.ea.xn)}),
            .addr_disp => {
                const disp: i16 = @bitCast(self.state.next(enc.Size.word));
                try writer.print("{}({})", .{ disp, Addr.from(self.ea.xn) });
            },
            .addr_idx => {
                const word: enc.BriefExtWord = @bitCast(self.state.next(enc.Size.word));
                if (word.mode == 1) {
                    try writer.print("{}(a{}, {})", .{
                        word.disp,
                        Addr.from(word.reg),
                        Addr.from(self.ea.xn),
                    });
                } else {
                    try writer.print("{}(d{}, {})", .{ word.disp, word.reg, Addr.from(self.ea.xn) });
                }
            },

            // Special
            .abs_word => try writer.print("${X:0>4}", .{self.state.next(enc.Size.word)}),
            .abs_long => try writer.print("${X:0>8}", .{self.state.next(enc.Size.long)}),
            .pc_disp => try writer.print("{}(pc)", .{@as(i16, @bitCast(self.state.next(enc.Size.word)))}),
            .pc_idx => {
                const word: enc.BriefExtWord = @bitCast(self.state.next(enc.Size.word));
                if (word.mode == 1) {
                    try writer.print("{}({}, pc)", .{ word.disp, Addr.from(word.reg) });
                } else {
                    try writer.print("{}(d{}, pc)", .{ word.disp, word.reg });
                }
            },
            .imm => {
                if (self.size) |real_size| {
                    switch (real_size) {
                        .byte => {
                            const imm: i8 = @bitCast(self.state.next(enc.Size.byte));
                            try writer.print("#{}", .{imm});
                        },
                        .word => {
                            const imm: i16 = @bitCast(self.state.next(enc.Size.word));
                            try writer.print("#{}", .{imm});
                        },
                        .long => {
                            const imm: i32 = @bitCast(self.state.next(enc.Size.long));
                            try writer.print("#{}", .{imm});
                        },
                    }
                } else {
                    try writer.print("<invalid>", .{});
                }
            },
        }
    }
};
