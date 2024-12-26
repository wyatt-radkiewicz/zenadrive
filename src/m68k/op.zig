const std = @import("std");
const meta = std.meta;
const expect = std.testing.expect;

pub fn ShiftType(comptime Src: type) type {
    const src_info = @typeInfo(Src).Int;
    return std.meta.Int(.unsigned, std.math.log2_int(Src, src_info.bits));
}

pub fn brange(comptime Size: type, src_bits: anytype, start: u16) Size {
    const shift: ShiftType(@TypeOf(src_bits)) = @intCast(start);
    return @truncate(src_bits >> shift);
}

pub fn getbit(src_bits: anytype, bit: u16) bool {
    const Src = @TypeOf(src_bits);
    const shift: ShiftType(Src) = @intCast(bit);
    return (src_bits & @as(Src, 1) << shift) != 0;
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

test "brange" {
    try expect(brange(u4, @as(u16, 0b0110_0000_1111_0000), 12) == @as(u4, 0b0110));
}

test "getbit" {
    try expect(getbit(@as(u4 ,0b1000), 3));
    try expect(!getbit(@as(u4, 0b1000), 2));
}
