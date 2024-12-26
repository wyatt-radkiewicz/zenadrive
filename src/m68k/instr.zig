const std = @import("std");
const opc = @import("opcode.zig");
const op = @import("op.zig");
const arg = @import("arg.zig");

// Holds data from first word about the instruction used in table to generate cycle timings and
// other data to make instruction decoding easier
pub const Instr = union(opc.Opcode) {
    ori_to_ccr: arg.EffAddr,
    ori_to_sr: arg.EffAddr,
    ori: SizeEffAddr,
    andi_to_ccr: arg.EffAddr,
    andi_to_sr: arg.EffAddr,
    andi: SizeEffAddr,
    subi: SizeEffAddr,
    addi: SizeEffAddr,
    eori_to_ccr: arg.EffAddr,
    eori_to_sr: arg.EffAddr,
    eori: SizeEffAddr,
    cmpi: SizeEffAddr,
    btsti: arg.EffAddr,
    bchgi: arg.EffAddr,
    bclri: arg.EffAddr,
    bseti: arg.EffAddr,
    btst: RegEffAddr,
    bchg: RegEffAddr,
    bclr: RegEffAddr,
    bset: RegEffAddr,
    movep: Movep,
    movea: Move,
    move: Move,
    move_from_sr: arg.EffAddr,
    move_to_ccr: arg.EffAddr,
    move_to_sr: arg.EffAddr,
    negx: SizeEffAddr,
    clr: SizeEffAddr,
    neg: SizeEffAddr,
    not: SizeEffAddr,
    ext: SizeReg,
    nbcd: arg.EffAddr,
    swap: u3,
    pea: arg.EffAddr,
    illegal: void,
    tas: arg.EffAddr,
    tst: SizeEffAddr,
    trap: u4,
    link: u3,
    unlk: u3,
    move_usp: MoveUsp,
    reset: void,
    nop: void,
    stop: void,
    rte: void,
    rts: void,
    trapv: void,
    rtr: void,
    jsr: arg.EffAddr,
    jmp: arg.EffAddr,
    movem: Movem,
    lea: RegEffAddr,
    chk: RegEffAddr,
    addq: Arithq,
    subq: Arithq,
    s_cc: Scc,
    db_cc: Dbcc,
    bra: i8,
    bsr: i8,
    b_cc: Bcc,
    moveq: Moveq,
    divu: RegEffAddr,
    divs: RegEffAddr,
    sbcd: RegReg,
    @"or": Opd,
    sub: Opd,
    subx: Opx,
    suba: Opa,
    eor: Opa,
    cmpm: Opx,
    cmp: Opa,
    cmpa: Opa,
    mulu: RegEffAddr,
    muls: RegEffAddr,
    abcd: Opx,
    exg: Exg,
    @"and": Opd,
    add: Opd,
    addx: Opx,
    adda: Opa,
    @"asm": ShiftMem,
    lsm: ShiftMem,
    roxm: ShiftMem,
    rom: ShiftMem,
    asd: Shift,
    lsd: Shift,
    roxd: Shift,
    rod: Shift,
    
    pub const SizeEffAddr = struct {
        size: arg.Size,
        ea: arg.EffAddr,
    };
    pub const RegEffAddr = struct {
        reg: u3,
        ea: arg.EffAddr,
    };
    pub const SizeReg = struct {
        size: arg.Size,
        reg: u3,
    };
    pub const MoveUsp = struct {
        dir: arg.MemDir,
        reg: u3,
    };
    pub const Movep = struct {
        dn: u3,
        an: u3,
        dir: arg.MemDir,
        size: arg.Size,
    };
    pub const Movem = struct {
        dir: arg.MemDir,
        size: arg.Size,
        ea: arg.EffAddr,
    };
    pub const Move = struct {
        size: arg.Size,
        src: arg.EffAddr,
        dst: arg.EffAddr,
    };
    pub const Arithq = struct {
        data: u3,
        dst: SizeEffAddr,
    };
    pub const Scc = struct {
        cond: arg.Cond,
        dst: arg.EffAddr,
    };
    pub const Dbcc = struct {
        cond: arg.Cond,
        reg: u3,
    };
    pub const Bcc = struct {
        cond: arg.Cond,
        disp: i8,
    };
    pub const Moveq = struct {
        reg: u3,
        data: i8,
    };
    pub const RegReg = struct {
        mode: arg.AddrMode,
        regs: [2]u3,
    };
    pub const Opd = struct {
        reg: u3,
        size: arg.Size,
        dir: arg.ArgDir,
        ea: arg.EffAddr,
    };
    pub const Opa = struct {
        reg: u3,
        size: arg.Size,
        ea: arg.EffAddr,
    };
    pub const Opx = struct {
        regs: [2]u3,
        size: arg.Size,
    };
    pub const Exg = struct {
        mode: arg.ExgMode,
        regs: [2]u3,
    };
    pub const ShiftMem = struct {
        dir: arg.ShiftDir,
        ea: arg.AddrMode,
    };
    pub const Shift = struct {
        dir: arg.ShiftDir,
        rotmode: arg.Rotation,
        rot: u3,
        size: arg.Size,
        reg: u3,
    };
};
