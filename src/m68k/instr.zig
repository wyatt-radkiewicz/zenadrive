const std = @import("std");
const opc = @import("opcode.zig");
const op = @import("op.zig");
const arg = @import("arg.zig");
const AddrMode = arg.AddrMode;

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
    ext: Ext,
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
    cmpm: Cmpm,
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
    pub const Ext = struct {
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
        mode: AddrMode,
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
        mode: AddrMode,
    };
    pub const Cmpm = struct {
        regs: [2]u3,
        size: arg.Size,
    };
    pub const Exg = struct {
        mode: arg.ExgMode,
        regs: [2]u3,
    };
    pub const ShiftMem = struct {
        dir: arg.ShiftDir,
        ea: AddrMode,
    };
    pub const Shift = struct {
        dir: arg.ShiftDir,
        rotmode: arg.Rotation,
        rot: u3,
        size: arg.Size,
        reg: u3,
    };

    // If the encoding can not be converted to the instruction encoding it will return illegal instr
    pub fn decode(word: u16) Instr {
        const opcode = opc.Opcode.decode(word);
        return @unionInit(Instr, @tagName(opcode), switch (opcode) {
            .ori,
            .andi,
            .subi,
            .addi,
            .eori,
            .cmpi,
            .negx,
            .clr,
            .neg,
            .not,
            .tst,
            => lssea(word) orelse return Instr.illegal,
            .btsti,
            .bchgi,
            .bseti,
            .bclri,
            .move_from_sr,
            .move_to_ccr,
            .move_to_sr,
            .nbcd,
            .pea,
            .tas,
            .jsr,
            .jmp,
            .divu,
            .divs,
            .mulu,
            .muls,
            => lsea(word),
            .btst, .bchg, .bset, .bclr, .lea, .chk => RegEffAddr{
                .reg = op.brange(u3, word, 9),
                .ea = lsea(word),
            },
            .movep => Movep{
                .dn = op.brange(u3, word, 9),
                .an = op.brange(u3, word, 0),
                .dir = arg.MemDir.decode(op.brange(u1, word, 7), true),
                .size = arg.Size.from_bit(op.brange(u1, word, 6)),
            },
            .move, .movea => Move{
                .size = arg.Size.from_bits(op.brange(u2, word, 12), false).?,
                .src = lsea(word),
                .dst = arg.EffAddr{ .mode = op.brange(u3, word, 6), .xn = op.brange(u3, word, 9) },
            },
            .ext => Ext{
                .size = arg.Size.from_bit(op.brange(u1, word, 6)),
                .reg = op.brange(u3, word, 0),
            },
            .link, .unlk => op.brange(u3, word, 0),
            .move_usp => MoveUsp{
                .dir = arg.MemDir.decode(op.brange(u1, word, 3), false),
                .reg = op.brange(u3, word, 0),
            },
            .trap => op.brange(u4, word, 0),
            .movem => Movem{
                .dir = arg.MemDir.decode(op.brange(u1, word, 10), false),
                .size = arg.Size.from_bit(op.brange(u1, word, 6)),
                .ea = lsea(word),
            },
            .addq, .subq => Arithq{
                .data = op.brange(u3, word, 9),
                .dst = lssea(word) orelse return Instr.illegal,
            },
            .s_cc => Scc{
                .cond = @bitCast(op.brange(u4, word, 8)),
                .dst = lsea(word),
            },
            .db_cc => Dbcc{
                .cond = @bitCast(op.brange(u4, word, 8)),
                .reg = op.brange(u3, word, 0),
            },
            .bra, .bsr => lsi8(word),
            .b_cc => Bcc{
                .cond = @bitCast(op.brange(u4, word, 8)),
                .disp = lsi8(word),
            },
            .moveq => Moveq{
                .reg = op.brange(u3, word, 9),
                .data = lsi8(word),
            },
            .sbcd, .abcd => RegReg{
                .mode = AddrMode.from_binary_mode(op.brange(u1, word, 3)),
                .regs = getregs(word),
            },
            .@"or", .sub, .eor, .@"and", .add => Opd{
                .reg = op.brange(u3, word, 9),
                .size = arg.Size.from_bits(op.brange(u2, word, 6)),
                .dir = @bitCast(op.brange(u1, word, 8)),
                .ea = lsea(word),
            },
            .subx, .addx => Opx{
                .regs = getregs(word),
                .size = arg.Size.from_bits(op.brange(u2, word, 6)),
                .mode = AddrMode.from_binary_mode(op.brange(u1, word, 3)),
            },
            .suba, .cmpa, .adda => Opa{
                .reg = op.brange(u3, word, 9),
                .size = arg.Size.from_bit(op.brange(u1, word, 8)),
                .ea = lsea(word),
            },
            .cmpm => Cmpm{
                .regs = getregs(word),
                .size = arg.Size.from_bits(op.brange(u2, word, 6)),
            },
            .cmp => Opa{
                .reg = op.brange(u3, word, 9),
                .size = arg.Size.from_bits(op.brange(u2, word, 6)),
                .ea = lsea(word),
            },
            .exg => Exg{
                .mode = arg.ExgMode.decode(op.brange(u5, word, 3)) orelse return Instr.illegal,
                .regs = getregs(word),
            },
            .@"asm", .lsm, .roxm, .rom => ShiftMem{
                .dir = @bitCast(op.brange(u1, word, 8)),
                .ea = lsea(word),
            },
            .asd, .lsd, .roxd, .rod => Shift{
                .dir = @bitCast(op.brange(u1, word, 8)),
                .rotmode = @bitCast(op.brange(u1, word, 5)),
                .rot = op.brange(u3, word, 9),
                .size = arg.Size.from_bits(op.brange(u2, word, 6)),
                .reg = op.brange(u3, word, 0),
            },
            .illegal, .reset, .nop, .stop, .rte, .rts, .trapv, .rtr => {},
        });
    }

    // Get least significant effective address mode from a word
    fn lsea(word: u16) arg.EffAddr {
        return .{ .mode = op.brange(u3, word, 3), .xn = op.brange(u3, word, 0) };
    }

    // Get least significant size/effective addressing mode
    fn lssea(word: u16) ?SizeEffAddr {
        return .{
            .size = arg.Size.from_bits(op.brange(u2, word, 6), true) orelse return null,
            .ea = lsea(word),
        };
    }

    fn lsi8(word: u16) i8 {
        return @bitCast(op.brange(u8, word, 0));
    }

    fn getregs(word: u16) [2]u3 {
        return .{ op.brange(u3, word, 9), op.brange(u3, word, 0) };
    }

    // Validate arguments/operands given to this instruction
    pub fn validate(self: Instr) bool {
        return switch (self) {
            .add, .sub => |instr| valid: {
                const md = AddrMode.from_ea(instr.ea);
                if (instr.size == .byte and md == .addr_reg) return false;
                if (instr.dir == .ea_dn) return true;
                break :valid chkmd(md, &[_]AddrMode{ .data_reg, .addr_reg, .imm, .pc_disp, .pc_idx });
            },
            .addi,
            .andi,
            .eori,
            .neg,
            .negx,
            .not,
            .ori,
            .subi,
            => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .addr_reg, .imm, .pc_disp, .pc_idx }),
            .tst => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .addr_reg, .imm }),
            .bchg,
            .bclr,
            .bset,
            => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .addr_reg, .imm, .pc_disp, .pc_idx }),
            .bchgi,
            .bclri,
            .bseti,
            .clr,
            .move_from_sr,
            .nbcd,
            .tas,
            => |ea| chkmd(AddrMode.from_ea(ea), &[_]AddrMode{ .addr_reg, .imm, .pc_disp, .pc_idx }),
            .pea => |ea| chkmd(AddrMode.from_ea(ea), &[_]AddrMode{ .data_reg, .addr_reg, .imm, .addr_postinc, .addr_predec }),
            .btst,
            .chk,
            .divu,
            .divs,
            .mulu,
            .muls,
            => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{.addr_reg}),
            .move_to_sr, .move_to_ccr => |ea| chkmd(AddrMode.from_ea(ea), &[_]AddrMode{.addr_reg}),
            .btsti => |ea| chkmd(AddrMode.from_ea(ea), &[_]AddrMode{ .addr_reg, .imm }),
            .addq, .subq => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .imm, .pc_disp, .pc_idx }),
            .@"and", .@"or" => |instr| valid: {
                const md = AddrMode.from_ea(instr.ea);
                if (instr.dir == .ea_dn) return md != .addr_reg;
                break :valid chkmd(md, &[_]AddrMode{ .data_reg, .addr_reg, .imm, .pc_disp, .pc_idx });
            },
            .@"asm",
            .lsm,
            .rom,
            .roxm,
            => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .data_reg, .addr_reg, .imm, .pc_disp, .pc_idx }),
            .cmp => |i| AddrMode.from_ea(i.ea) != .addr_reg or i.size != .byte,
            .cmpi => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .addr_reg, .imm }),
            .eor => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .addr_reg, .imm, .pc_disp, .pc_idx }),
            .jmp, .jsr => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .data_reg, .addr_reg, .addr_postinc, .addr_predec, .imm }),
            .lea => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .data_reg, .addr_reg, .addr_postinc, .addr_predec, .imm }),
            .move => |i| chkmd(AddrMode.from_ea(i.dst), &[_]AddrMode{ .data_reg, .imm, .pc_disp, .pc_idx }),
            .movem => |instr| valid: {
                const md = AddrMode.from_ea(instr.ea);
                if (instr.dir == .reg_to_mem) {
                    break :valid chkmd(md, &[_]AddrMode{ .data_reg, .addr_reg, .imm, .addr_postinc, .pc_disp, .pc_idx });
                } else {
                    break :valid chkmd(md, &[_]AddrMode{ .data_reg, .addr_reg, .imm, .addr_predec });
                }
            },
            .s_cc => |i| chkmd(AddrMode.from_ea(i.dst), &[_]AddrMode{ .addr_reg, .imm, .pc_disp, .pc_idx }),
            .abcd,
            .adda,
            .addx,
            .subx,
            .swap,
            .andi_to_sr,
            .andi_to_ccr,
            .asd,
            .cmpa,
            .cmpm,
            .eori_to_ccr,
            .eori_to_sr,
            .exg,
            .ext,
            .illegal,
            .link,
            .lsd,
            .movea,
            .nop,
            .ori_to_ccr,
            .ori_to_sr,
            .rtr,
            .rts,
            .sbcd,
            .suba,
            .trap,
            .trapv,
            .unlk,
            => true,
        };
    }

    fn chkmd(mode: AddrMode, invalid: []const AddrMode) bool {
        return for (invalid) |currmode| {
            if (mode == currmode) break false;
        } else true;
    }
};
