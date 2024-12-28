const std = @import("std");
const opc = @import("opcode.zig");
const op = @import("op.zig");
const arg = @import("arg.zig");
const AddrMode = arg.AddrMode;
const expect = std.testing.expect;

// Holds data from first word about the instruction used in table to generate cycle timings and
// other data to make instruction decoding easier
pub const Instr = union(opc.Opcode) {
    ori_to_ccr: void,
    ori_to_sr: void,
    ori: SizeEffAddr,
    andi_to_ccr: void,
    andi_to_sr: void,
    andi: SizeEffAddr,
    subi: SizeEffAddr,
    addi: SizeEffAddr,
    eori_to_ccr: void,
    eori_to_sr: void,
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
    abcd: RegReg,
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
        ea: arg.EffAddr,
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
        const instr = switch (opcode) {
            .ori => Instr{ .ori = lssea(word) orelse return Instr.illegal },
            .andi => Instr{ .andi = lssea(word) orelse return Instr.illegal },
            .subi => Instr{ .subi = lssea(word) orelse return Instr.illegal },
            .addi => Instr{ .addi = lssea(word) orelse return Instr.illegal },
            .eori => Instr{ .eori = lssea(word) orelse return Instr.illegal },
            .cmpi => Instr{ .cmpi = lssea(word) orelse return Instr.illegal },
            .negx => Instr{ .negx = lssea(word) orelse return Instr.illegal },
            .clr => Instr{ .clr = lssea(word) orelse return Instr.illegal },
            .neg => Instr{ .neg = lssea(word) orelse return Instr.illegal },
            .not => Instr{ .not = lssea(word) orelse return Instr.illegal },
            .tst => Instr{ .tst = lssea(word) orelse return Instr.illegal },

            .btsti => Instr{ .btsti = lsea(word) },
            .bchgi => Instr{ .bchgi = lsea(word) },
            .bseti => Instr{ .bseti = lsea(word) },
            .bclri => Instr{ .bclri = lsea(word) },
            .move_from_sr => Instr{ .move_from_sr = lsea(word) },
            .move_to_ccr => Instr{ .move_to_ccr = lsea(word) },
            .move_to_sr => Instr{ .move_to_sr = lsea(word) },
            .nbcd => Instr{ .nbcd = lsea(word) },
            .pea => Instr{ .pea = lsea(word) },
            .tas => Instr{ .tas = lsea(word) },
            .jsr => Instr{ .jsr = lsea(word) },
            .jmp => Instr{ .jmp = lsea(word) },
            
            .divu => Instr{ .divu = decode_bitop(word) },
            .divs => Instr{ .divs = decode_bitop(word) },
            .mulu => Instr{ .mulu = decode_bitop(word) },
            .muls => Instr{ .muls = decode_bitop(word) },
            .btst => Instr{ .btst = decode_bitop(word) },
            .bchg => Instr{ .bchg = decode_bitop(word) },
            .bset => Instr{ .bset = decode_bitop(word) },
            .bclr => Instr{ .bclr = decode_bitop(word) },
            .lea => Instr{ .lea = decode_bitop(word) },
            .chk => Instr{ .chk = decode_bitop(word) },

            .movep => Instr{ .movep = Movep{
                .dn = op.brange(u3, word, 9),
                .an = op.brange(u3, word, 0),
                .dir = arg.MemDir.decode(op.brange(u1, word, 7), true),
                .size = arg.Size.from_bit(op.brange(u1, word, 6)),
            }},
            .move => Instr{ .move = decode_move(word) },
            .movea => Instr{ .movea = decode_move(word) },
            .ext => Instr{ .ext = Ext{
                .size = arg.Size.from_bit(op.brange(u1, word, 6)),
                .reg = op.brange(u3, word, 0),
            }},
            .link => Instr{ .link = op.brange(u3, word, 0)},
            .unlk => Instr{ .unlk = op.brange(u3, word, 0)},
            .move_usp => Instr{ .move_usp = MoveUsp{
                .dir = arg.MemDir.decode(op.brange(u1, word, 3), false),
                .reg = op.brange(u3, word, 0),
            }},
            .trap => Instr{ .trap = op.brange(u4, word, 0) },
            .swap => Instr{ .swap = op.brange(u3, word, 0) },
            .movem => Instr{ .movem = Movem{
                .dir = arg.MemDir.decode(op.brange(u1, word, 10), false),
                .size = arg.Size.from_bit(op.brange(u1, word, 6)),
                .ea = lsea(word),
            }},
            .addq => Instr{ .addq = decode_arithq(word) orelse return Instr.illegal },
            .subq => Instr{ .subq = decode_arithq(word) orelse return Instr.illegal },
            .s_cc => Instr{ .s_cc = Scc{
                .cond = @enumFromInt(op.brange(u4, word, 8)),
                .dst = lsea(word),
            }},
            .db_cc => Instr{ .db_cc = Dbcc{
                .cond = @enumFromInt(op.brange(u4, word, 8)),
                .reg = op.brange(u3, word, 0),
            }},
            .bra => Instr{ .bra = lsi8(word) },
            .bsr => Instr{ .bsr = lsi8(word) },
            .b_cc => Instr{ .b_cc = Bcc{
                .cond = @enumFromInt(op.brange(u4, word, 8)),
                .disp = lsi8(word),
            }},
            .moveq => Instr{ .moveq = Moveq{
                .reg = op.brange(u3, word, 9),
                .data = lsi8(word),
            }},
            .sbcd => Instr{ .sbcd = decode_bcd(word) },
            .abcd => Instr{ .abcd = decode_bcd(word) },
            .@"or" => Instr{ .@"or" = decode_opd(word) orelse return Instr.illegal },
            .sub => Instr{ .sub = decode_opd(word) orelse return Instr.illegal },
            .@"and" => Instr{ .@"and" = decode_opd(word) orelse return Instr.illegal },
            .add => Instr{ .add = decode_opd(word) orelse return Instr.illegal },
            .subx => Instr{ .subx = decode_opx(word) orelse return Instr.illegal },
            .addx => Instr{ .addx = decode_opx(word) orelse return Instr.illegal },
            .suba => Instr{ .suba = decode_opa(word) },
            .cmpa => Instr{ .cmpa = decode_opa(word) },
            .adda => Instr{ .adda = decode_opa(word) },
            .cmpm => Instr{ .cmpm = Cmpm{
                .regs = getregs(word),
                .size = arg.Size.from_bits(op.brange(u2, word, 6), true) orelse return Instr.illegal,
            }},
            .eor => Instr{ .eor = decode_opd_nosz(word) orelse return Instr.illegal },
            .cmp => Instr{ .cmp = decode_opd_nosz(word) orelse return Instr.illegal },
            .exg => Instr{ .exg = Exg{
                .mode = arg.ExgMode.decode(op.brange(u5, word, 3)) orelse return Instr.illegal,
                .regs = getregs(word),
            }},
            .@"asm" => Instr{ .@"asm" = decode_shiftmem(word) },
            .lsm => Instr{ .lsm = decode_shiftmem(word) },
            .roxm => Instr{ .roxm = decode_shiftmem(word) },
            .rom => Instr{ .rom = decode_shiftmem(word) },
            .asd => Instr{ .asd = decode_shift(word) orelse return Instr.illegal },
            .lsd => Instr{ .lsd = decode_shift(word) orelse return Instr.illegal },
            .roxd => Instr{ .roxd = decode_shift(word) orelse return Instr.illegal },
            .rod => Instr{ .rod = decode_shift(word) orelse return Instr.illegal },
            .illegal => Instr.illegal,
            .reset => Instr.reset,
            .nop => Instr.nop,
            .stop => Instr.stop,
            .rte => Instr.rte,
            .rts => Instr.rts,
            .trapv => Instr.trapv,
            .rtr => Instr.rtr,
            .ori_to_ccr => Instr.ori_to_ccr,
            .ori_to_sr => Instr.ori_to_sr,
            .andi_to_ccr => Instr.andi_to_ccr,
            .andi_to_sr => Instr.andi_to_sr,
            .eori_to_ccr => Instr.eori_to_ccr,
            .eori_to_sr => Instr.eori_to_sr,
        };
        return if (instr.validate()) instr else .illegal;
    }

    fn decode_bitop(word: u16) RegEffAddr {
        return .{
            .reg = op.brange(u3, word, 9),
            .ea = lsea(word),
        };
    }

    fn decode_move(word: u16) Move {
        return .{
            .size = arg.Size.from_bits(op.brange(u2, word, 12), false).?,
            .src = lsea(word),
            .dst = arg.EffAddr{ .mode = op.brange(u3, word, 6), .xn = op.brange(u3, word, 9) },
        };
    }
    
    fn decode_arithq(word: u16) ?Arithq {
        return .{
            .data = op.brange(u3, word, 9),
            .dst = lssea(word) orelse return null,
        };
    }
    
    fn decode_bcd(word: u16) RegReg {
        return .{
            .mode = AddrMode.from_binary_mode(op.brange(u1, word, 3)),
            .regs = getregs(word),
        };
    }
    
    fn decode_opd(word: u16) ?Opd {
        return .{
            .reg = op.brange(u3, word, 9),
            .size = arg.Size.from_bits(op.brange(u2, word, 6), true) orelse return null,
            .dir = @enumFromInt(op.brange(u1, word, 8)),
            .ea = lsea(word),
        };
    }
    
    fn decode_opx(word: u16) ?Opx {
        return .{
            .regs = getregs(word),
            .size = arg.Size.from_bits(op.brange(u2, word, 6), true) orelse return null,
            .mode = AddrMode.from_binary_mode(op.brange(u1, word, 3)),
        };
    }
    
    fn decode_opa(word: u16) Opa {
        return .{
            .reg = op.brange(u3, word, 9),
            .size = arg.Size.from_bit(op.brange(u1, word, 8)),
            .ea = lsea(word),
        };
    }
    
    fn decode_shiftmem(word: u16) ShiftMem {
        return .{
            .dir = @enumFromInt(op.brange(u1, word, 8)),
            .ea = lsea(word),
        };
    }
    
    fn decode_shift(word: u16) ?Shift {
        return .{
            .dir = @enumFromInt(op.brange(u1, word, 8)),
            .rotmode = @enumFromInt(op.brange(u1, word, 5)),
            .rot = op.brange(u3, word, 9),
            .size = arg.Size.from_bits(op.brange(u2, word, 6), true) orelse return null,
            .reg = op.brange(u3, word, 0),
        };
    }
    
    fn decode_opd_nosz(word: u16) ?Opa {
        return .{
            .reg = op.brange(u3, word, 9),
            .size = arg.Size.from_bits(op.brange(u2, word, 6), true) orelse return null,
            .ea = lsea(word),
        };
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
    fn validate(self: Instr) bool {
        return switch (self) {
            .add, .sub => |instr| valid: {
                const md = AddrMode.from_ea(instr.ea) orelse return false;
                if (instr.size == .byte and md == .addr_reg) return false;
                if (instr.dir == .ea_dn) return true;
                break :valid chkmd(md, &[_]AddrMode{ .data_reg, .addr_reg, .imm, .pc_disp, .pc_idx });
            },
            .@"and", .@"or" => |instr| valid: {
                const md = AddrMode.from_ea(instr.ea);
                if (instr.dir == .ea_dn) return md != .addr_reg;
                break :valid chkmd(md, &[_]AddrMode{ .data_reg, .addr_reg, .imm, .pc_disp, .pc_idx });
            },
            .cmp => |i| AddrMode.from_ea(i.ea) != .addr_reg or i.size != .byte,
            .movem => |instr| valid: {
                const md = AddrMode.from_ea(instr.ea);
                if (instr.dir == .reg_to_mem) {
                    break :valid chkmd(md, &[_]AddrMode{ .data_reg, .addr_reg, .imm, .addr_postinc, .pc_disp, .pc_idx });
                } else {
                    break :valid chkmd(md, &[_]AddrMode{ .data_reg, .addr_reg, .imm, .addr_predec });
                }
            },
            .addi,
            .andi,
            .eori,
            .neg,
            .negx,
            .not,
            .ori,
            .clr,
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
            .addq, .subq => |i| chkmd(AddrMode.from_ea(i.dst.ea), &[_]AddrMode{ .imm, .pc_disp, .pc_idx }),
            .@"asm",
            .lsm,
            .rom,
            .roxm,
            => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .data_reg, .addr_reg, .imm, .pc_disp, .pc_idx }),
            .cmpi => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .addr_reg, .imm }),
            .eor => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .addr_reg, .imm, .pc_disp, .pc_idx }),
            .jmp, .jsr => |ea| chkmd(AddrMode.from_ea(ea), &[_]AddrMode{ .data_reg, .addr_reg, .addr_postinc, .addr_predec, .imm }),
            .lea => |i| chkmd(AddrMode.from_ea(i.ea), &[_]AddrMode{ .data_reg, .addr_reg, .addr_postinc, .addr_predec, .imm }),
            .move => |i| chkmd(AddrMode.from_ea(i.dst), &[_]AddrMode{ .data_reg, .imm, .pc_disp, .pc_idx }),
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
            .bsr,
            .bra,
            .b_cc,
            .moveq,
            .roxd,
            .rod,
            .db_cc,
            .rte,
            .stop,
            .reset,
            .movep,
            .move_usp,
            => true,
        };
    }

    fn chkmd(mode: ?AddrMode, invalid: []const AddrMode) bool {
        if (mode == null) return false;
        return for (invalid) |currmode| {
            if (mode == currmode) break false;
        } else true;
    }
};

