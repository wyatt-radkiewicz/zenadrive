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

    pub fn fromModeBits(m: u3, xn: u3) ?AddrMode {
        if (m == 0b111) {
            const variant = @intFromEnum(AddrMode.abs_word) + xn;
            return std.meta.intToEnum(AddrMode, variant) catch return null;
        } else {
            return @enumFromInt(m);
        }
    }
    
    pub fn toModeBits(self: AddrMode) struct{ u3, ?u3 } {
        const as_int = @intFromEnum(self);
        if (as_int > 7) {
            return .{ 7, @truncate(as_int - 8) };
        } else {
            return .{ @truncate(as_int), null };
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

// Shift direction used in shift instructions
pub const ShiftDir = enum (u1) {
    right,
    left,
    
    pub fn match(bits: u1) bool {
        _ = bits;
        return true;
    }
};

// Bit operations
pub const BitOp = enum(u2) {
    btst,
    bchg,
    bclr,
    bset,
    
    pub fn match(bits: u2) bool {
        _ = bits;
        return true;
    }
};

// Conditions
pub const Cond = enum(u4) {
    @"true",
    @"false",
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

// Matches condition codes
pub fn MatchCond(comptime invalid_conds: []const Cond) type {
    return packed struct {
        val: Cond,

        pub fn match(bits: u4) bool {
            const cond: Cond = @enumFromInt(bits);
            for (invalid_conds) |currcond| {
                if (cond == currcond) return false;
            }
            return true;
        }
    };
}

// Type used in MatchEffAddr
pub fn MatchEffAddr(comptime invalid_modes: []const AddrMode) type {
    return packed struct {
        xn: u3,
        m: u3,

        const Self = @This();

        pub fn match(bits: u6) bool {
            const self: Self = @bitCast(bits);
            const addrmode = AddrMode.fromModeBits(self.m, self.xn) orelse return false;
            for (invalid_modes) |mode| {
                if (addrmode == mode) return false;
            }
            return true;
        }
    };
}

/// Exactly matches a bit pattern in an instruction encoding
pub fn MatchBits(comptime length: u16, comptime pattern: std.meta.Int(.unsigned, length)) type {
    const Pattern = @TypeOf(pattern);

    return packed struct {
        encoded_bits: Pattern,

        pub fn match(bits: Pattern) bool {
            return bits == pattern;
        }
    };
}

// Bit type of type
pub fn ToInt(comptime T: type) type {
    return std.meta.Int(.unsigned, @bitSizeOf(T));
}

// Match children of a structure
pub fn matchChildren(comptime T: type, bits: ToInt(T)) bool {
    const info = @typeInfo(T).Struct;
    var bits_left = bits;
    inline for (info.fields) |field| {
        const field_bits: ToInt(field.type) = @truncate(bits_left);
        switch (@typeInfo(field.type)) {
            .Int, .Bool => {},
            .Struct, .Union, .Enum => if (!field.type.match(field_bits)) return false,
            else => {
                @compileLog("encoding type: ");
                @compileLog(field.type);
                @compileError("unrecognized encoding type");
            },
        }
        if (@bitSizeOf(field.type) == @bitSizeOf(T)) {
            return true;
        } else {
            bits_left >>= @bitSizeOf(field.type);
        }
    }
    return true;
}
