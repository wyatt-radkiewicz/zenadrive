const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

const Dir = enum(u1) {
    reg_to_mem,
    mem_to_reg,
};
pub const Encoding = packed struct {
    ea: enc.EffAddr,
    size: u1,
    pattern: enc.BitPattern(3, 0b001),
    dir: Dir,
    line: enc.BitPattern(5, 0b01001),
};
pub const Variant = packed struct {
    size: u1,
};
pub const Tester = struct {
    const expect = std.testing.expect;

    //    0:	4890 000f      	movemw %d0-%d3,%a0@
    pub const code = [_]u16{ 0x4890, 0x000F };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles == 8+4*4);
    }
};

pub fn getLen(encoding: Encoding) usize {
    const size = enc.Size.fromBit(encoding.size);
    return enc.AddrMode.fromEffAddr(encoding.ea).?.getAdditionalSize(size) + 2;
}
pub fn match(comptime encoding: Encoding) bool {
    return switch (enc.AddrMode.fromEffAddr(encoding.ea).?) {
        .data_reg, .addr_reg, .imm => false,
        .addr_postinc, .pc_idx, .pc_disp => encoding.dir == .reg_to_mem,
        .addr_predec => encoding.dir == .mem_to_reg,
        else => true,
    };
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    const size = comptime enc.Size.fromBit(args.size);
    const mask = state.programFetch(enc.Size.word);
    const instr: Encoding = @bitCast(state.ir);
    const mode = enc.AddrMode.fromEffAddr(instr.ea).?;
    const start = cpu.EffAddr(size).calc(state, instr.ea).mem;
    switch (instr.dir) {
        .reg_to_mem => {
            const rev = mode == .addr_predec;
            var iter = Iter.init(size, rev, start, mask);
            var curr = iter.next();
            while (curr) |i| : (curr = iter.next()) {
                const reg = if (rev) i[1] -% 15 else i[1];
                state.wrBus(size, i[0], loadReg(state, size, reg));
            }
            if (rev) state.regs.a[instr.ea.xn] = iter.addr;
        },
        .mem_to_reg => {
            var iter = Iter.init(size, false, start, mask);
            var curr = iter.next();
            while (curr) |i| : (curr = iter.next()) {
                storeReg(state, size, i[1], state.rdBus(size, i[0]));
            }
            if (mode == .addr_postinc) state.regs.a[instr.ea.xn] = iter.addr;
        },
    }
    state.ir = state.programFetch(enc.Size.word);
}

fn loadReg(state: *cpu.State, comptime size: enc.Size, idx: u4) size.getType(.unsigned) {
    if (idx < 8) {
        return state.loadReg(.data, size, @truncate(idx));
    } else {
        return state.loadReg(.addr, size, @truncate(idx - 8));
    }
}

fn storeReg(state: *cpu.State, comptime size: enc.Size, idx: u4, data: size.getType(.unsigned)) void {
    const extended = cpu.extendFull(size, data);
    if (idx < 8) {
        state.storeReg(.data, enc.Size.long, @truncate(idx), extended);
    } else {
        state.storeReg(.addr, enc.Size.long, @truncate(idx - 8), extended);
    }
}

const Iter = struct {
    bytes: i32,
    addr: u32,
    mask: u16,
    rev: bool,
    idx: u16,
    stopped: bool,
    
    fn init(comptime size: enc.Size, rev: bool, start: u32, mask: u16) Iter {
        const bytes = @sizeOf(size.getType(.unsigned));
        return .{
            .bytes = bytes,
            .addr = if (rev) start - bytes else start,
            .mask = mask,
            .rev = rev,
            .idx = 0,
            .stopped = false,
        };
    }
    
    fn next(self: *Iter) ?struct { u32, u4 } {
        const idx = self.idx;
        while (self.idx < 16 and !self.maskAt(@truncate(self.idx))) {
            self.idx += 1;
        }
        if (self.idx >= 16) {
            if (!self.stopped) {
                if (!self.rev) self.addr += @bitCast(self.bytes);
                self.stopped = true;
            }
            return null;
        }
        const addr = self.addr;
        self.idx += 1;
        self.addr +%= @bitCast(if (self.rev) -self.bytes else self.bytes);
        return .{ addr, @truncate(idx) };
    }
    
    fn maskAt(self: *Iter, idx: u4) bool {
        return self.mask & @as(u16, 1) << idx != 0;
    }
};
