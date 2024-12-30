const std = @import("std");

// Size field used in most instructions
pub const Size = enum(u2) {
    byte,
    word,
    long,

    pub fn match(bits: u2) bool {
        return switch (bits) {
            0b11 => false,
            else => true,
        };
    }
    
    pub fn fromBit(bit: u1) Size {
        return @enumFromInt(@as(u2, bit) + 1);
    }

    pub fn getType(comptime self: Size, comptime signedness: std.builtin.Signedness) type {
        return switch (self) {
            .byte => std.meta.Int(signedness, 8),
            .word => std.meta.Int(signedness, 16),
            .long => std.meta.Int(signedness, 32),
        };
    }

    pub fn extend(self: Size) Size {
        return switch (self) {
            .byte => .word,
            .word, .long => .long,
        };
    }
};

pub const AddrMode = enum {
    // Normal
    data_reg,
    addr_reg,
    addr,
    addr_postinc,
    addr_predec,
    addr_disp,
    addr_idx,

    // Special
    abs_word,
    abs_long,
    pc_disp,
    pc_idx,
    imm,

    pub fn fromEffAddr(ea: EffAddr) ?AddrMode {
        if (ea.m == 0b111) {
            const variant = @intFromEnum(AddrMode.abs_word) + ea.xn;
            return std.meta.intToEnum(AddrMode, variant) catch return null;
        } else {
            return @enumFromInt(ea.m);
        }
    }

    pub fn toEffAddr(self: AddrMode) EffAddr {
        const as_int = @intFromEnum(self);
        if (as_int > 7) {
            return .{ .m = 7, .xn = @truncate(as_int - 8) };
        } else {
            return .{ .m = @truncate(as_int), .xn = 0 };
        }
    }
};

// Used in effective address calculation
pub const BriefExtWord = packed struct {
    disp: i8,
    padding: u3 = 0,
    size: u1,
    reg: u3,
    mode: u1,
};

// Effective address encoding
pub const EffAddr = packed struct {
    xn: u3,
    m: u3,
    
    pub fn match(bits: u6) bool {
        const self: EffAddr = @bitCast(bits);
        return AddrMode.fromEffAddr(self) != null;
    }
};

// Shift direction used in shift instructions
pub const ShiftDir = enum(u1) {
    right,
    left,
};

// Operation direction used in math and logical instructions
pub const OpDir = enum(u1) {
    dn_ea_store_dn,
    ea_dn_store_ea,
};

// Bit operations
pub const BitOp = enum(u2) {
    btst,
    bchg,
    bclr,
    bset,
};

// Immediate operations
pub const ImmOp = enum(u3) {
    ori,
    andi,
    subi,
    addi,
    eori = 5,
    
    pub fn match(bits: u3) bool {
        _ = std.meta.intToEnum(ImmOp, bits) catch return false;
        return true;
    }
};

// Conditions
pub const Cond = enum(u4) {
    true,
    false,
    higher,
    lower_or_same,
    carry_clear,
    carry_set,
    not_equal,
    equal,
    overflow_clear,
    overflow_set,
    plus,
    minus,
    greater_or_equal,
    less_than,
    greater_than,
    less_or_equal,
};

pub fn BitPattern(comptime len: u16, bits: comptime_int) type {
    const Int = std.meta.Int(.unsigned, len);
    
    return packed struct {
        pattern: Int,
        
        pub fn match(pattern: Int) bool {
            return bits == pattern;
        }
    };
}
