const meta = @import("std").meta;
const expect = @import("std").testing.expect;
const op = @import("op.zig");
const Self = @This();

d: [8]u32,
a: [8]u32,
pc: u32,
sr: Status,

pub fn reset() Self {
    return .{
        .d = [_]u32{0} ** 8,
        .a = [_]u32{0} ** 8,
        .pc = 0,
        .sr = Status.reset(),
    };
}

pub const Status = packed struct {
    c: bool,
    o: bool,
    z: bool,
    n: bool,
    e: bool,
    reserved_ccr: u3 = 0,
    ipl: u3,
    reserved_ssr: u2 = 0,
    s: bool,
    reserved_trace: u1 = 0,
    t: bool,
    
    pub fn reset() Status {
        return @bitCast(@as(u16, 0b0010_0111_0000_0000));
    }
};

// Store to registers
pub fn std(self: *Self, reg: u3, data: anytype) void {
    self.d[reg] = op.overwrite(self.d[reg], data);
}
pub fn sta(self: *Self, reg: u3, data: anytype) void {
    self.a[reg] = op.extend(u32, data);
}

// Load from registers
pub fn ldd(self: *Self, reg: u3, comptime T: type) T {
    return @as(T, @truncate(self.d[reg]));
}
pub fn lda(self: *Self, reg: u3, comptime T: type) u32 {
    return op.extend(u32, @as(T, @truncate(self.a[reg])));
}

test "Regs store/load" {
    var regs = Self.reset();
    
    regs.std(0, @as(u32, 0xFFFFFFFF));
    try expect(regs.ldd(0, u32) == 0xFFFFFFFF);
    regs.std(0, @as(u16, 0));
    try expect(regs.ldd(0, u32) == 0xFFFF0000);
    
    regs.sta(0, @as(u16, 0xFFFF));
    try expect(regs.a[0] == 0xFFFFFFFF);
    try expect(regs.lda(0, u16) == 0xFFFFFFFF);
    regs.sta(0, @as(u16, 0x7FFF));
    try expect(regs.a[0] == 0x00007FFF);
    try expect(regs.lda(0, u16) == 0x00007FFF);
}
