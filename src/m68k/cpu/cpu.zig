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

    // Tries to handle pending exceptions if there are any
    pub fn tryPendingException(self: *State) void {
        const exception = self.pending_exception orelse return;
        self.pending_exception = null;
        self.handleException(exception);
    }
    
    // Returns whether or not the cpu has privilages, and executes trap if not
    pub fn checkPrivlege(self: *State, need_privileges: bool) bool {
        if (!need_privileges or self.regs.sr.s) return true;
        self.handleException(@intFromEnum(Vector.privilege_violation));
        return false;
    }

    pub fn trapException(self: *State, vector: u4) void {
        self.regs.sr.s = true;
        self.pushVal(enc.Size.long, self.regs.pc);
        self.pushVal(enc.Size.word, @bitCast(self.regs.sr));
        const exception = @intFromEnum(Vector.trap_vectors) + vector;
        self.regs.pc = self.rdBus(enc.Size.long, exception * 4);
        self.ir = self.programFetch(enc.Size.word);
    }
    
    // Starts exception handler code for the exception
    pub fn handleException(self: *State, exception: u8) void {
        const sr_copy = self.regs.sr;
        self.regs.sr.s = true;
        self.regs.sr.t = false;
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
            .chk_instr, .zero_divide, .privilege_violation => |vec| {
                self.pushVal(enc.Size.long, self.regs.pc -% 2);
                self.pushVal(enc.Size.word, @bitCast(sr_copy));
                self.regs.pc = self.rdBus(enc.Size.long, vec.getAddr());
                self.ir = self.programFetch(enc.Size.word);
            },
            else => {},
        }
    }

    // Load a register while truncating result to desired size
    pub inline fn loadReg(self: *State, comptime ty: Regs.GpType, comptime sz: enc.Size, reg: u3) sz.getType(.unsigned) {
        const reg_data = switch (ty) {
            .data => self.regs.d[reg],
            .addr => self.regs.a[reg],
        };
        return @truncate(reg_data);
    }

    // Overwrites register
    pub inline fn storeReg(self: *State, comptime ty: Regs.GpType, comptime sz: enc.Size, reg: u3, data: sz.getType(.unsigned)) void {
        const mask: u32 = std.math.maxInt(sz.getType(.unsigned));
        switch (ty) {
            .data => {
                self.regs.d[reg] &= ~mask;
                self.regs.d[reg] |= data;
            },
            .addr => {
                self.regs.a[reg] &= ~mask;
                self.regs.a[reg] |= data;
            },
        }
    }

    // Push value onto program stack
    pub fn pushVal(self: *State, comptime sz: enc.Size, data: sz.getType(.unsigned)) void {
        self.regs.a[Regs.sp] -= switch (sz) {
            .byte, .word => 2,
            .long => 4,
        };
        self.wrBus(sz, self.regs.a[Regs.sp], data);
    }

    // Pop value from program stack
    pub fn popVal(self: *State, comptime sz: enc.Size) sz.getType(.unsigned) {
        const val = self.rdBus(sz, self.regs.a[Regs.sp]);
        self.regs.a[Regs.sp] += switch (sz) {
            .byte, .word => 2,
            .long => 4,
        };
        return val;
    }

    pub fn setNegAndZeroFlags(self: *State, comptime sz: enc.Size, val: sz.getType(.unsigned)) void {
        self.regs.sr.z = val == 0;
        self.regs.sr.n = @as(sz.getType(.signed), @bitCast(val)) < 0;
    }

    // Set flags for normal arithmatic operations
    pub fn addWithFlags(
        self: *State,
        comptime sz: enc.Size,
        lhs: sz.getType(.unsigned),
        rhs: sz.getType(.unsigned),
    ) sz.getType(.unsigned) {
        const S = sz.getType(.signed);
        const res = lhs +% rhs;
        self.regs.sr.c = @addWithOverflow(lhs, rhs)[1] != 0;
        self.regs.sr.v = @addWithOverflow(@as(S, @bitCast(lhs)), @as(S, @bitCast(rhs)))[1] != 0;
        self.setNegAndZeroFlags(sz, res);
        return res;
    }

    // Set flags for normal arithmatic operations
    pub fn subWithFlags(
        self: *State,
        comptime sz: enc.Size,
        lhs: sz.getType(.unsigned),
        rhs: sz.getType(.unsigned),
    ) sz.getType(.unsigned) {
        const S = sz.getType(.signed);
        const res = lhs -% rhs;
        self.regs.sr.c = @subWithOverflow(lhs, rhs)[1] != 0;
        self.regs.sr.v = @subWithOverflow(@as(S, @bitCast(lhs)), @as(S, @bitCast(rhs)))[1] != 0;
        self.setNegAndZeroFlags(sz, res);
        return res;
    }

    // Set logical bit operation flags
    pub inline fn setLogicalFlags(self: *State, comptime sz: enc.Size, val: sz.getType(.unsigned)) void {
        self.regs.sr.c = false;
        self.regs.sr.v = false;
        self.regs.sr.z = val == 0;
        self.regs.sr.n = checkMsb(val);
    }

    // Shift integer and set flags
    // Does variable cycle calculation (aka 2m)
    pub fn shiftWithFlags(self: *State, comptime sz: enc.Size, comptime mode: enc.ShiftOp, dir: enc.ShiftDir, data: sz.getType(.unsigned), shift: u6) sz.getType(.unsigned) {
        switch (mode) {
            .shift_arith, .shift_logic => {},
            else => @compileError("Can only use shift mode in shiftWithFlags"),
        }
        const S = sz.getType(.signed);
        var x = data;
        self.regs.sr.c = false;
        self.regs.sr.v = false;
        switch (dir) {
            .left => {
                for (0..shift) |_| {
                    const old_msb = checkMsb(x);
                    self.cycles += 2;
                    x <<= 1;
                    const new_msb = checkMsb(x);
                    self.regs.sr.c = old_msb;
                    self.regs.sr.x = old_msb;
                    if (mode == .shift_arith) {
                        self.regs.sr.v = self.regs.sr.v or (old_msb != new_msb);
                    }
                }
            },
            .right => {
                for (0..shift) |_| {
                    const old_lsb = (x & 1) != 0;
                    self.cycles += 2;
                    if (mode == .shift_arith) {
                        x = @bitCast(@as(S, @bitCast(x)) >> 1);
                    } else {
                        x >>= 1;
                    }
                    self.regs.sr.c = old_lsb;
                    self.regs.sr.x = old_lsb;
                }
            },
        }
        self.setNegAndZeroFlags(sz, x);
        return x;
    }

    // Rotate integer and set flags
    // Does variable cycle calculation (aka 2m)
    pub fn rotateWithFlags(self: *State, comptime sz: enc.Size, comptime mode: enc.ShiftOp, dir: enc.ShiftDir, data: sz.getType(.unsigned), shift: u6) sz.getType(.unsigned) {
        switch (mode) {
            .rotate, .rotate_extended => {},
            else => @compileError("Can only use rotate modes in rotateWithFlags"),
        }
        var x = data;
        self.regs.sr.c = false;
        self.regs.sr.v = false;
        switch (dir) {
            .left => {
                for (0..shift) |_| {
                    const msb = checkMsb(x);
                    self.regs.sr.c = msb;
                    if (mode == .rotate_extended) self.regs.sr.x = msb;
                    self.cycles += 2;
                    x <<= 1;
                    x |= @intFromBool(msb);
                }
            },
            .right => {
                for (0..shift) |_| {
                    const lsb = x & 1 != 0;
                    self.regs.sr.c = lsb;
                    if (mode == .rotate_extended) self.regs.sr.x = lsb;
                    self.cycles += 2;
                    x >>= 1;
                    if (lsb) x |= 1 << @bitSizeOf(@TypeOf(x)) - 1;
                }
            },
        }
        if (mode == .rotate_extended and shift == 0) self.regs.sr.c = self.regs.sr.x;
        self.setNegAndZeroFlags(sz, x);
        return x;
    }

    // Setup a bit operation with flags. Returns addressing mode used
    pub fn bitOpWithFlags(
        self: *State,
        ea: enc.EffAddr,
        bit_idx: u32,
        comptime write_back: bool,
        op: fn (dst: u32, mask: u32) u32,
    ) enc.AddrMode {
        if (ea.m == comptime enc.AddrMode.toEffAddr(.data_reg).m) {
            // Long (aka work on data register)
            const idx: u5 = @truncate(bit_idx);
            const mask = @as(u32, 1) << idx;
            const dst = self.regs.d[ea.xn];
            self.regs.sr.z = dst & mask == 0;
            if (write_back) self.regs.d[ea.xn] = op(dst, mask);
            return enc.AddrMode.data_reg;
        } else {
            // Byte (aka work on memory)
            const mask = @as(u8, 1) << @as(u3, @truncate(bit_idx));
            const dst_ea = EffAddr(enc.Size.byte).calc(self, ea);
            const dst = dst_ea.load(self);
            self.regs.sr.z = dst & mask == 0;
            if (write_back) dst_ea.store(self, @truncate(op(dst, mask)));
            return enc.AddrMode.fromEffAddr(ea).?;
        }
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

// Sign extends a type to full u32
pub fn extendFull(comptime sz: enc.Size, data: sz.getType(.unsigned)) u32 {
    const extended: i32 = @as(sz.getType(.signed), @bitCast(data));
    return @bitCast(extended);
}

// Gets most significant bit
pub fn checkMsb(int: anytype) bool {
    const Type = @TypeOf(int);
    const info = @typeInfo(Type).Int;
    return (int >> (info.bits - 1)) != 0;
}

/// Helper struct to represent binary coded decimal bytes
pub const Bcd = packed struct {
    ones: u4,
    tens: u4,

    // Converts the BCD coded number to binary
    pub fn toBinary(self: Bcd) u8 {
        return @as(u8, self.tens) * 10 + self.ones;
    }

    // Returns whether or not the number overflowed in the other bit
    // It will always return a truncated value
    pub fn fromBinary(binary: anytype) struct { Bcd, bool } {
        const truncated = binary % 100;
        return .{
            .{
                .ones = @truncate(truncated % 10),
                .tens = @truncate(truncated / 10),
            },
            truncated != binary,
        };
    }

    // Adds two bcd coded numbers, truncates them and returns the result and if they overflowed
    pub fn add(lhs: Bcd, rhs: Bcd, extend: u1) struct { Bcd, bool } {
        const l: u16 = toBinary(lhs);
        const r: u16 = toBinary(rhs);
        return fromBinary(l + r + extend);
    }

    // Subtracts two bcd coded numbers
    pub fn sub(lhs: Bcd, rhs: Bcd, extend: u1) struct { Bcd, bool } {
        const l: u16 = toBinary(lhs);
        const r: u16 = toBinary(rhs) + extend;

        if (l < r) {
            const diff = (r - l) % 100;
            const res = 100 - diff;
            return .{ .{
                .ones = @truncate(res % 10),
                .tens = @truncate(res / 10),
            }, true };
        } else {
            return fromBinary(l - r);
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
                .data_reg => |reg| cpu.loadReg(.data, sz, reg),
                .addr_reg => |reg| cpu.loadReg(.addr, sz, reg),
                .mem => |addr| cpu.rdBus(sz, addr),
                .imm => |data| data,
            };
        }

        // Store data to calculated address
        pub fn store(self: Self, cpu: *State, data: Data) void {
            switch (self) {
                .data_reg => |reg| cpu.storeReg(.data, sz, reg, data),
                .addr_reg => |reg| cpu.storeReg(.addr, sz, reg, data),
                .mem => |addr| cpu.wrBus(sz, addr, data),
                .imm => unreachable,
            }
        }

        // Calculate address only (no data reading)
        pub fn calc(cpu: *State, ea: enc.EffAddr) Self {
            const mode = enc.AddrMode.fromEffAddr(ea).?;
            switch (mode) {
                .data_reg => return Self{ .data_reg = ea.xn },
                .addr_reg => return Self{ .addr_reg = ea.xn },
                .addr => return Self{ .mem = cpu.regs.a[ea.xn] },
                .addr_postinc => {
                    const addr = cpu.regs.a[ea.xn];
                    cpu.regs.a[ea.xn] +%= @sizeOf(Data);
                    return Self{ .mem = addr };
                },
                .addr_predec => {
                    cpu.cycles += 2;
                    cpu.regs.a[ea.xn] -%= @sizeOf(Data);
                    return Self{ .mem = cpu.regs.a[ea.xn] };
                },
                .addr_disp, .pc_disp => {
                    const base = if (mode == .pc_disp) cpu.regs.pc else cpu.regs.a[ea.xn];
                    const disp: i16 = @bitCast(cpu.programFetch(enc.Size.word));
                    return Self{ .mem = base +% @as(u32, @bitCast(@as(i32, disp))) };
                },
                .addr_idx, .pc_idx => {
                    cpu.cycles += 2;
                    const ext: enc.BriefExtWord = @bitCast(cpu.programFetch(enc.Size.word));
                    const idx: i32 = calc_idx: {
                        const reg = if (ext.mode == 1) cpu.regs.a[ext.reg] else cpu.regs.d[ext.reg];
                        const trunc: u16 = @truncate(reg);
                        break :calc_idx @as(i16, @bitCast(trunc));
                    };
                    var addr = if (mode == .pc_disp) cpu.regs.pc else cpu.regs.a[ea.xn];
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
        const ConstPtr = *const Impl;

        // Instead of unsafely casting the pointers to the impl's functions, I create these buffer
        // functions that only cast the context pointer to be more type safe.
        const funcs = struct {
            fn rd8(ctx: *const anyopaque, addr: u24) u8 {
                const bus: ConstPtr = @ptrCast(@alignCast(ctx));
                return Impl.rd8(bus, addr);
            }
            fn rd16(ctx: *const anyopaque, addr: u24) u16 {
                const bus: ConstPtr = @ptrCast(@alignCast(ctx));
                return Impl.rd16(bus, addr);
            }
            fn rd32(ctx: *const anyopaque, addr: u24) u32 {
                const bus: ConstPtr = @ptrCast(@alignCast(ctx));
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
    pub inline fn rd8(self: *const Bus, addr: u24) u8 {
        return self.rd8fn(self.ctx, addr);
    }
    pub inline fn rd16(self: *const Bus, addr: u24) u16 {
        return self.rd16fn(self.ctx, addr);
    }
    pub inline fn rd32(self: *const Bus, addr: u24) u32 {
        return self.rd32fn(self.ctx, addr);
    }
    pub inline fn wr8(self: *Bus, addr: u24, byte: u8) void {
        self.wr8fn(self.ctx, addr, byte);
    }
    pub inline fn wr16(self: *Bus, addr: u24, word: u16) void {
        self.wr16fn(self.ctx, addr, word);
    }
    pub inline fn wr32(self: *Bus, addr: u24, long: u32) void {
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

    // Status register representation. Reset state is defaults for struct.
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

        pub fn satisfiesCond(self: Status, cond: enc.Cond) bool {
            const n = @intFromBool(self.n);
            const v = @intFromBool(self.v);
            return switch (cond) {
                .true => true,
                .false => false,
                .higher => !self.z and !self.c,
                .lower_or_same => self.z or self.c,
                .carry_clear => !self.c,
                .carry_set => self.c,
                .not_equal => !self.z,
                .equal => self.z,
                .overflow_clear => !self.v,
                .overflow_set => self.v,
                .plus => !self.n,
                .minus => self.n,
                .greater_or_equal => n ^ v == 0,
                .less_than => n ^ v != 0,
                .greater_than => !self.z and n ^ v == 0,
                .less_or_equal => self.z or n ^ v != 0,
            };
        }
    };

    // General Purpose register kind
    pub const GpType = enum {
        data,
        addr,

        pub fn fromAddrMode(md: enc.AddrMode) ?GpType {
            return switch (md) {
                .data_reg => GpType.data,
                .addr_reg => GpType.addr,
                else => null,
            };
        }
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

    pub fn getAddr(self: Vector) u24 {
        return @intFromEnum(self) * 4;
    }
};
