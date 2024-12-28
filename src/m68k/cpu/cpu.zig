const std = @import("std");
const enc = @import("enc.zig");

/// Holds internal processor state
pub const State = struct {
    bus: Bus, // Bus interface
    regs: Regs, // Normal registers
    ir: u16, // Internal instruction opcode register
    cycles: u64, // Number of cycles the cpu has been emulating

    /// bus_impl should be a pointer to a bus implementation see Bus type for more details
    pub fn init(bus_impl: anytype) State {
        return .{
            .bus = Bus.init(bus_impl),
            .regs = Regs.init(),
            .ir = 0,
            .cycles = 0,
        };
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
                .data_reg => |reg| @truncate(cpu.regs.gp[reg]),
                .addr_reg => |reg| @truncate(cpu.regs.gp[8 + reg]),
                .mem => |addr| cpu.rdBus(sz, addr),
                .imm => |data| data,
            };
        }
        
        // Store data to calculated address
        pub fn store(self: Self, cpu: *State, data: Data) void {
            switch (self) {
                .data_reg => |reg| {
                    const mask: u32 = std.math.maxInt(Data);
                    cpu.regs.gp[reg] &= ~mask;
                    cpu.regs.gp[reg] |= data;
                },
                .addr_reg => |reg| {
                    const extended: i32 = @as(sz.getType(.signed), data);
                    cpu.regs.gp[8 + reg] = @bitCast(extended);
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
                .addr => return Self{ .mem = cpu.regs.gp[8 + xn] },
                .addr_postinc => {
                    const addr = cpu.regs.gp[8 + xn];
                    cpu.regs.gp[8 + xn] += @sizeOf(Data);
                    return Self{ .mem = addr };
                },
                .addr_predec => {
                    cpu.cycles += 2;
                    cpu.regs.gp[8 + xn] -= @sizeOf(Data);
                    return Self{ .mem = cpu.regs.gp[8 + xn] };
                },
                .addr_disp, .pc_disp => {
                    const base = if (mode == .pc_disp) cpu.regs.pc else cpu.regs.gp[8 + xn];
                    const disp: i16 = @bitCast(cpu.programFetch(enc.Size.word));
                    return Self{ .mem = base +% @as(u32, @bitCast(@as(i32, disp))) };
                },
                .addr_idx, .pc_idx => {
                    const ext: enc.BriefExtWord = @bitCast(cpu.programFetch(enc.Size.word));
                    const idx: i32 = calc_idx: {
                        const reg: u16 = @truncate(cpu.regs.gp[@as(u4, ext.mode) * 8 + ext.reg]);
                        break :calc_idx @as(i16, @bitCast(reg));
                    };
                    var addr = if (mode == .pc_disp) cpu.regs.pc else cpu.regs.gp[8 + xn];
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
    gp: [16]u32, // General purpose registers (data first, then address registers)
    pc: u32, // Program counter register
    sr: Status, // Status register

    pub const Status = packed struct {
        c: bool = false, // Carry
        v: bool = false, // Overflow
        z: bool = false, // Zero
        n: bool = false, // Negative
        e: bool = false, // Extend
        reserved_ccr: u3 = 0,
        ipl: u3 = 7, // Interrupt priority level
        reserved_sr: u2 = 0,
        s: bool = true, // Supervisor level
        reserved_trace: u1 = 0,
        t: bool = false, // Trace mode enable
    };
    
    pub fn init() Regs {
        return .{
            .gp = [_]u32{0} ** 16,
            .pc = 0,
            .sr = Status{},
        };
    }
};
