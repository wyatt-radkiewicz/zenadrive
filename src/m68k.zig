const std = @import("std");

/// Bus interface for working with the emulated m68k chip
pub const Bus = struct {
    ptr: *anyopaque,
    vtable: VTable,

    pub const VTable = struct {
        read8: *const fn (*anyopaque, u24) u8,
        read16: *const fn (*anyopaque, u24) u16,
        read32: *const fn (*anyopaque, u24) u32,

        write8: *const fn (*anyopaque, u24, u8) void,
        write16: *const fn (*anyopaque, u24, u16) void,
        write32: *const fn (*anyopaque, u24, u32) void,
    };

    /// Read data from memory
    fn read8(self: *const Bus, fulladdr: u32) u8 {
        const addr: u24 = @truncate(fulladdr);
        return self.vtable.read8(self.ptr, addr);
    }
    fn read16(self: *const Bus, fulladdr: u32) u16 {
        const addr: u24 = @truncate(fulladdr);
        return self.vtable.read16(self.ptr, addr);
    }
    fn read32(self: *const Bus, fulladdr: u32) u32 {
        const addr: u24 = @truncate(fulladdr);
        return self.vtable.read32(self.ptr, addr);
    }

    /// Write data to memory
    fn write8(self: *const Bus, fulladdr: u32, val: u8) void {
        const addr: u24 = @truncate(fulladdr);
        self.vtable.write8(self.ptr, addr, val);
    }
    fn write16(self: *const Bus, fulladdr: u32, val: u16) void {
        const addr: u24 = @truncate(fulladdr);
        self.vtable.write16(self.ptr, addr, val);
    }
    fn write32(self: *const Bus, fulladdr: u32, val: u32) void {
        const addr: u24 = @truncate(fulladdr);
        self.vtable.write32(self.ptr, addr, val);
    }
};

