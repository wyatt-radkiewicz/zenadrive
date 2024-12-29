const std = @import("std");
const enc = @import("enc.zig");

/// Holds internal processor state
pub const State = struct {
    bus: Bus, // Bus interface
    regs: Regs, // Normal registers
    ir: u16, // Internal instruction opcode register
    cycles: u64, // Number of cycles the cpu has been emulating
    pending_exception: ?u8, // What exception to run next if we need to
    halted: bool, // Can the cpu execute instructions?

    /// bus_impl should be a pointer to a bus implementation see Bus type for more details
    pub fn init(bus_impl: anytype) State {
        return .{
            .bus = Bus.init(bus_impl),
            .regs = Regs.init(),
            .ir = 0,
            .cycles = 0,
            .pending_exception = null,
            .halted = true,
        };
    }

    pub fn handleException(self: *State) void {
        const exception = self.pending_exception orelse return;
        self.pending_exception = null;
        switch (std.meta.intToEnum(Vector, exception) catch {
            return;
        }) {
            .reset => {
                self.halted = false;
                self.regs = Regs.init();
                self.regs.a[Regs.sp] = self.rdBus(enc.Size.long, 0);
                self.regs.pc = self.rdBus(enc.Size.long, 4);
                self.ir = self.programFetch(enc.Size.word);
            },
            .illegal_instr => {
                self.halted = true;
            },
            else => {},
        }
    }
    
    // Set flags for normal arithmatic operations
    pub fn setArithFlags(self: *State, comptime sz: enc.Size, add: AddFlags(sz)) void {
        self.regs.sr.c = add.carry;
        self.regs.sr.v = add.overflow;
        self.regs.sr.z = add.val == 0;
        self.regs.sr.z = @as(sz.getType(.signed), @bitCast(add.val)) < 0;
        self.regs.sr.x = add.carry;
    }

    pub fn programFetch(self: *State, comptime sz: enc.Size) sz.getType(.unsigned) {
        switch (sz) {
            .byte, .word => {
                const word = self.rdBus(enc.Size.word, self.regs.pc);
                self.regs.pc += 2;
                return @truncate(word);
            },
            .long => {
                const long = self.rdBus(enc.Size.long, self.regs.pc);
                self.regs.pc += 4;
                return long;
            },
        }
    }

    pub fn rdBus(self: *State, comptime sz: enc.Size, fulladdr: u32) sz.getType(.unsigned) {
        const addr: u24 = @truncate(fulladdr);
        self.cycles += switch (sz) {
            .byte, .word => 4,
            .long => 8,
        };
        return switch (sz) {
            .byte => self.bus.rd8(addr),
            .word => self.bus.rd16(addr),
            .long => self.bus.rd32(addr),
        };
    }

    pub fn wrBus(self: *State, comptime sz: enc.Size, fulladdr: u32, data: sz.getType(.unsigned)) void {
        const addr: u24 = @truncate(fulladdr);
        self.cycles += switch (sz) {
            .byte, .word => 4,
            .long => 8,
        };
        switch (sz) {
            .byte => self.bus.wr8(addr, data),
            .word => self.bus.wr16(addr, data),
            .long => self.bus.wr32(addr, data),
        }
    }
};

/// Helper functions for overflow/carry etc
pub fn AddFlags(comptime sz: enc.Size) type {
    const Data = sz.getType(.unsigned);
    return struct {
        val: Data,
        carry: bool,
        overflow: bool,
        
        pub fn add(lhs: Data, rhs: Data) @This() {
            const S = sz.getType(.signed);
            
            return .{
                .val = lhs +% rhs,
                .carry = @addWithOverflow(lhs, rhs)[1] != 0,
                .overflow = @addWithOverflow(@as(S, @bitCast(lhs)), @as(S, @bitCast(rhs)))[1] != 0,
            };
        }
    };
}

/// Helper struct to represent binary coded decimal bytes
pub const Bcd = packed struct {
    ones: u4,
    tens: u4,

    pub fn add(lhs: Bcd, rhs: Bcd) struct { Bcd, u1 } {
        var carried: u1 = 0;
        var out = lhs;
        var ones: u32 = out.ones + rhs.ones;
        var tens: u32 = out.tens + rhs.tens;

        if (ones > 9) {
            ones %= 10;
            carried = 1;
        }
        out.ones = @truncate(ones);

        if (tens > 9) {
            tens %= 10;
            carried = 1;
        }
        out.tens = @truncate(tens);
        return .{ out, carried };
    }
};