test "mode validation" {
    try expect(Instr.decode(0x003C) != Instr.illegal);
    try expect(Instr.decode(0x0040) != Instr.illegal);
    try expect(Instr.decode(0x023C) != Instr.illegal);
    try expect(Instr.decode(0x0240) != Instr.illegal);
    try expect(Instr.decode(0x0440) != Instr.illegal);
    try expect(Instr.decode(0x0640) != Instr.illegal);
    try expect(Instr.decode(0x0A3C) != Instr.illegal);
    try expect(Instr.decode(0x0A40) != Instr.illegal);
    try expect(Instr.decode(0x0800) != Instr.illegal);
    try expect(Instr.decode(0x0840) != Instr.illegal);
    try expect(Instr.decode(0x08C0) != Instr.illegal);
    try expect(Instr.decode(0x0880) != Instr.illegal);
    try expect(Instr.decode(0x0300) != Instr.illegal);
    try expect(Instr.decode(0x0340) != Instr.illegal);
    try expect(Instr.decode(0x03C0) != Instr.illegal);
    try expect(Instr.decode(0x0380) != Instr.illegal);
    try expect(Instr.decode(0x0188) != Instr.illegal);
    try expect(Instr.decode(0x3040) != Instr.illegal);
    try expect(Instr.decode(0x2040) != Instr.illegal);
    try expect(Instr.decode(0x1200) != Instr.illegal);
    try expect(Instr.decode(0x3200) != Instr.illegal);
    try expect(Instr.decode(0x2200) != Instr.illegal);
    try expect(Instr.decode(0x40C0) != Instr.illegal);
    try expect(Instr.decode(0x46C0) != Instr.illegal);
    try expect(Instr.decode(0x4AFC) == Instr.illegal);
    try expect(Instr.decode(0x4AC0) != Instr.illegal);
    try expect(Instr.decode(0x4A40) != Instr.illegal);
    try expect(Instr.decode(0x4E40) != Instr.illegal);
    try expect(Instr.decode(0x4E50) != Instr.illegal);
    try expect(Instr.decode(0x4E58) != Instr.illegal);
    try expect(Instr.decode(0x3E48) != Instr.illegal);
    try expect(Instr.decode(0x304F) != Instr.illegal);
    try expect(Instr.decode(0x4E70) != Instr.illegal);
    try expect(Instr.decode(0x4E71) != Instr.illegal);
    try expect(Instr.decode(0x4E72) != Instr.illegal);
    try expect(Instr.decode(0x4E73) != Instr.illegal);
    try expect(Instr.decode(0x4E75) != Instr.illegal);
    try expect(Instr.decode(0x4E76) != Instr.illegal);
    try expect(Instr.decode(0x4E77) != Instr.illegal);
    try expect(Instr.decode(0x4E90) != Instr.illegal);
    try expect(Instr.decode(0x4ED0) != Instr.illegal);
    try expect(Instr.decode(0x48A0) != Instr.illegal);
    try expect(Instr.decode(0x48E0) != Instr.illegal);
    try expect(Instr.decode(0x4C98) != Instr.illegal);
    try expect(Instr.decode(0x4CD8) != Instr.illegal);
    try expect(Instr.decode(0x41D0) != Instr.illegal);
    try expect(Instr.decode(0x4181) != Instr.illegal);
    try expect(Instr.decode(0x8101) != Instr.illegal);
    try expect(Instr.decode(0x9001) != Instr.illegal);
    try expect(Instr.decode(0x9111) != Instr.illegal);
    try expect(Instr.decode(0x9041) != Instr.illegal);
    try expect(Instr.decode(0x90C1) != Instr.illegal);
    try expect(Instr.decode(0x9151) != Instr.illegal);
    try expect(Instr.decode(0x9081) != Instr.illegal);
    try expect(Instr.decode(0x91C1) != Instr.illegal);
    try expect(Instr.decode(0x9191) != Instr.illegal);
    try expect(Instr.decode(0x9048) != Instr.illegal);
    try expect(Instr.decode(0x5A40) != Instr.illegal);
    try expect(Instr.decode(0x5B40) != Instr.illegal);
    try expect(Instr.decode(0x57C0) != Instr.illegal);
    try expect(Instr.decode(0x56C8) != Instr.illegal);
    try expect(Instr.decode(0x6000) != Instr.illegal);
    try expect(Instr.decode(0x6100) != Instr.illegal);
    try expect(Instr.decode(0x6600) != Instr.illegal);
    try expect(Instr.decode(0x7003) != Instr.illegal);
    try expect(Instr.decode(0x80FC) != Instr.illegal);
    try expect(Instr.decode(0x81FC) != Instr.illegal);
    try expect(Instr.decode(0x8300) != Instr.illegal);
    try expect(Instr.decode(0x8110) != Instr.illegal);
    try expect(Instr.decode(0x9050) != Instr.illegal);
    try expect(Instr.decode(0x9140) != Instr.illegal);
    try expect(Instr.decode(0x91C8) != Instr.illegal);
    try expect(Instr.decode(0xB141) != Instr.illegal);
    try expect(Instr.decode(0xB348) != Instr.illegal);
    try expect(Instr.decode(0xB048) != Instr.illegal);
    try expect(Instr.decode(0xB0C0) != Instr.illegal);
    try expect(Instr.decode(0xC0FC) != Instr.illegal);
    try expect(Instr.decode(0xC1FC) != Instr.illegal);
    try expect(Instr.decode(0xC100) != Instr.illegal);
    try expect(Instr.decode(0xC188) != Instr.illegal);
    try expect(Instr.decode(0xC040) != Instr.illegal);
    try expect(Instr.decode(0xE0D0) != Instr.illegal);
    try expect(Instr.decode(0xE3D0) != Instr.illegal);
    try expect(Instr.decode(0xE5D0) != Instr.illegal);
    try expect(Instr.decode(0xE7D0) != Instr.illegal);
    try expect(Instr.decode(0xE440) != Instr.illegal);
    try expect(Instr.decode(0xE548) != Instr.illegal);
    try expect(Instr.decode(0xE550) != Instr.illegal);
    try expect(Instr.decode(0xE558) != Instr.illegal);
}