/// Cpu state for emulation
pub const Cpu = struct {
    regs: Registers,
    bus: Bus,

    /// Set internal cpu state data to known values
    pub fn init(bus: *const Bus) Cpu {
        return .{
            .regs = undefined,
            .bus = bus.*,
        };
    }

    /// Reset cpu like the reset instruction would
    pub fn reset(self: *Cpu) void {
        self.regs = Registers.reset();
        self.regs.pc = self.bus.read32(Vector.reset_program_counter.offset());
        self.regs.addr[Registers.sp] = self.bus.read32(Vector.reset_stack_pointer.offset());
    }

    /// Run N number of cpu cycles (approx)
    pub fn execute_cycles(self: *Cpu, ntimes: u32) Error!void {
        var cycles: u32 = 0;
        while (cycles < ntimes) {
            @setEvalBranchQuota(std.math.maxInt(u16) + 1);
            const word = self.fetch_instr_word();

            // Jump to code to execute the specific permutaiton of the instrction
            switch (word) {
                inline 0...0x0100 => |permutation| {
                    cycles += try self.execute_instr(@bitCast(permutation));
                },
                else => unreachable,
                //inline else => |permutation| {
                //    cycles += self.execute_instr(@bitCast(permutation));
                //}
            }
        }
    }

    // Fetch next word of data from the program counter
    fn fetch_instr_word(self: *Cpu) u16 {
        const word = self.bus.read16(self.regs.pc);
        self.regs.pc += 2;
        return word;
    }
    
    // Fetchs and sign extends displacement word
    fn fetch_disp_word(self: *Cpu) u32 {
        const word: i16 = @bitCast(self.fetch_instr_word());
        return extend(u32, word);
    }

    // Runs the instruction (taking first instruction word as input) and returns number of cycles
    // used in the instruction
    fn execute_instr(self: *Cpu, comptime instr: Instr) Error!u32 {
        switch (instr.line) {
            0b0000 => return self.execute_line0(Instr.Line0.from_instr(instr)),
            else => return 1,
        }
    }

    // Execute immediates/bit manipulation/movep
    fn execute_line0(self: *Cpu, comptime instr: Instr.Line0) Error!u32 {
        if (instr.is_movep_or_bitmanip) {
            return 1;
            //if (instr.addr_mode == .addr) {
            //    return execute_movep(self, instr);
            //} else {
            //    return execute_bit_ops(self, instr);
            //}
        } else {
            return switch (instr.dn) {
                0b000 => execute_ori(self, instr),
                else => return 1,
                //0b001 => execute_andi(self, instr),
                //0b010 => execute_subi(self, instr),
                //0b011 => execute_addi(self, instr),
                //0b101 => execute_eori(self, instr),
                //0b110 => execute_cmpi(self, instr),
                //0b100 => execute_bit_ops(self, instr),
            };
        }
    }

    fn execute_ori(self: *Cpu, comptime instr: Instr.Line0) Error!u32 {
        const size = comptime Instr.Size.decode2(instr.size, true);
        const imm = self.fetch_instr_word();

        if (instr.addr_mode == .special and instr.xn == 0b100) {
            // Or to the status register
            switch (size) {
                .byte, .word => {
                    self.regs.sr = @bitCast(@as(u16, @bitCast(self.regs.sr)) | imm);
                },
                .long => return Error.IllegalInstruction,
            }
        }

        // Can't do logical OR to address register
        if (instr.addr_mode == .addr) {
            return Error.IllegalInstruction;
        }

        // Do normal OR
        const reg = self.load_ea(instr.addr_mode, size.backing_type(), instr.xn);
        self.store_ea(instr.addr_mode, instr.xn, imm | reg);
        return 1;
    }

    // Load address register with specific size, extending the word in the process
    fn load_addr_reg(self: *Cpu, reg: u3, comptime size: Instr.Size) u32 {
        return @as(u32, @bitCast(@as(i32, @as(size.backing_type(), @truncate(self.regs.addr[reg])))));
    }

    // Load data register with specific size
    fn load_data_reg(self: *Cpu, reg: u3, comptime size: Instr.Size) u32 {
        return @as(u32, @as(size.backing_type(), @truncate(self.regs.data[reg])));
    }

    // Read data (with any type)
    fn read(self: *Cpu, comptime T: type, addr: u32) T {
        switch (@typeInfo(T)) {
            .Int => |info| {
                return switch (info.bits) {
                    8 => self.bus.read8(addr),
                    16 => self.bus.read16(addr),
                    32 => self.bus.read32(addr),
                    else => @compileError("trying to write data thay you can not write!"),
                };
            },
            else => @compileError("trying to write data thay you can not write!"),
        }
    }

    // Write data (with any type)
    fn write(self: *Cpu, addr: u32, data: anytype) void {
        switch (@typeInfo(@TypeOf(data))) {
            .Int => |info| {
                switch (info.bits) {
                    8 => self.bus.write8(addr, @bitCast(data)),
                    16 => self.bus.write16(addr, @bitCast(data)),
                    32 => self.bus.write32(addr, @bitCast(data)),
                    else => @compileError("trying to write data thay you can not write!"),
                }
            },
            else => @compileError("trying to write data thay you can not write!"),
        }
    }

    // Store into effective address. If mode is a special mode, it will load 16 more bits
    // to get the brief extension word
    fn store_ea(self: *Cpu, mode: Instr.AddrMode, xn: u3, val: anytype) void {
        switch (mode) {
            .data_reg => {
                self.regs.data[xn] = overwrite(self.regs.data[xn], val);
            },
            .addr_reg => {
                self.regs.addr[xn] = extend(u32, val);
            },
            .addr => {
                self.write(self.regs.addr[xn], val);
            },
            .addr_postinc => {
                self.write(self.regs.addr[xn], val);
                self.regs.addr[xn] += @sizeOf(@TypeOf(val));
            },
            .addr_predec => {
                self.regs.addr[xn] -= @sizeOf(@TypeOf(val));
                self.write(self.regs.addr[xn], val);
            },
            .addr_disp => {
                var addr = self.regs.addr[xn];
                addr +%= self.fetch_disp_word();
                self.write(addr, val);
            },
            .addr_idx => {
                const bew: Instr.ExtensionWord = @bitCast(self.fetch_instr_word());
                var addr = self.regs.addr[xn];
                addr +%= extend(u32, bew.disp);
                addr += reg: {
                    if (bew.is_addr_reg) {
                        break :reg self.load_addr_reg(bew.xn, Instr.Size.decode1(bew.size));
                    } else {
                        break :reg self.load_data_reg(bew.xn, Instr.Size.decode1(bew.size));
                    }
                };
                self.write(addr, val);
            },
            .special => {
                switch (@as(Instr.AddrModeSpecial, @enumFromInt(xn))) {
                    .abs_short => {
                        const loc: u32 = extend(u32, self.fetch_instr_word());
                        self.write(loc, val);
                    },
                    .abs_long => {
                        const loc: u32 = @bitCast(@as(i32, @as(i16, @bitCast(self.fetch_instr_word()))));
                        self.write(loc, val);
                    },
                    .pc_disp => {},
                    .pc_idx => {},
                    .imm => {},
                    _ => {},
                }
            },
        }
    }

    // Store from effective address. If mode is a special mode, it will load 16 more bits
    // to get the brief extension word
    fn load_ea(self: *Cpu, mode: Instr.AddrMode, comptime T: type, xn: u3) T {
        switch (mode) {
            .data_reg => {
                return @truncate(self.regs.data[xn]);
            },
            .addr_reg => {
                return @truncate(self.regs.addr[xn]);
            },
            .addr => {
                return self.read(T, self.regs.addr[xn]);
            },
            .addr_postinc => {
                const val = self.read(T, self.regs.addr[xn]);
                self.regs.addr[xn] += @sizeOf(T);
                return val;
            },
            .addr_predec => {
                self.regs.addr[xn] -= @sizeOf(T);
                return self.read(T, self.regs.addr[xn]);
            },
            .addr_disp => {
                var addr = self.regs.addr[xn];
                addr +%= self.fetch_disp_word();
                return self.read(T, addr);
            },
            .addr_idx => {
                const bew: Instr.ExtensionWord = @bitCast(self.fetch_instr_word());
                var addr = self.regs.addr[xn];
                addr +%= extend(u32, bew.disp);
                addr += reg: {
                    const size = switch(bew.size) {
                        inline else => |bs| Instr.Size.decode1(bs),
                    };
                    if (bew.is_addr_reg) {
                        break :reg self.load_addr_reg(bew.xn, size);
                    } else {
                        break :reg self.load_data_reg(bew.xn, size);
                    }
                };
                return self.read(T, addr);
            },
            .special => {
                switch (@as(Instr.AddrModeSpecial, @enumFromInt(xn))) {
                    .abs_short => {
                        const loc: u32 = extend(u32, self.fetch_instr_word());
                        return self.read(T, loc);
                    },
                    .abs_long => {
                        const loc: u32 = @bitCast(@as(i32, @as(i16, @bitCast(self.fetch_instr_word()))));
                        return self.read(T, loc);
                    },
                    .pc_disp => {
                        var loc = self.regs.pc;
                        loc +%= self.fetch_disp_word();
                        return self.read(T, loc);
                    },
                    .pc_idx => {
                        var addr = self.regs.pc;
                        const bew: Instr.ExtensionWord = @bitCast(self.fetch_instr_word());
                        addr +%= extend(u32, bew.disp);
                        addr += reg: {
                            if (bew.is_addr_reg) {
                                break :reg self.load_addr_reg(bew.xn, Instr.Size.decode1(bew.size));
                            } else {
                                break :reg self.load_data_reg(bew.xn, Instr.Size.decode1(bew.size));
                            }
                        };
                        return self.read(T, addr);
                    },
                    .imm => {
                        switch (@typeInfo(T)) {
                            .Int => |info| switch (info.bits) {
                                8, 16 => {
                                    const imm = self.fetch_instr_word();
                                    return @truncate(imm);
                                },
                                32 => {
                                    const hi: u32 = self.fetch_instr_word();
                                    const lo: u32 = self.fetch_instr_word();
                                    return hi << 16 | lo;
                                },
                                else => @compileError("Can only handle u8,u16, or u32 immediates"),
                            },
                            else => @compileError("Can only handle u8,u16, or u32 immediates"),
                        }
                    },
                    _ => {},
                }
            },
        }
    }
};