/// Helper function used to calculate effective addresses
pub fn EffAddr(comptime sz: enc.Size) type {
    const Data = sz.getType(.unsigned);

    return union(enum) {
        data_reg: u3,
        addr_reg: u3,
        mem: u32,
        imm: Data,

        const Self = @This();

        // Load data from calculated address
        pub fn load(self: Self, cpu: *State) Data {
            return switch (self) {
                .data_reg => |reg| @truncate(cpu.regs.d[reg]),
                .addr_reg => |reg| @truncate(cpu.regs.a[reg]),
                .mem => |addr| cpu.rdBus(sz, addr),
                .imm => |data| data,
            };
        }

        // Store data to calculated address
        pub fn store(self: Self, cpu: *State, data: Data) void {
            switch (self) {
                .data_reg => |reg| {
                    const mask: u32 = std.math.maxInt(Data);
                    cpu.regs.d[reg] &= ~mask;
                    cpu.regs.d[reg] |= data;
                },
                .addr_reg => |reg| {
                    const extended: i32 = @as(sz.getType(.signed), @bitCast(data));
                    cpu.regs.a[reg] = @bitCast(extended);
                },
                .mem => |addr| cpu.wrBus(sz, addr, data),
                .imm => unreachable,
            }
        }

        // Calculate address only (no data reading)
        pub fn calc(cpu: *State, m: u3, xn: u3) Self {
            const mode = enc.AddrMode.fromModeBits(m, xn) orelse unreachable;
            switch (mode) {
                .data_reg => return Self{ .data_reg = xn },
                .addr_reg => return Self{ .addr_reg = xn },
                .addr => return Self{ .mem = cpu.regs.a[xn] },
                .addr_postinc => {
                    const addr = cpu.regs.a[xn];
                    cpu.regs.a[xn] += @sizeOf(Data);
                    return Self{ .mem = addr };
                },
                .addr_predec => {
                    cpu.cycles += 2;
                    cpu.regs.a[xn] -= @sizeOf(Data);
                    return Self{ .mem = cpu.regs.a[xn] };
                },
                .addr_disp, .pc_disp => {
                    const base = if (mode == .pc_disp) cpu.regs.pc else cpu.regs.a[xn];
                    const disp: i16 = @bitCast(cpu.programFetch(enc.Size.word));
                    return Self{ .mem = base +% @as(u32, @bitCast(@as(i32, disp))) };
                },
                .addr_idx, .pc_idx => {
                    const ext: enc.BriefExtWord = @bitCast(cpu.programFetch(enc.Size.word));
                    const idx: i32 = calc_idx: {
                        const reg = if (ext.mode == 1) cpu.regs.a[ext.reg] else cpu.regs.d[ext.reg];
                        const trunc: u16 = @truncate(reg);
                        break :calc_idx @as(i16, @bitCast(trunc));
                    };
                    var addr = if (mode == .pc_disp) cpu.regs.pc else cpu.regs.a[xn];
                    addr +%= @bitCast(@as(i32, ext.disp));
                    addr +%= @bitCast(idx);
                    return Self{ .mem = addr };
                },
                .abs_word => {
                    const addr: i32 = @as(i16, @bitCast(cpu.programFetch(enc.Size.word)));
                    return Self{ .mem = @bitCast(addr) };
                },
                .abs_long => return Self{ .mem = cpu.programFetch(enc.Size.long) },
                .imm => return Self{ .imm = cpu.programFetch(sz) },
            }
        }
    };
}

