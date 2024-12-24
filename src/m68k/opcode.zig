const std = @import("std");
const ops = @import("ops.zig");

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
                return @field(Opcode, std.fmt.comptimePrint("decode_line_{b}"), .{ line })(word);
            }
        }
    }

    fn decode_line_0(word: u16) Opcode {
        if (ops.getbit(word, 8)) {
            // Okay! we have either movep, or bit manipulation instructions with register operands
            
        } else {
            // Immidiate instructions
            return switch (ops.brange(u3, word, 9)) {
                0b000 => {
                    if ()
                }
            }
        }
    }
};
