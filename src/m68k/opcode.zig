const std = @import("std");
const expect = std.testing.expect;
const ops = @import("ops.zig");
const operand = @import("operand.zig");

pub const Opcode = enum {
    ori_to_ccr,
    ori_to_sr,
    ori,
    andi_to_ccr,
    andi_to_sr,
    andi,
    subi,
    addi,
    eori_to_ccr,
    eori_to_sr,
    eori,
    cmpi,
    btsti,
    bchgi,
    bclri,
    bseti,
    btst,
    bchg,
    bclr,
    bset,
    movep,
    movea,
    move,
    move_from_sr,
    move_to_ccr,
    move_to_sr,
    negx,
    clr,
    neg,
    not,
    ext,
    nbcd,
    swap,
    pea,
    illegal,
    tas,
    tst,
    trap,
    link,
    ulnk,
    move_usp,
    reset,
    nop,
    stop,
    rte,
    rts,
    trapv,
    rtr,
    jsr,
    jmp,
    movem,
    lea,
    chk,
    addq,
    subq,
    s_cc,
    db_cc,
    bra,
    bsr,
    b_cc,
    moveq,
    divu,
    divs,
    sbcd,
    @"or",
    sub,
    subx,
    suba,
    eor,
    cmpm,
    cmp,
    cmpa,
    mulu,
    muls,
    abcd,
    exg,
    @"and",
    add,
    addx,
    adda,
    as_d1,
    ls_d1,
    rox_d1,
    ro_d1,
    as_dn,
    ls_dn,
    rox_dn,
    ro_dn,

    pub fn decode(word: u16) Opcode {
        // Split into decoding lines first
        switch (ops.brange(u4, word, 12)) {
            0b0001...0b0011 => {
                return Opcode.decode_line_move(word);
            },
            inline else => |line| {
                return @field(Opcode, std.fmt.comptimePrint("decode_line_{b:0>4}", .{line}))(word);
            },
        }
    }

    fn decode_line_0000(word: u16) Opcode {
        if (ops.getbit(word, 8)) {
            if (operand.AddrMode.from_mode(ops.brange(u3, word, 3)) == operand.AddrMode.addr_reg) {
                return Opcode.movep;
            } else {
                // Do bit instructions
                return switch (ops.brange(u2, word, 6)) {
                    0b00 => Opcode.btst,
                    0b01 => Opcode.bchg,
                    0b10 => Opcode.bclr,
                    0b11 => Opcode.bset,
                };
            }
        } else {
            // Immidiate instructions
            switch (ops.brange(u3, word, 9)) {
                0b000, 0b001, 0b101 => |ty| {
                    // ORI instructions
                    const enum_val = @intFromEnum(switch (ty){
                        0b000 => Opcode.ori_to_ccr,
                        0b001 => Opcode.andi_to_ccr,
                        0b101 => Opcode.eori_to_ccr,
                        else => unreachable,
                    });
                    if (operand.AddrMode.from_mode_xn(
                        ops.brange(u3, word, 3),
                        ops.brange(u3, word, 0),
                    )) |addrmode| {
                        if (addrmode == .imm) {
                            return switch (ops.brange(u2, word, 6)) {
                                0b00 => @enumFromInt(enum_val),
                                0b01 => @enumFromInt(enum_val + 1),
                                else => Opcode.illegal,
                            };
                        } else {
                            return @enumFromInt(enum_val + 2);
                        }
                    } else {
                        return Opcode.illegal;
                    }
                },
                0b010 => return Opcode.subi,
                0b011 => return Opcode.addi,
                0b110 => return Opcode.cmpi,
                0b100 => {
                    return switch (ops.brange(u2, word, 6)) {
                        0b00 => Opcode.btsti,
                        0b01 => Opcode.bchgi,
                        0b10 => Opcode.bclri,
                        0b11 => Opcode.bseti,
                    };
                },
                else => return Opcode.illegal,
            }
        }
    }
    
    fn decode_line_move(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_0100(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_0101(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_0110(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_0111(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_1000(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_1001(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_1010(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_1011(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_1100(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_1101(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_1110(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
    
    fn decode_line_1111(word: u16) Opcode {
        _ = word;
        return Opcode.illegal;
    }
};

test "line_0000" {
    try expect(Opcode.decode(0x003C) == Opcode.ori_to_ccr);
    try expect(Opcode.decode(0x007C) == Opcode.ori_to_sr);
    try expect(Opcode.decode(0x0040) == Opcode.ori);
    try expect(Opcode.decode(0x023C) == Opcode.andi_to_ccr);
    try expect(Opcode.decode(0x027C) == Opcode.andi_to_sr);
    try expect(Opcode.decode(0x0240) == Opcode.andi);
    try expect(Opcode.decode(0x0440) == Opcode.subi);
    try expect(Opcode.decode(0x0640) == Opcode.addi);
    try expect(Opcode.decode(0x0A3C) == Opcode.eori_to_ccr);
    try expect(Opcode.decode(0x0A7C) == Opcode.eori_to_sr);
    try expect(Opcode.decode(0x0a40) == Opcode.eori);
    try expect(Opcode.decode(0x0800) == Opcode.btsti);
    try expect(Opcode.decode(0x0840) == Opcode.bchgi);
    try expect(Opcode.decode(0x08c0) == Opcode.bseti);
    try expect(Opcode.decode(0x0880) == Opcode.bclri);
    try expect(Opcode.decode(0x0300) == Opcode.btst);
    try expect(Opcode.decode(0x0340) == Opcode.bchg);
    try expect(Opcode.decode(0x03c0) == Opcode.bset);
    try expect(Opcode.decode(0x0380) == Opcode.bclr);
    try expect(Opcode.decode(0x0188) == Opcode.movep);
}