/// Cpu bus interface
pub const Bus = struct {
    ctx: *anyopaque, // Interface implementor instance
    rd8fn: *const fn (ctx: *anyopaque, addr: u24) u8,
    rd16fn: *const fn (ctx: *anyopaque, addr: u24) u16,
    rd32fn: *const fn (ctx: *anyopaque, addr: u24) u32,
    wr8fn: *const fn (ctx: *anyopaque, addr: u24, byte: u8) void,
    wr16fn: *const fn (ctx: *anyopaque, addr: u24, word: u16) void,
    wr32fn: *const fn (ctx: *anyopaque, addr: u24, long: u32) void,

    // Pass in a pointer to the implementor, it will try to get the functions above out of the
    // implementors struct as member functions
    pub fn init(impl: anytype) Bus {
        const Ptr = @TypeOf(impl);
        const Impl = std.meta.Child(Ptr);

        // Instead of unsafely casting the pointers to the impl's functions, I create these buffer
        // functions that only cast the context pointer to be more type safe.
        const funcs = struct {
            fn rd8(ctx: *anyopaque, addr: u24) u8 {
                const bus: Ptr = @ptrCast(@alignCast(ctx));
                return Impl.rd8(bus, addr);
            }
            fn rd16(ctx: *anyopaque, addr: u24) u16 {
                const bus: Ptr = @ptrCast(@alignCast(ctx));
                return Impl.rd16(bus, addr);
            }
            fn rd32(ctx: *anyopaque, addr: u24) u32 {
                const bus: Ptr = @ptrCast(@alignCast(ctx));
                return Impl.rd32(bus, addr);
            }
            fn wr8(ctx: *anyopaque, addr: u24, byte: u8) void {
                const bus: Ptr = @ptrCast(@alignCast(ctx));
                Impl.wr8(bus, addr, byte);
            }
            fn wr16(ctx: *anyopaque, addr: u24, word: u16) void {
                const bus: Ptr = @ptrCast(@alignCast(ctx));
                Impl.wr16(bus, addr, word);
            }
            fn wr32(ctx: *anyopaque, addr: u24, long: u32) void {
                const bus: Ptr = @ptrCast(@alignCast(ctx));
                Impl.wr32(bus, addr, long);
            }
        };

        return .{
            .ctx = impl,
            .rd8fn = &funcs.rd8,
            .rd16fn = &funcs.rd16,
            .rd32fn = &funcs.rd32,
            .wr8fn = &funcs.wr8,
            .wr16fn = &funcs.wr16,
            .wr32fn = &funcs.wr32,
        };
    }

    // Helper functions so you don't have to pass the context pointer every time
    fn rd8(self: *const Bus, addr: u24) u8 {
        return self.rd8fn(self.ctx, addr);
    }
    fn rd16(self: *const Bus, addr: u24) u16 {
        return self.rd16fn(self.ctx, addr);
    }
    fn rd32(self: *const Bus, addr: u24) u32 {
        return self.rd32fn(self.ctx, addr);
    }
    fn wr8(self: *const Bus, addr: u24, byte: u8) void {
        self.wr8fn(self.ctx, addr, byte);
    }
    fn wr16(self: *const Bus, addr: u24, word: u16) void {
        self.wr16fn(self.ctx, addr, word);
    }
    fn wr32(self: *const Bus, addr: u24, long: u32) void {
        self.wr32fn(self.ctx, addr, long);
    }
};

/// Cpu registers
pub const Regs = struct {
    d: [8]u32, // Data registers
    a: [8]u32, // Address registers
    pc: u32, // Program counter register
    sr: Status, // Status register

    // Stack pointer register
    pub const sp = 7;

    pub const Status = packed struct {
        c: bool = false, // Carry
        v: bool = false, // Overflow
        z: bool = false, // Zero
        n: bool = false, // Negative
        x: bool = false, // Extend
        reserved_ccr: u3 = 0,
        ipl: u3 = 7, // Interrupt priority level
        reserved_sr: u2 = 0,
        s: bool = true, // Supervisor level
        reserved_trace: u1 = 0,
        t: bool = false, // Trace mode enable
    };

    pub fn init() Regs {
        return .{
            .d = [1]u32{0} ** 8,
            .a = [1]u32{0} ** 8,
            .pc = 0,
            .sr = Status{},
        };
    }
};

// Interrupt vector table enum
pub const Vector = enum(u8) {
    reset,
    bus_error = 2,
    addr_error,
    illegal_instr,
    zero_divide,
    chk_instr,
    trapv_instr,
    privilege_violation,
    trace,
    line_1010_emu,
    line_1111_emu,
    uninitialized_interrupt = 15,
    spurious_interrupt = 24,
    interrupt_autovectors,
    trap_vectors,
    user_interrupts = 40,
};
