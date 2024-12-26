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

    pub fn from_binary_mode(mode: u1) AddrMode {
        return if (mode == 1) .addr_predec else .data_reg;
    }
    
    pub fn from_ea(ea: EffAddr) AddrMode {
        return from_mode_xn(ea.mode, ea.xn);
    }

    pub fn cycle_time(self: AddrMode, size: Size) u32 {
        return switch (self) {
            .data_reg, .addr_reg => 0,
            .addr, .addr_postinc, .imm => 4,
            .addr_predec => 6,
            .addr_disp, .pc_disp, .abs_short => 8,
            .addr_idx, .pc_idx => 10,
            .abs_long => 12,
        } + if (size == .long) 4 else 0;
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

pub const EffAddr = struct {
    mode: u3,
    xn: u3,
};

pub const MemDir = enum(u1) {
    reg_to_mem,
    mem_to_reg,

    pub fn decode(bit: u1, flip_encoding: bool) MemDir {
        return @enumFromInt(if (flip_encoding) ~bit else bit);
    }
};

pub const ExgMode = enum {
    data,
    addr,
    data_addr,
    
    pub fn decode(bits: u5) ?ExgMode {
        return switch (bits) {
            0b01000 => .data,
            0b01001 => .addr,
            0b10001 => .data_addr,
            else => null,
        };
    }
};

pub const ArgDir = enum(u1) { dn_ea, ea_dn };
pub const ShiftDir = enum(u1) { right, left };
pub const Rotation = enum(u1) { imm, reg };
pub const Cond = enum(u4) { t, f, hi, ls, cc, cs, ne, eq, vc, vs, pl, mi, ge, lt, gt, le };

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
