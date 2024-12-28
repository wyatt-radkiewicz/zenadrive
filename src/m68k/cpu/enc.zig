const std = @import("std");
const ea = @import("ea.zig");

pub const Size = enum(u2) {
    byte,
    word,
    long,
    
    pub fn match(bits: u2) ?Size {
        return switch (bits) {
            0b00 => .byte,
            0b01 => .word,
            0b10 => .long,
            0b11 => null,
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
    
    pub fn fromModeBits(m: u3, xn: u3) ?AddrMode{
        if (m == 0b111) {
            return std.meta.intToEnum(AddrMode.abs_word + xn) catch return null;
        } else {
            return @enumFromInt(m);
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

// Type used in MatchEffAddr
pub fn MatchEffAddr(comptime invalid_modes: []const AddrMode) type {
    return packed struct {
        m: u3,
        xn: u3,
        
        const Self = @This();
        
        pub fn match(bits: u6) ?Self {
            const self: Self = @bitCast(bits);
            const addrmode = AddrMode.fromModeBits(self.m, self.xn) orelse return null;
            for (invalid_modes) |mode| {
                if (addrmode == mode) return null;
            }
            return self;
        }
    };
}

/// Exactly matches a bit pattern in an instruction encoding
pub fn MatchBits(comptime length: u16, comptime pattern: std.meta.Int(.unsigned, length)) type {
    const Pattern = @TypeOf(pattern);
    
    return packed struct {
        encoded_bits: Pattern,
        
        pub fn match(bits: Pattern) ?@This() {
            return if (bits != pattern) null else .{
                .encoded_bits = bits,
            };
        }
    };
}
