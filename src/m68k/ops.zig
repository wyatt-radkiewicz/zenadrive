const std = @import("std");
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

test "brange" {
    try expect(brange(u4, @as(u16, 0b0110_0000_1111_0000), 12) == @as(u4, 0b0110));
}

test "getbit" {
    try expect(getbit(@as(u4 ,0b1000), 3));
    try expect(!getbit(@as(u4, 0b1000), 2));
}
