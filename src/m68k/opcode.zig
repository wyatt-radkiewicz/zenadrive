const std = @import("std");
const expect = std.testing.expect;
const op = @import("op.zig");
const arg = @import("arg.zig");

const word_to_opcode = compute_word_to_opcode: {
    const len = std.math.maxInt(u16) + 1;
    var table: [len]Opcode = undefined;
    for (0..len) |idx| {
        const opcode = Opcode.decode(idx);
        table[idx] = if (opcode.validate_word(idx)) opcode else Opcode.illegal;
    }
    break :compute_word_to_opcode table;
};

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
        return switch (op.brange(u4, word, 12)) {
            0b0001...0b0011 => Opcode.decode_line_move(word),
            0b1010, 0b1111 => Opcode.illegal,
            0b0111 => Opcode.moveq,
            inline else => |line| @field(
                Opcode,
                std.fmt.comptimePrint("decode_line_{b:0>4}", .{line}),
            )(word),
        };
    }

    fn decode_line_0000(word: u16) Opcode {
        if (op.getbit(word, 8)) {
            if (arg.AddrMode.from_mode(op.brange(u3, word, 3)) == arg.AddrMode.addr_reg) {
                return Opcode.movep;
            } else {
                // Do bit instructions
                return switch (op.brange(u2, word, 6)) {
                    0b00 => Opcode.btst,
                    0b01 => Opcode.bchg,
                    0b10 => Opcode.bclr,
                    0b11 => Opcode.bset,
                };
            }
        } else {
            // Immidiate instructions
            switch (op.brange(u3, word, 9)) {
                0b000, 0b001, 0b101 => |ty| {
                    // ORI instructions
                    const enum_val = @intFromEnum(switch (ty) {
                        0b000 => Opcode.ori_to_ccr,
                        0b001 => Opcode.andi_to_ccr,
                        0b101 => Opcode.eori_to_ccr,
                        else => unreachable,
                    });
                    if (arg.AddrMode.from_mode_xn(
                        op.brange(u3, word, 3),
                        op.brange(u3, word, 0),
                    )) |addrmode| {
                        if (addrmode != .imm) return @enumFromInt(enum_val + 2);
                        return switch (op.brange(u2, word, 6)) {
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
                    return switch (op.brange(u2, word, 6)) {
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
        return if (op.brange(u3, word, 6) == 0b001) Opcode.movea else Opcode.move;
    }

    fn decode_line_0100(word: u16) Opcode {
        // Take care of oddly encoded instructions first
        switch (op.brange(u3, word, 6)) {
            0b110 => return Opcode.chk,
            0b111 => return Opcode.lea,
            else => {},
        }

        // Take care of other instructions
        const invalid_size = op.brange(u2, word, 6) == 0b11;
        switch (op.brange(u4, word, 8)) {
            0b0000 => return if (invalid_size) Opcode.move_from_sr else Opcode.negx,
            0b0100 => return if (invalid_size) Opcode.move_to_ccr else Opcode.neg,
            0b0110 => return if (invalid_size) Opcode.move_to_sr else Opcode.not,
            0b0010 => return Opcode.clr,
            0b1000 => {
                if (op.getbit(word, 7)) {
                    return if (op.brange(u3, word, 3) == 0b000) Opcode.ext else Opcode.movem;
                } else {
                    if (!op.getbit(word, 6)) return Opcode.nbcd;
                    return if (op.brange(u3, word, 3) == 0b000) Opcode.swap else Opcode.pea;
                }
            },
            0b1010 => {
                if (word == 0b0100101011111100) return Opcode.illegal;
                return if (op.brange(u2, word, 6) == 0b11) Opcode.tas else Opcode.tst;
            },
            else => {},
        }

        // Do movem and jsr/jmp
        if (op.getbit(word, 11) and op.brange(u3, word, 7) == 0b001) return Opcode.movem;
        if (op.brange(u5, word, 7) == 0b11101) {
            return if (op.getbit(word, 6)) Opcode.jmp else Opcode.jsr;
        }
        if (op.brange(u6, word, 6) != 0b111001) return Opcode.illegal;

        switch (op.brange(u2, word, 4)) {
            0b00 => return Opcode.trap,
            0b01 => return if (op.getbit(word, 3)) Opcode.unlk else Opcode.link,
            0b10 => return Opcode.move_usp,
            0b11 => {},
        }
        switch (op.brange(u4, word, 0)) {
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
        if (op.brange(u2, word, 6) == 0b11) {
            return if (op.brange(u3, word, 3) == 0b001) Opcode.db_cc else Opcode.s_cc;
        } else {
            return if (op.getbit(word, 8)) Opcode.subq else Opcode.addq;
        }
    }

    fn decode_line_0110(word: u16) Opcode {
        return switch (op.brange(u4, word, 8)) {
            0b0000 => Opcode.bra,
            0b0001 => Opcode.bsr,
            else => Opcode.b_cc,
        };
    }

    fn decode_line_1000(word: u16) Opcode {
        if (op.brange(u2, word, 6) == 0b11) {
            return if (op.getbit(word, 8)) Opcode.divs else Opcode.divu;
        }

        if (!op.getbit(word, 8)) return Opcode.@"or";
        return if (op.brange(u2, word, 4) == 0b00) Opcode.sbcd else Opcode.@"or";
    }

    fn decode_line_1001(word: u16) Opcode {
        if (op.brange(u2, word, 6) == 0b11) return Opcode.suba;
        if (!op.getbit(word, 8)) return Opcode.sub;
        return switch (op.brange(u3, word, 3)) {
            0b000, 0b001 => Opcode.subx,
            else => Opcode.sub,
        };
    }

    fn decode_line_1011(word: u16) Opcode {
        if (op.brange(u2, word, 6) == 0b11) return Opcode.cmpa;
        if (!op.getbit(word, 8)) return Opcode.cmp;
        return if (op.brange(u3, word, 3) == 0b001) Opcode.cmpm else Opcode.eor;
    }

    fn decode_line_1100(word: u16) Opcode {
        if (op.brange(u2, word, 6) == 0b11) {
            return if (op.getbit(word, 8)) Opcode.muls else Opcode.mulu;
        }
        if (!op.getbit(word, 8)) return Opcode.@"and";
        return switch (op.brange(u3, word, 3)) {
            0b000, 0b001 => if (op.brange(u2, word, 6) == 0b00) Opcode.abcd else Opcode.exg,
            else => Opcode.@"and",
        };
    }

    fn decode_line_1101(word: u16) Opcode {
        if (op.brange(u2, word, 6) == 0b11) return Opcode.adda;
        return switch (op.brange(u3, word, 3)) {
            0b000, 0b001 => Opcode.addx,
            else => Opcode.add,
        };
    }

    fn decode_line_1110(word: u16) Opcode {
        const invalid_size = op.brange(u2, word, 6) == 0b11;
        const instr_type = op.brange(u2, word, if (invalid_size) 9 else 3);
        return switch (instr_type) {
            0b00 => if (invalid_size) Opcode.@"asm" else Opcode.asd,
            0b01 => if (invalid_size) Opcode.lsm else Opcode.lsd,
            0b10 => if (invalid_size) Opcode.roxm else Opcode.roxd,
            0b11 => if (invalid_size) Opcode.rom else Opcode.rod,
        };
    }

    fn has_mode(word: u16, pos: u16, modes: []const arg.AddrMode) bool {
        const addrmode = arg.AddrMode.from_mode(op.brange(u3, word, pos));
        return for (modes) |mode| {
            if (addrmode == mode) break true;
        } else false;
    }

    pub fn validate_word(self: Opcode, word: u16) bool {
        switch (self) {
            .ori,
            .andi,
            .eori,
            .subi,
            .addi,
            .cmpi,
            .btsti,
            .bchgi,
            .bclri,
            .bseti,
            .btst,
            .bchg,
            .bclr,
            .bset,
            .move_from_sr,
            .negx,
            .clr,
            .neg,
            .not,
            .nbcd,
            .tas,
            .s_cc,
            .eor,
            => return !has_mode(word, 3, &[_]arg.AddrMode{
                .addr_reg,
                .imm,
                .pc_idx,
                .pc_disp,
            }),
            .move => return !has_mode(word, 6, &[_]arg.AddrMode{
                .addr_reg,
                .imm,
                .pc_idx,
                .pc_disp,
            }),
            .move_to_ccr, .move_to_sr => return !has_mode(word, 6, &[_]arg.AddrMode{.addr_reg}),
            .pea, .jsr, .jmp, .lea => return !has_mode(word, 3, &[_]arg.AddrMode{
                .data_reg,
                .addr_reg,
                .addr_postinc,
                .addr_predec,
                .imm,
            }),
            .tst => return !has_mode(word, 3, &[_]arg.AddrMode{ .addr_reg, .imm }),
            .movem => {
                if (op.getbit(word, 10)) {
                    return !has_mode(word, 3, &[_]arg.AddrMode{
                        .data_reg,
                        .addr_reg,
                        .addr_predec,
                        .imm,
                    });
                } else {
                    return !has_mode(word, 3, &[_]arg.AddrMode{
                        .data_reg,
                        .addr_reg,
                        .addr_postinc,
                        .imm,
                        .pc_disp,
                        .pc_idx,
                    });
                }
            },
            .chk,
            .divu,
            .divs,
            .mulu,
            .muls,
            => return !has_mode(word, 3, &[_]arg.AddrMode{.addr_reg}),
            .addq, .subq => {
                if (op.brange(u3, word, 3) == 0b001 and op.brange(u2, word, 6) == 0b00) return false;
                return !has_mode(word, 3, &[_]arg.AddrMode{ .imm, .pc_disp, .pc_idx });
            },
            .@"or", .sub, .@"and", .add => {
                const modes = get_modes: {
                    if (op.getbit(word, 8)) {
                        break :get_modes &[_]arg.AddrMode{
                            .addr_reg,
                            .data_reg,
                            .imm,
                            .pc_disp,
                            .pc_idx,
                        };
                    } else {
                        if (op.brange(u3, word, 3) == 0b00) {
                            break :get_modes &[_]arg.AddrMode{.addr_reg};
                        } else {
                            break :get_modes &[0]arg.AddrMode{};
                        }
                    }
                };
                return !has_mode(word, 3, modes);
            },
            .cmp => return op.brange(u2, word, 6) != 0b00 or op.brange(u3, word, 3) != 0b001,
            .exg => return switch (op.brange(u5, word, 3)) {
                0b01000, 0b01001, 0b10001 => true,
                else => false,
            },
            .@"asm", .lsm, .roxm, .rom => return !has_mode(word, 3, &[_]arg.AddrMode{ .data_reg, .addr_reg, .imm, .pc_idx, .pc_disp }),
            else => return true,
        }
    }
};

test "word to opcode" {
    try expect(word_to_opcode[0x9041] == Opcode.sub);
}

test "mode validation" {
    try expect(Opcode.ori_to_ccr.validate_word(0x003C));
    try expect(Opcode.ori.validate_word(0x0040));
    try expect(Opcode.andi_to_ccr.validate_word(0x023C));
    try expect(Opcode.andi.validate_word(0x0240));
    try expect(Opcode.subi.validate_word(0x0440));
    try expect(Opcode.addi.validate_word(0x0640));
    try expect(Opcode.eori_to_ccr.validate_word(0x0A3C));
    try expect(Opcode.eori.validate_word(0x0A40));
    try expect(Opcode.btsti.validate_word(0x0800));
    try expect(Opcode.bchgi.validate_word(0x0840));
    try expect(Opcode.bseti.validate_word(0x08C0));
    try expect(Opcode.bclri.validate_word(0x0880));
    try expect(Opcode.btst.validate_word(0x0300));
    try expect(Opcode.bchg.validate_word(0x0340));
    try expect(Opcode.bset.validate_word(0x03C0));
    try expect(Opcode.bclr.validate_word(0x0380));
    try expect(Opcode.movep.validate_word(0x0188));
    try expect(Opcode.movea.validate_word(0x3040));
    try expect(Opcode.movea.validate_word(0x2040));
    try expect(Opcode.move.validate_word(0x1200));
    try expect(Opcode.move.validate_word(0x3200));
    try expect(Opcode.move.validate_word(0x2200));
    try expect(Opcode.move.validate_word(0x40C0));
    try expect(Opcode.move.validate_word(0x46C0));
    try expect(Opcode.illegal.validate_word(0x4AFC));
    try expect(Opcode.tas.validate_word(0x4AC0));
    try expect(Opcode.tst.validate_word(0x4A40));
    try expect(Opcode.trap.validate_word(0x4E40));
    try expect(Opcode.link.validate_word(0x4E50));
    try expect(Opcode.unlk.validate_word(0x4E58));
    try expect(Opcode.movea.validate_word(0x3E48));
    try expect(Opcode.movea.validate_word(0x304F));
    try expect(Opcode.reset.validate_word(0x4E70));
    try expect(Opcode.nop.validate_word(0x4E71));
    try expect(Opcode.stop.validate_word(0x4E72));
    try expect(Opcode.rte.validate_word(0x4E73));
    try expect(Opcode.rts.validate_word(0x4E75));
    try expect(Opcode.trapv.validate_word(0x4E76));
    try expect(Opcode.rtr.validate_word(0x4E77));
    try expect(Opcode.jsr.validate_word(0x4E90));
    try expect(Opcode.jmp.validate_word(0x4ED0));
    try expect(Opcode.movem.validate_word(0x48A0));
    try expect(Opcode.movem.validate_word(0x48E0));
    try expect(Opcode.movem.validate_word(0x4C98));
    try expect(Opcode.movem.validate_word(0x4CD8));
    try expect(Opcode.lea.validate_word(0x41D0));
    try expect(Opcode.chk.validate_word(0x4181));
    try expect(Opcode.sbcd.validate_word(0x8101));
    try expect(Opcode.sub.validate_word(0x9001));
    try expect(Opcode.sub.validate_word(0x9111));
    try expect(Opcode.sub.validate_word(0x9041));
    try expect(Opcode.suba.validate_word(0x90C1));
    try expect(Opcode.sub.validate_word(0x9151));
    try expect(Opcode.sub.validate_word(0x9081));
    try expect(Opcode.suba.validate_word(0x91C1));
    try expect(Opcode.sub.validate_word(0x9191));
    try expect(Opcode.sub.validate_word(0x9048));
    try expect(Opcode.addq.validate_word(0x5A40));
    try expect(Opcode.subq.validate_word(0x5B40));
    try expect(Opcode.s_cc.validate_word(0x57C0));
    try expect(Opcode.db_cc.validate_word(0x56C8));
    try expect(Opcode.bra.validate_word(0x6000));
    try expect(Opcode.bsr.validate_word(0x6100));
    try expect(Opcode.b_cc.validate_word(0x6600));
    try expect(Opcode.moveq.validate_word(0x7003));
    try expect(Opcode.divu.validate_word(0x80FC));
    try expect(Opcode.divs.validate_word(0x81FC));
    try expect(Opcode.sbcd.validate_word(0x8300));
    try expect(Opcode.@"or".validate_word(0x8110));
    try expect(Opcode.sub.validate_word(0x9050));
    try expect(Opcode.subx.validate_word(0x9140));
    try expect(Opcode.suba.validate_word(0x91C8));
    try expect(Opcode.eor.validate_word(0xB141));
    try expect(Opcode.cmpm.validate_word(0xB348));
    try expect(Opcode.cmp.validate_word(0xB048));
    try expect(Opcode.cmpa.validate_word(0xB0C0));
    try expect(Opcode.mulu.validate_word(0xC0FC));
    try expect(Opcode.muls.validate_word(0xC1FC));
    try expect(Opcode.abcd.validate_word(0xC100));
    try expect(Opcode.exg.validate_word(0xC188));
    try expect(Opcode.@"and".validate_word(0xC040));
    try expect(Opcode.@"asm".validate_word(0xE0D0));
    try expect(Opcode.lsm.validate_word(0xE3D0));
    try expect(Opcode.roxm.validate_word(0xE5D0));
    try expect(Opcode.rom.validate_word(0xE7D0));
    try expect(Opcode.asd.validate_word(0xE440));
    try expect(Opcode.lsd.validate_word(0xE548));
    try expect(Opcode.roxd.validate_word(0xE550));
    try expect(Opcode.rod.validate_word(0xE558));
}

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
