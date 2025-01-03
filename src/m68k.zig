const std = @import("std");
const enc = @import("m68k/cpu/enc.zig");
const fmt = @import("m68k/cpu/fmt.zig");
pub const cpu = @import("m68k/cpu/cpu.zig");

// Run one instruction (and potentially handle exceptions (but not run their code))
pub fn runInstr(state: *cpu.State) void {
    if (state.halted) return;

    // Handle exceptions generated since last instruction
    state.tryPendingException();

    // Get lut byte from instruction word and jump to instruction function (with comptime variant)
    switch (decode_lut[state.ir]) {
        inline else => |lut_byte| {
            if (lut_to_instr[lut_byte]) |info| {
                const bits: AsInt(info.instr.Variant) = comptime info.variant;
                info.instr.run(state, @bitCast(bits));
            } else {
                state.pending_exception = @intFromEnum(cpu.Vector.illegal_instr);
            }
        },
    }
}

// Gets the length of an instruction in bytes
pub fn instrLenBytes(first_word: u16) usize {
    switch (decode_lut[first_word]) {
        inline else => |lut_byte| {
            if (lut_to_instr[lut_byte]) |info| {
                return info.instr.Encoding.getLen(@bitCast(first_word)) * 2;
            } else {
                return 0;
            }
        },
    }
}

pub const FormatInstr = struct {
    state: fmt.State,

    pub fn init(bus: *const cpu.Bus, addr: u32) FormatInstr {
        return .{ .state = .{ .bus = bus, .addr = addr } };
    }
    
    pub fn lenBytes(self: FormatInstr) usize {
        const word = self.state.bus.rd16(@truncate(self.state.addr));
        return instrLenBytes(word);
    }

    pub fn format(
        self: FormatInstr,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        var state = self.state;
        const word = state.next(enc.Size.word);
        switch (decode_lut[word]) {
            inline else => |lut_byte| {
                if (lut_to_instr[lut_byte]) |info| {
                    const formatter = info.instr.Fmt{
                        .fmt = @bitCast(word),
                        .data = &state,
                    };
                    try writer.print("{}", .{formatter});
                } else {
                    try writer.print("illegal", .{});
                }
            },
        }
    }
};

// Iterates over instructions
const InstrIterator = struct {
    instr: comptime_int,
    base: u8,

    fn init() InstrIterator {
        return .{
            .instr = -1,
            .base = 0,
        };
    }

    fn next(self: *InstrIterator) type {
        // Get by how much we need to advance base
        if (self.instr >= 0 and self.instr < instrs.len) {
            const instr = instrs[self.instr];
            self.base += 1 << @bitSizeOf(instr.Variant);
        }

        // Now advance instr and return
        self.instr += 1;
        if (self.instr < instrs.len) {
            return instrs[self.instr];
        } else {
            return void;
        }
    }
};

fn AsInt(comptime T: type) type {
    return std.meta.Int(.unsigned, @bitSizeOf(T));
}

// Makes sure that the packed struct can be represented by bits
fn validatePackedStruct(comptime T: type, bits: comptime_int) bool {
    var idx = 0;
    for (std.meta.fields(T)) |field| {
        const as_int: AsInt(field.type) = @truncate(bits >> idx);
        switch (@typeInfo(field.type)) {
            .Enum, .Struct, .Union => {
                if (@hasDecl(field.type, "match") and !field.type.match(as_int)) return false;
            },
            else => {},
        }
        idx += @bitSizeOf(field.type);
    }
    return true;
}

// Create the arguments from the encoding
fn encodingToVariant(comptime instr: type, comptime encoding: anytype) instr.Variant {
    var variant: instr.Variant = undefined;
    for (std.meta.fields(instr.Variant)) |field| {
        @field(variant, field.name) = @field(encoding, field.name);
    }
    return variant;
}

fn setEncodingPermutations(
    lut: *[0x10000]u8,
    base: u8,
    comptime instr: type,
    comptime Fields: []const std.builtin.Type.StructField,
    word: u16,
) void {
    // Base case
    if (Fields.len == 0) {
        if (!instr.Encoding.match(@bitCast(word))) return;
        const encoding: instr.Encoding = @bitCast(word);
        const as_bits: AsInt(instr.Variant) = @bitCast(encodingToVariant(instr, encoding));
        lut[word] = base + as_bits;
        return;
    }

    const idx = Fields.len - 1;
    const Field = Fields[idx].type;
    const size = @bitSizeOf(Field);
    const field_info = @typeInfo(Field);
    const next_word = if (size == 16) 0 else word << size;

    // It is a BitPattern?
    if (field_info == .Struct and @hasDecl(Field, "pattern")) {
        setEncodingPermutations(lut, base, instr, Fields[0..idx], next_word | Field.pattern);
        return;
    }

    // It is a matchable struct?
    if (switch (field_info) {
        .Struct, .Enum, .Union => true,
        else => false,
    } and @hasDecl(Field, "match")) {
        for (0..1 << size) |i| {
            if (!Field.match(i)) continue;
            setEncodingPermutations(lut, base, instr, Fields[0..idx], next_word | i);
        }
        return;
    }

    // It's not matchable so just do normal permutations
    for (0..1 << size) |i| {
        setEncodingPermutations(lut, base, instr, Fields[0..idx], next_word | i);
    }
}