// Any error while interpreting m68k instructions
const Error = error{
    IllegalInstruction,
};

// Sign extends dst to type type
fn extend(comptime To: type, dest: anytype) To {
    const as_signed = @Type(std.builtin.Type{ .Int = .{
        .bits = @typeInfo(To).Int.bits,
        .signedness = .signed,
    } });
    return @bitCast(@as(as_signed, @intCast(dest)));
}

// Functions for overriding only parts of a 32 bit value
fn overwrite(source: u32, dest: anytype) u32 {
    switch (@typeInfo(dest)) {
        .Int => |info| {
            if (info.signedness == .unsigned) {
                return dest | (source & ~switch (info.bits) {
                    8 => 0xFF,
                    16 => 0xFFFF,
                    32 => 0xFFFFFFFF,
                    else => @compileError("Expected to overwrite u8,u16,u32!"),
                });
            } else {
                @compileError("Expected to overwrite u8,u16,u32!");
            }
        },
        else => @compileError("Expected to overwrite u8,u16,u32!"),
    }
}

// Instruction encodings
const Instr = packed struct {
    rest: u12, // The rest of the instruction encoding
    line: u4, // Instruction "line" (somewhat of a grouping for m68k isntructions)

    const Line0 = packed struct {
        xn: u3,
        addr_mode: AddrMode,
        size: u2,
        is_movep_or_bitmanip: bool,
        dn: u3,

        fn from_instr(instr: Instr) Line0 {
            return @bitCast(instr.rest);
        }
    };

    // Address modes
    const AddrMode = enum(u3) {
        data_reg,
        addr_reg,
        addr,
        addr_postinc,
        addr_predec,
        addr_disp,
        addr_idx,
        special,
    };

    // Special address modes relating to last addr_mode
    const AddrModeSpecial = enum(u3) {
        abs_short,
        abs_long,
        pc_disp,
        pc_idx,
        imm,
        _,
    };

    // Brief extension word used in index addressing modes
    const ExtensionWord = packed struct {
        disp: i8,
        reserved: u3 = 0,
        size: u1,
        xn: u3,
        is_addr_reg: bool,
    };

    // Instruction operand sizes
    const Size = enum(u2) {
        byte,
        word,
        long,

        // Decode 2 bit sequence
        fn decode2(bits: u2, allow_zero: bool) Size {
            return switch (bits) {
                0b00 => if (allow_zero) .byte else .byte,
                0b01 => if (allow_zero) .word else .byte,
                0b11 => if (allow_zero) .word else .word,
                0b10 => if (allow_zero) .long else .long,
            };
        }

        // Decode 1 bit sequence
        fn decode1(bit: u1) Size {
            return if (bit == 1) .long else .word;
        }

        // Get backing type for size
        fn backing_type(comptime self: Size) type {
            return switch (self) {
                .byte => u8,
                .word => u16,
                .long => u32,
            };
        }
    };
};

