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
    unlk,
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
    @"asm",
    lsm,
    roxm,
    rom,
    asd,
    lsd,
    roxd,
    rod,

    pub fn decode(word: u16) Opcode {
        // Split into decoding lines first
        return switch (ops.brange(u4, word, 12)) {
            0b0001...0b0011 => Opcode.decode_line_move(word),
            0b1010, 0b1111 => Opcode.illegal,
            0b0111 => Opcode.moveq,
            inline else => |line| @field(Opcode, std.fmt.comptimePrint("decode_line_{b:0>4}", .{line}))(word),
        };
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
                        if (addrmode != .imm) return @enumFromInt(enum_val + 2);
                        return switch (ops.brange(u2, word, 6)) {
                            0b00 => @enumFromInt(enum_val),
                            0b01 => @enumFromInt(enum_val + 1),
                            else => Opcode.illegal,
                        };
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
        return if (ops.brange(u3, word, 6) == 0b001) Opcode.movea else Opcode.move;
    }
    
    fn decode_line_0100(word: u16) Opcode {
        // Take care of oddly encoded instructions first
        switch (ops.brange(u3, word, 6)) {
            0b110 => return Opcode.chk,
            0b111 => return Opcode.lea,
            else => {},
        }
        
        // Take care of other instructions
        const invalid_size = ops.brange(u2, word, 6) == 0b11;
        switch (ops.brange(u4, word, 8)) {
            0b0000 => return if (invalid_size) Opcode.move_from_sr else Opcode.negx,
            0b0100 => return if (invalid_size) Opcode.move_to_ccr else Opcode.neg,
            0b0110 => return if (invalid_size) Opcode.move_to_sr else Opcode.not,
            0b0010 => return Opcode.clr,
            0b1000 => {
                if (ops.getbit(word, 7)) {
                    return if (ops.brange(u3, word, 3) == 0b000) Opcode.ext else Opcode.movem;
                } else {
                    if (!ops.getbit(word, 6)) return Opcode.nbcd;
                    return if (ops.brange(u3, word, 3) == 0b000) Opcode.swap else Opcode.pea;
                }
            },
            0b1010 => {
                if (word == 0b0100101011111100) return Opcode.illegal;
                return if (ops.brange(u2, word, 6) == 0b11) Opcode.tas else Opcode.tst;
            },
            else => {},
        }
        
        // Do movem and jsr/jmp
        if (ops.getbit(word, 11) and ops.brange(u3, word, 7) == 0b001) return Opcode.movem;
        if (ops.brange(u5, word, 7) == 0b11101) {
            return if (ops.getbit(word, 6)) Opcode.jmp else Opcode.jsr;
        }
        if (ops.brange(u6, word, 6) != 0b111001) return Opcode.illegal;
        
        switch (ops.brange(u2, word, 4)) {
            0b00 => return Opcode.trap,
            0b01 => return if (ops.getbit(word, 3)) Opcode.unlk else Opcode.link,
            0b10 => return Opcode.move_usp,
            0b11 => {},
        }
        switch (ops.brange(u4, word, 0)) {
            0b0000 => return Opcode.reset,
            0b0001 => return Opcode.nop,
            0b0010 => return Opcode.stop,
            0b0011 => return Opcode.rte,
            0b0101 => return Opcode.rts,
            0b0110 => return Opcode.trapv,
            0b0111 => return Opcode.rtr,
            else => {},
        }
        return Opcode.illegal;
    }
    
    fn decode_line_0101(word: u16) Opcode {
        if (ops.brange(u2, word, 6) == 0b11) {
            return if (ops.brange(u3, word, 3) == 0b001) Opcode.db_cc else Opcode.s_cc;
        } else {
            return if(ops.getbit(word, 8)) Opcode.subq else Opcode.addq;
        }
    }
    
    fn decode_line_0110(word: u16) Opcode {
        return switch (ops.brange(u4, word, 8)) {
            0b0000 => Opcode.bra,
            0b0001 => Opcode.bsr,
            else => Opcode.b_cc,
        };
    }
    
    fn decode_line_1000(word: u16) Opcode {
        if (ops.brange(u2, word, 6) == 0b11) {
            return if (ops.getbit(word, 8)) Opcode.divs else Opcode.divu;
        }
        
        if (!ops.getbit(word, 8)) return Opcode.@"or";
        return if (ops.brange(u2, word, 4) == 0b00) Opcode.sbcd else Opcode.@"or";
    }
    
    fn decode_line_1001(word: u16) Opcode {
        if (ops.brange(u2, word, 6) == 0b11) return Opcode.suba;
        if (!ops.getbit(word, 8)) return Opcode.sub;
        return switch (ops.brange(u3, word, 3)) {
            0b000, 0b001 => Opcode.subx,
            else => Opcode.sub,
        };
    }
    
    fn decode_line_1011(word: u16) Opcode {
        if (ops.brange(u2, word, 6) == 0b11) return Opcode.cmpa;
        if (!ops.getbit(word, 8)) return Opcode.cmp;
        return if (ops.brange(u3, word, 3) == 0b001) Opcode.cmpm else Opcode.eor;
    }
    
    fn decode_line_1100(word: u16) Opcode {
        if (ops.brange(u2, word, 6) == 0b11) {
            return if (ops.getbit(word, 8)) Opcode.muls else Opcode.mulu;
        }
        if (!ops.getbit(word, 8)) return Opcode.@"and";
        return switch (ops.brange(u3, word, 3)) {
            0b000, 0b001 => if (ops.brange(u2, word, 6) == 0b00) Opcode.abcd else Opcode.exg,
            else => Opcode.@"and",
        };
    }
    
    fn decode_line_1101(word: u16) Opcode {
        if (ops.brange(u2, word, 6) == 0b11) return Opcode.adda;
        return switch (ops.brange(u3, word, 3)) {
            0b000, 0b001 => Opcode.addx,
            else => Opcode.add,
        };
    }
    
    fn decode_line_1110(word: u16) Opcode {
        const invalid_size = ops.brange(u2, word, 6) == 0b11;
        const instr_type = ops.brange(u2, word, if (invalid_size) 9 else 3);
        return switch (instr_type) {
            0b00 => if (invalid_size) Opcode.@"asm" else Opcode.asd,
            0b01 => if (invalid_size) Opcode.lsm else Opcode.lsd,
            0b10 => if (invalid_size) Opcode.roxm else Opcode.roxd,
            0b11 => if (invalid_size) Opcode.rom else Opcode.rod,
        };
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

test "line_0000-line_0011" {
    try expect(Opcode.decode(0x3040) == Opcode.movea);
    try expect(Opcode.decode(0x2040) == Opcode.movea);
    try expect(Opcode.decode(0x1200) == Opcode.move);
    try expect(Opcode.decode(0x3200) == Opcode.move);
    try expect(Opcode.decode(0x2200) == Opcode.move);
}

test "line_0100" {
    try expect(Opcode.decode(0x40C0) == Opcode.move_from_sr);
    try expect(Opcode.decode(0x44C0) == Opcode.move_to_ccr);
    try expect(Opcode.decode(0x46C0) == Opcode.move_to_sr);
    try expect(Opcode.decode(0x4AFC) == Opcode.illegal);
    try expect(Opcode.decode(0x4AC0) == Opcode.tas);
    try expect(Opcode.decode(0x4A40) == Opcode.tst);
    try expect(Opcode.decode(0x4E40) == Opcode.trap);
    try expect(Opcode.decode(0x4E50) == Opcode.link);
    try expect(Opcode.decode(0x4E58) == Opcode.unlk);
    try expect(Opcode.decode(0x4E70) == Opcode.reset);
    try expect(Opcode.decode(0x4E71) == Opcode.nop);
    try expect(Opcode.decode(0x4E72) == Opcode.stop);
    try expect(Opcode.decode(0x4E73) == Opcode.rte);
    try expect(Opcode.decode(0x4E75) == Opcode.rts);
    try expect(Opcode.decode(0x4E76) == Opcode.trapv);
    try expect(Opcode.decode(0x4E77) == Opcode.rtr);
    try expect(Opcode.decode(0x4E90) == Opcode.jsr);
    try expect(Opcode.decode(0x4ED0) == Opcode.jmp);
    try expect(Opcode.decode(0x48A0) == Opcode.movem);
    try expect(Opcode.decode(0x48E0) == Opcode.movem);
    try expect(Opcode.decode(0x4C98) == Opcode.movem);
    try expect(Opcode.decode(0x4CD8) == Opcode.movem);
    try expect(Opcode.decode(0x41D0) == Opcode.lea);
    try expect(Opcode.decode(0x4181) == Opcode.chk);
}

test "line_0101" {
    try expect(Opcode.decode(0x5A40) == Opcode.addq);
    try expect(Opcode.decode(0x5B40) == Opcode.subq);
    try expect(Opcode.decode(0x57C0) == Opcode.s_cc);
    try expect(Opcode.decode(0x56C8) == Opcode.db_cc);
}

test "line_0110" {
    try expect(Opcode.decode(0x6000) == Opcode.bra);
    try expect(Opcode.decode(0x6100) == Opcode.bsr);
    try expect(Opcode.decode(0x6600) == Opcode.b_cc);
}

test "line_0111" {
    try expect(Opcode.decode(0x7003) == Opcode.moveq);
}

test "line_1000" {
    try expect(Opcode.decode(0x80FC) == Opcode.divu);
    try expect(Opcode.decode(0x81FC) == Opcode.divs);
    try expect(Opcode.decode(0x8300) == Opcode.sbcd);
    try expect(Opcode.decode(0x8110) == Opcode.@"or");
}

test "line_1001" {
    try expect(Opcode.decode(0x9050) == Opcode.sub);
    try expect(Opcode.decode(0x9140) == Opcode.subx);
    try expect(Opcode.decode(0x91C8) == Opcode.suba);
}

test "line_1011" {
    try expect(Opcode.decode(0xB141) == Opcode.eor);
    try expect(Opcode.decode(0xB348) == Opcode.cmpm);
    try expect(Opcode.decode(0xB048) == Opcode.cmp);
    try expect(Opcode.decode(0xB0C0) == Opcode.cmpa);
}

test "line_1100" {
    try expect(Opcode.decode(0xC0FC) == Opcode.mulu);
    try expect(Opcode.decode(0xC1FC) == Opcode.muls);
    try expect(Opcode.decode(0xC100) == Opcode.abcd);
    try expect(Opcode.decode(0xC188) == Opcode.exg);
    try expect(Opcode.decode(0xC040) == Opcode.@"and");
}

test "line_1101" {
    try expect(Opcode.decode(0xD050) == Opcode.add);
    try expect(Opcode.decode(0xD140) == Opcode.addx);
    try expect(Opcode.decode(0xD1C8) == Opcode.adda);
}

test "line_1110" {
    try expect(Opcode.decode(0xE0D0) == Opcode.@"asm");
    try expect(Opcode.decode(0xE3D0) == Opcode.lsm);
    try expect(Opcode.decode(0xE5D0) == Opcode.roxm);
    try expect(Opcode.decode(0xE7D0) == Opcode.rom);
    try expect(Opcode.decode(0xE440) == Opcode.asd);
    try expect(Opcode.decode(0xE548) == Opcode.lsd);
    try expect(Opcode.decode(0xE550) == Opcode.roxd);
    try expect(Opcode.decode(0xE558) == Opcode.rod);
}