// This byte signifies an instruction word is invalid
pub const invalid_instr_word: u8 = 0xFF;

// Cpu instruction decode lookup table
// If you index the table by the first word of an instruction, it gives you the correct run function
// to run for the instruction. Index 0xFF is for invalid instruction encodings and should run the
// illegal instruction exception handler.
const decode_lut: [0x10000]u8 = compute_lut: {
    var lut = [1]u8{invalid_instr_word} ** 0x10000;
    @setEvalBranchQuota(lut.len * 256 * 16);

    var iter = InstrIterator.init();
    while (true) {
        const instr = iter.next();
        if (instr == void) break;

        if (@bitSizeOf(instr.Encoding) != 16) {
            @compileLog(instr);
            @compileError("instruction encodings must be 16 bits!");
        }

        // Get all possible variations of the encoding and update them in the lookup table
        setEncodingPermutations(&lut, iter.base, instr, std.meta.fields(instr.Encoding), 0);
    }
    break :compute_lut lut;
};

// Generate table of lut bytes to instruction functions
const LutEntry = struct {
    instr: type, // Type related to this template instance
    variant: comptime_int, // Variant info specific to this template instance
};

// Generate a table to quickly go from decode lut byte to actual instruction type and variant info
const lut_to_instr: [0x100]?LutEntry = gen: {
    @setEvalBranchQuota(256 * 256);

    var lut = [1]?LutEntry{null} ** 0x100;
    var iter = InstrIterator.init();
    var instr = iter.next();
    while (instr != void) : (instr = iter.next()) {
        const Variant = instr.Variant;
        for (0..1 << @bitSizeOf(Variant)) |permutation| {
            // See if we can even encode this
            if (!validatePackedStruct(Variant, permutation)) continue;
            lut[iter.base + permutation] = .{
                .instr = instr,
                .variant = permutation,
            };
        }
    }
    break :gen lut;
};

// List of cpu instructions (as types of structs)
const instrs = .{
    @import("m68k/abcd_sbcd.zig"),
    @import("m68k/add_sub.zig"),
    @import("m68k/adda_suba.zig"),
    @import("m68k/addq_subq.zig"),
    //@import("m68k/addx_subx.zig"),
    //@import("m68k/and_or.zig"),
    //@import("m68k/b_cc.zig"),
    //@import("m68k/b_xxx_imm.zig"),
    //@import("m68k/b_xxx_reg.zig"),
    //@import("m68k/bitop_to_ccr.zig"),
    //@import("m68k/chk.zig"),
    //@import("m68k/cmp.zig"),
    //@import("m68k/cmpa.zig"),
    //@import("m68k/cmpi.zig"),
    //@import("m68k/cmpm.zig"),
    //@import("m68k/db_cc.zig"),
    //@import("m68k/div.zig"),
    //@import("m68k/eor.zig"),
    //@import("m68k/exg.zig"),
    //@import("m68k/ext.zig"),
    //@import("m68k/jmp.zig"),
    //@import("m68k/jsr.zig"),
    //@import("m68k/lea.zig"),
    //@import("m68k/link.zig"),
    //@import("m68k/move.zig"),
    //@import("m68k/move_from_sr.zig"),
    //@import("m68k/move_to_ccr.zig"),
    //@import("m68k/move_usp.zig"),
    //@import("m68k/movea.zig"),
    //@import("m68k/movem.zig"),
    //@import("m68k/movep.zig"),
    //@import("m68k/moveq.zig"),
    //@import("m68k/mul.zig"),
    //@import("m68k/nbcd.zig"),
    //@import("m68k/nop.zig"),
    //@import("m68k/not_neg_clr.zig"),
    //@import("m68k/opi.zig"),
    //@import("m68k/pea.zig"),
    //@import("m68k/reset.zig"),
    //@import("m68k/ret.zig"),
    //@import("m68k/s_cc.zig"),
    //@import("m68k/shift_mem.zig"),
    //@import("m68k/shift_reg.zig"),
    //@import("m68k/stop.zig"),
    //@import("m68k/swap.zig"),
    //@import("m68k/tas.zig"),
    //@import("m68k/trap.zig"),
    //@import("m68k/trapv.zig"),
    //@import("m68k/tst.zig"),
    //@import("m68k/unlk.zig"),
};