/// Normal cpu registers
const Registers = struct {
    // 16 General purpose data registers
    // First 8 are the data registers, second 8 are the address registers
    data: [8]u32,
    addr: [8]u32,
    pc: u32, // Program counter
    sr: Status, // Status register
    const sp = 7; // Stack pointer index

    const Status = packed struct {
        carry: bool,
        overflow: bool,
        zero: bool,
        negative: bool,
        extend: bool,
        reserved_ccr: u3 = 0,
        ipl: u3,
        reserved_ssr: u2 = 0,
        supervisor: bool,
        reserved_trace: u1 = 0,
        trace: bool,

        fn reset() Status {
            return .{
                .carry = false,
                .overflow = false,
                .zero = false,
                .negative = false,
                .extend = false,
                .ipl = 7,
                .supervisor = true,
                .trace = false,
            };
        }
    };

    fn reset() Registers {
        return .{
            .data = [_]u32{0} ** 8,
            .addr = [_]u32{0} ** 8,
            .pc = 0,
            .sr = Status.reset(),
        };
    }
};

/// Vector indexes
const Vector = enum(u8) {
    reset_stack_pointer,
    reset_program_counter,
    access_fault,
    address_error,
    illegal_instruction,
    integer_divide_by_zero,
    chk_chk2,
    trapv,
    privilege_violation,
    trace,
    line_a_emulator,
    line_f_emulator,
    coprocessor_protocol_violation = 13,
    format_error,
    uninitialized_interrupt,
    spurious_interrupt = 24,
    interrupt_autovectors,
    trap_vectors = 32,
    _,

    fn offset(self: Vector) u24 {
        return @intFromEnum(self) * 4;
    }
};

