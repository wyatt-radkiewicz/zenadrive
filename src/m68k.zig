const std = @import("std");

/// Bus interface for working with the emulated m68k chip
pub const Bus = struct {
    ptr: *anyopaque,
    vtable: VTable,
    
    pub const VTable = struct {
        read8: *const fn(*anyopaque, u24) u8,
        read16: *const fn(*anyopaque, u24) u16,
        read32: *const fn(*anyopaque, u24) u32,
        
        write8: *const fn(*anyopaque, u24, u8) void,
        write16: *const fn(*anyopaque, u24, u16) void,
        write32: *const fn(*anyopaque, u24, u32) void,
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
            .bus = bus,
        };
    }
    
    /// Reset cpu like the reset instruction would
    pub fn reset(self: *Cpu) void {
        self.regs = Registers.reset();
    }
    
    /// Run N number of cpu cycles (approx)
    pub fn execute(self: *Cpu, ntimes: u32) void {
        _ = self;
        _ = ntimes;
    }
};

/// Normal cpu registers
const Registers = struct {
    // 16 General purpose data registers
    // First 8 are the data registers, second 8 are the address registers
    gp: [16]u32,
    pc: u32, // Program counter
    sr: Status, // Status register
    
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
            .gp = [_]u32{0} ** 16,
            .pc = 0,
            .sr = reset,
        };
    }
};