// Bus tester
const Bus = struct {
    bytes: [256]u8 = [_]u8{0} ** 256,

    pub fn rd8(self: *const Bus, addr: u24) u8 {
        if (addr > self.bytes.len - 1) return 0;
        return self.bytes[addr];
    }
    pub fn rd16(self: *const Bus, addr: u24) u16 {
        if (addr > self.bytes.len - 2) return 0;
        return std.mem.readInt(u16, self.bytes[addr..][0..2], .big);
    }
    pub fn rd32(self: *const Bus, addr: u24) u32 {
        if (addr > self.bytes.len - 4) return 0;
        return std.mem.readInt(u32, self.bytes[addr..][0..4], .big);
    }
    pub fn wr8(self: *Bus, addr: u24, byte: u8) void {
        if (addr > self.bytes.len - 1) return;
        self.bytes[addr] = byte;
    }
    pub fn wr16(self: *Bus, addr: u24, word: u16) void {
        if (addr > self.bytes.len - 2) return;
        std.mem.writeInt(u16, self.bytes[addr..][0..2], word, .big);
    }
    pub fn wr32(self: *Bus, addr: u24, long: u32) void {
        if (addr > self.bytes.len - 4) return;
        std.mem.writeInt(u32, self.bytes[addr..][0..4], long, .big);
    }
};

test "Bus Impl" {
    const expect = std.testing.expect;

    var impl = Bus{};
    var state = cpu.State.init(&impl);

    state.wrBus(enc.Size.byte, 4, 0xFF);
    try expect(state.rdBus(enc.Size.byte, 4) == 0xFF);
    try expect(state.rdBus(enc.Size.word, 4) == 0xFF00);
}

test "Instructions" {
    var bus = Bus{};
    var state = cpu.State.init(&bus);

    inline for (instrs) |instr| {
        // Write program
        @memset(&bus.bytes, 0);
        bus.wr32(0, 0x100); // Write stack pointer address
        bus.wr32(4, 0x8); // Write program start address
        var addr: u24 = 8;

        // Write program code
        for (instr.Tester.code) |word| {
            bus.wr16(addr, word);
            addr += 2;
        }

        // Reset and validate instruction
        state.handleException(@intFromEnum(cpu.Vector.reset));
        state.cycles = 0;
        while (state.regs.pc <= addr and !state.halted) {
            runInstr(&state);
        }
        try instr.Tester.validate(&state);
    }
}

const DisasmTester = struct {
    code: [16]u16,
    len: usize,
    
    pub fn init(code: []const u16) DisasmTester {
        var self: DisasmTester = .{
            .code = [1]u16{0} ** 16,
            .len = code.len,
        };
        @memcpy(self.code[0..code.len], code);
        return self;
    }
    
    pub fn check(self: DisasmTester, against: []const u8) !void {
        // Set up code
        var bus = Bus{};
        for (0..self.len) |i| {
            bus.wr16(@truncate(i * 2), self.code[i]);
        }
        const bus_interface = cpu.Bus.init(&bus);
        
        // Set up writer
        var tmp: [0x100]u8 = undefined;
        var stream = std.io.fixedBufferStream(&tmp);
        const writer = stream.writer();
        
        // See if they match
        const formatter = FormatInstr.init(&bus_interface, 0);
        if (formatter.lenBytes() != self.len * 2) {
            return error.DisassemblyLengthMismatch;
        }
        try writer.print("{}", .{formatter});
        if (!std.mem.eql(u8, stream.getWritten(), against)) {
            std.log.err("{s}", .{stream.getWritten()});
            return error.DisassemblyOutputMismatch;
        }
    }
};

test "Disassembly" {
    try DisasmTester.init(&[_]u16{0xCB00}).check("sbcd.b d0,d5");
    try DisasmTester.init(&[_]u16{0x8B0F}).check("abcd.b -(sp),-(a5)");
    try DisasmTester.init(&[_]u16{0xD154}).check("add.w d0,(a4)");
    try DisasmTester.init(&[_]u16{0xD0FC, 0xFFFF}).check("adda.w #-1,a0");
    try DisasmTester.init(&[_]u16{0x5683}).check("addq.l #3,d3");
    //try DisasmTester.init(&[_]u16{}).check("");
}