// Tests and example code
const testutils = struct {
    const expect = std.testing.expect;

    // Ram
    const Ram = struct {
        bytes: [4096]u8,

        fn init(reset_sp: u32, reset_pc: u32) Ram {
            var ram: Ram = undefined;
            ram.bytes = [_]u8{0} ** 4096;
            ram.write32(Vector.reset_stack_pointer.offset(), reset_sp);
            ram.write32(Vector.reset_program_counter.offset(), reset_pc);
            return ram;
        }

        fn bus(self: *Ram) Bus {
            return .{
                .ptr = @ptrCast(self),
                .vtable = .{
                    .read8 = @ptrCast(&Ram.read8),
                    .read16 = @ptrCast(&Ram.read16),
                    .read32 = @ptrCast(&Ram.read32),
                    .write8 = @ptrCast(&Ram.write8),
                    .write16 = @ptrCast(&Ram.write16),
                    .write32 = @ptrCast(&Ram.write32),
                },
            };
        }

        fn read8(self: *const Ram, addr: u24) u8 {
            return self.bytes[addr];
        }
        fn read16(self: *const Ram, addr: u24) u16 {
            if (addr + 2 > self.bytes.len) return 0;
            return std.mem.readInt(u16, @ptrCast(self.bytes[addr..]), .big);
        }
        fn read32(self: *const Ram, addr: u24) u32 {
            if (addr + 4 > self.bytes.len) return 0;
            return std.mem.readInt(u32, @ptrCast(self.bytes[addr..]), .big);
        }
        fn write8(self: *Ram, addr: u24, val: u8) void {
            self.bytes[addr] = val;
        }
        fn write16(self: *Ram, addr: u24, val: u16) void {
            if (addr + 2 > self.bytes.len) return;
            std.mem.writeInt(u16, @ptrCast(self.bytes[addr..]), val, .big);
        }
        fn write32(self: *Ram, addr: u24, val: u32) void {
            if (addr + 4 > self.bytes.len) return;
            std.mem.writeInt(u32, @ptrCast(self.bytes[addr..]), val, .big);
        }
    };
};

test "Cpu reset" {
    var ram = testutils.Ram.init(0, 0);
    var cpu = Cpu.init(&ram.bus());
    cpu.reset();
    try testutils.expect(cpu.regs.sr.supervisor == true);
}

test "Cpu instruction ori" {
    var ram = testutils.Ram.init(0, 8);
    var cpu = Cpu.init(&ram.bus());
    cpu.reset();

    ram.write16(8, 0x0041);
    ram.write16(10, 0xAAAA);
    try cpu.execute_cycles(1);
}
