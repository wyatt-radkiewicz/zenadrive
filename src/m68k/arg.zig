const std = @import("std");
const expect = std.testing.expect;

pub const AddrMode = enum(u4) {
    // Normal addressing modes
    data_reg,
    addr_reg,
    addr,
    addr_postinc,
    addr_predec,
    addr_disp,
    addr_idx,
    
    // Special addressing modes
    abs_short,
    abs_long,
    pc_disp,
    pc_idx,
    imm,
    
    pub fn from_mode(mode: u3) ?AddrMode {
        return if (mode < 7) @enumFromInt(mode) else null;
    }
    
    pub fn from_mode_xn(mode: u3, xn: u3) ?AddrMode {
        if (from_mode(mode)) |addrmode| {
            return addrmode;
        } else {
            return if (xn <= 4) @enumFromInt(7 + @as(u4, xn)) else null;
        }
    }
};

pub const Size = enum(u2) {
    byte,
    word,
    long,
    
    pub fn from_bit(bit: u1) Size {
        return if (bit == 1) .long else .word;
    }
    
    pub fn from_bits(bits: u2, comptime allow_zero: bool) ?Size {
        return switch (bits) {
            0b00 => if (allow_zero) Size.byte else null,
            0b01 => if (allow_zero) Size.word else Size.byte,
            0b11 => if (allow_zero) null else Size.word,
            0b10 => Size.long,
        };
    }
};

test "Decode AddrMode" {
    try expect(AddrMode.from_mode(0b000) == AddrMode.data_reg);
    try expect(AddrMode.from_mode(0b110) == AddrMode.addr_idx);
    try expect(AddrMode.from_mode(0b111) == null);
    try expect(AddrMode.from_mode_xn(0b010, 0b000) == AddrMode.addr);
    try expect(AddrMode.from_mode_xn(0b111, 0b010) == AddrMode.pc_disp);
    try expect(AddrMode.from_mode_xn(0b111, 0b111) == null);
}

test "Decode Size" {
    try expect(Size.from_bits(0b00, true) == Size.byte);
    try expect(Size.from_bits(0b01, true) == Size.word);
    try expect(Size.from_bits(0b10, true) == Size.long);
    try expect(Size.from_bits(0b11, true) == null);
    try expect(Size.from_bits(0b01, false) == Size.byte);
    try expect(Size.from_bits(0b11, false) == Size.word);
    try expect(Size.from_bits(0b10, false) == Size.long);
    try expect(Size.from_bits(0b00, false) == null);
    try expect(Size.from_bit(0) == Size.word);
    try expect(Size.from_bit(1) == Size.long);
}
