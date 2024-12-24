const meta = @import("std").meta;
const expect = @import("std").testing.expect;
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
        return @bitCast(0b0010_0111_0000_0000);
    }
};

// Store to registers
pub fn std(self: *Self, reg: u3, data: anytype) void {
    self.d[reg] = overwrite(self.d[reg], data);
}
pub fn sta(self: *Self, reg: u3, data: anytype) void {
    self.a[reg] = extend(u32, data);
}

// Load from registers
pub fn ldd(self: *Self, reg: u3, comptime T: type) T {
    return @as(T, self.d[reg]);
}
pub fn lda(self: *Self, reg: u3, comptime T: type) u32 {
    return extend(u32, @as(T, @truncate(self.a[reg])));
}

// Extend a type, setting everything to the extended value of dst
pub fn extend(Dst: type, src: anytype) Dst {
    // Get type of src but signed
    const dst_signed = meta.Int(.signed, @typeInfo(Dst).Int.bits);
    const src_signed = meta.Int(.signed, @typeInfo(@TypeOf(src)).Int.bits);
    const src_signed_converted = @as(src_signed, @bitCast(src));
    
    // Extend dst and return
    return @bitCast(@as(dst_signed, @intCast(src_signed_converted)));
}

// Overwrite a type, setting only the bit you need
pub fn overwrite(dst: anytype, src: anytype) @TypeOf(dst) {
    // Generate the mask
    const mask = comptime genMask: {
        var mask: @TypeOf(dst) = 0;
        for (0..@sizeOf(@TypeOf(src))) |_| {
            mask <<= 8;
            mask |= 0xFF;
        }
        break :genMask mask;
    };
    
    // Get type of src but unsigned
    const unsigned = meta.Int(.unsigned, @typeInfo(@TypeOf(src)).Int.bits);
    
    // Return overwrite
    return dst & ~mask | @as(unsigned, @bitCast(src));
}

test "overwrite" {
    const dst: u32 = 0x420;
    const src: u8 = 0xFF;
    try expect(overwrite(dst, src) == 0x4FF);
}

test "extend" {
    var src: u8 = 0xFF;
    try expect(extend(u32, src) == 0xFFFFFFFF);
    
    src = 0x7F;
    try expect(extend(u32, src) == 0x7F);
}
