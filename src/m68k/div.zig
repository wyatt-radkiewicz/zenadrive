const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    rhs: enc.EffAddr,
    pattern: enc.BitPattern(2, 0b11),
    is_signed: bool,
    lhs: u3,
    line: enc.BitPattern(4, 0b1000),
};
pub const Variant = packed struct {
    is_signed: bool,
};
pub const Tester = struct {
    const expect = std.testing.expect;
    
    // 0:	0640 02d7      	addiw #727,%d0 ; 8
    // 4:	0641 0016      	addiw #22,%d1  ; 8 
    // 8:	80c1           	divuw %d1,%d0  ; 76 cycles minimum
    pub const code = [_]u16{
        0x0640, 0x02D7,
        0x0641, 0x0016,
        0x80C1,
    };
    pub fn validate(state: *const cpu.State) !void {
        try expect(state.cycles >= 16+76);
        try expect(state.regs.d[0] & 0xFFFF == 33);
        try expect(state.regs.d[0] >> 16 == 1);
    }
};

pub fn getImmLen(encoding: Encoding) usize {
    return enc.AddrMode.fromEffAddr(encoding.rhs).?.getAdditionalSize(enc.Size.word);
}
pub fn match(comptime encoding: Encoding) bool {
    return enc.AddrMode.fromEffAddr(encoding.rhs).? != .addr_reg;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    const Word = if (args.is_signed) i16 else u16;
    const Long = if (args.is_signed) i32 else u32;
    const instr: Encoding = @bitCast(state.ir);
    const rhs: Long = @as(Word, @bitCast(cpu.EffAddr(enc.Size.word).calc(state, instr.rhs).load(state)));
    const lhs: Long = @bitCast(state.regs.d[instr.lhs]);
    
    // Do initial stuff that happens no matter what
    state.regs.sr.c = false;
    state.cycles += 4;
    
    // Divide by zero occurred
    if (rhs == 0) {
        state.cycles += 4;
        state.handleException(@intFromEnum(cpu.Vector.zero_divide));
        return;
    }
    
    // Do division
    if (args.is_signed) {
        state.cycles += 8;
        if (lhs < 0) state.cycles += 2;
    } else {
        state.cycles += 2;
    }
    const quo = @divTrunc(lhs, rhs);
    const rem = @rem(lhs, rhs);
    
    // Check for overflow
    if (quo > std.math.maxInt(Word) or quo < std.math.minInt(Word)) {
        state.regs.sr.v = true;
        state.ir = state.programFetch(enc.Size.word);
        return;
    }
    
    // Set flags and update registers
    state.regs.sr.v = false;
    state.regs.sr.z = quo == 0;
    state.regs.sr.n = quo < 0;
    state.regs.d[instr.lhs] = @as(u32, @bitCast(quo)) & 0xFFFF | @as(u32, @bitCast(rem)) << 16;
    
    // Simulate cycle timings
    if (args.is_signed) {
        var cycle_quo: u32 = @bitCast(quo);
        for (0..16) |_| {
            state.cycles += 8;
            if (cpu.checkMsb(cycle_quo)) state.cycles -= 1;
            cycle_quo <<= 1;
        }
        state.cycles += 4;
        if (rhs < 0) {
            state.cycles += 4;
        } else {
            state.cycles += 2;
            if (lhs < 0) state.cycles += 4;
        }
    } else {
        var dividend: u32 = @bitCast(lhs);
        const divisor: u32 = @bitCast(rhs);
        var pmsb = false;
        var msb = cpu.checkMsb(dividend);
        for (0..16) |_| {
            state.cycles += 4;
            if (!pmsb) {
                state.cycles += 2;
                if (msb) state.cycles += 2;
            }
            
            dividend <<= 1;
            const res = @subWithOverflow(dividend >> 16, divisor);
            if (res[1] == 0) {
                dividend &= 0x0000FFFF;
                dividend |= res[0] << 16;
            }
            pmsb = msb;
            msb = cpu.checkMsb(dividend);
        }
        state.cycles += 6;
    }
    state.ir = state.programFetch(enc.Size.word);
}
