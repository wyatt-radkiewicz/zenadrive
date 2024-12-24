const std = @import("std");
const expect = std.testing.expect;

ctx: *anyopaque,
vtable: *const VTable,

pub fn rd(self: *Self, comptime T: type, addr: u32) T {
    switch (T) {
        i8, u8 => return @bitCast(self.vtable.rd8(self.ctx, @truncate(addr))),
        i16, u16 => return @bitCast(self.vtable.rd16(self.ctx, @truncate(addr))),
        i32, u32 => return @bitCast(self.vtable.rd32(self.ctx, @truncate(addr))),
        else => @compileError("Can only read integer types of size 8, 16, or 32!"),
    }
}

pub fn wr(self: *Self, comptime T: type, addr: u32, data: T) void {
    switch (T) {
        i8, u8 => self.vtable.wr8(self.ctx, @truncate(addr), @bitCast(data)),
        i16, u16 => self.vtable.wr16(self.ctx, @truncate(addr), @bitCast(data)),
        i32, u32 => self.vtable.wr32(self.ctx, @truncate(addr), @bitCast(data)),
        else => @compileError("Can only read integer types of size 8, 16, or 32!"),
    }
}

pub fn init(bus: anytype) Self {
    const BusPtr = @TypeOf(bus);
    const Bus = @typeInfo(BusPtr).Pointer.child;

    // Generate the actual function calls and ensure the functions are actually type-correct
    const vtable = struct {
        pub fn rd8(ctx: *anyopaque, addr: u24) u8 {
            const busctx: BusPtr = @ptrCast(@alignCast(ctx));
            return Bus.rd(busctx, u8, addr);
        }
        pub fn wr8(ctx: *anyopaque, addr: u24, data: u8) void {
            const busctx: BusPtr = @ptrCast(@alignCast(ctx));
            return Bus.wr(busctx, u8, addr, data);
        }

        pub fn rd16(ctx: *anyopaque, addr: u24) u16 {
            const busctx: BusPtr = @ptrCast(@alignCast(ctx));
            return Bus.rd(busctx, u16, addr);
        }
        pub fn wr16(ctx: *anyopaque, addr: u24, data: u16) void {
            const busctx: BusPtr = @ptrCast(@alignCast(ctx));
            return Bus.wr(busctx, u16, addr, data);
        }

        pub fn rd32(ctx: *anyopaque, addr: u24) u32 {
            const busctx: BusPtr = @ptrCast(@alignCast(ctx));
            return Bus.rd(busctx, u32, addr);
        }
        pub fn wr32(ctx: *anyopaque, addr: u24, data: u32) void {
            const busctx: BusPtr = @ptrCast(@alignCast(ctx));
            return Bus.wr(busctx, u32, addr, data);
        }
    };

    return .{
        .ctx = @ptrCast(bus),
        .vtable = &.{
            .rd8 = vtable.rd8,
            .wr8 = vtable.wr8,
            .rd16 = vtable.rd16,
            .wr16 = vtable.wr16,
            .rd32 = vtable.rd32,
            .wr32 = vtable.wr32,
        },
    };
}

const Self = @This();
const VTable = struct {
    fn Reader(comptime width: u16) type {
        return *const fn (ctx: *anyopaque, addr: u24) std.meta.Int(.unsigned, width);
    }
    fn Writer(comptime width: u16) type {
        return *const fn (ctx: *anyopaque, addr: u24, data: std.meta.Int(.unsigned, width)) void;
    }

    rd8: Reader(8),
    wr8: Writer(8),
    rd16: Reader(16),
    wr16: Writer(16),
    rd32: Reader(32),
    wr32: Writer(32),
};

test "Bus read and write" {
    const TestBus = struct {
        d8: u8 = undefined,
        d16: u16 = undefined,
        d32: u32 = undefined,

        const TestBus = @This();
        fn rd(self: *TestBus, comptime T: type, addr: u24) T {
            _ = addr;
            return @field(self, std.fmt.comptimePrint("d{}", .{
                @typeInfo(T).Int.bits,
            }));
        }
        fn wr(self: *TestBus, comptime T: type, addr: u24, data: T) void {
            _ = addr;
            @field(self, std.fmt.comptimePrint("d{}", .{
                @typeInfo(T).Int.bits,
            })) = data;
        }
    };

    var bus_impl = TestBus{};
    var bus = Self.init(&bus_impl);

    bus.wr(u8, 0, 0x12);
    try expect(bus.rd(u8, 0) == 0x12);
    bus.wr(u16, 0, 0x1234);
    try expect(bus.rd(u16, 0) == 0x1234);
    bus.wr(u32, 0, 0x12345678);
    try expect(bus.rd(u32, 0) == 0x12345678);
}
