const std = @import("std");
const enc = @import("cpu/enc.zig");
const cpu = @import("cpu/cpu.zig");

pub const Encoding = packed struct {
    src: enc.EffAddr,
    pattern: enc.BitPattern(1, 0),
    size: enc.Size,
    dst: u3,
    line: enc.BitPattern(4, 0b0100),
};
pub const Variant = packed struct {
    size: enc.Size,
};
pub const Tester = struct {
    const expect = @import("std").testing.expect;
    
    // 0:	41bc fffc      	chkw #-4,d0   ; 40 ish cycles ? (should take the trap)
    pub const code = [_]u16{ 0x41BC, 0xFFFC };
    pub fn validate(state: *const cpu.State) !void {
        _ = state;
    }
};

pub fn match(comptime encoding: Encoding) bool {
    return enc.AddrMode.fromEffAddr(encoding.src).? != .addr_reg;
}
pub fn run(state: *cpu.State, comptime args: Variant) void {
    // Compute effective addresses
    const instr: Encoding = @bitCast(state.ir);
    const Signed = args.size.getType(.signed);
    const src: Signed = @bitCast(cpu.EffAddr(args.size).calc(state, instr.src).load(state));
    const dst: Signed = @bitCast(state.loadReg(.data, args.size, instr.dst));
    
    if (dst < 0 or dst > src) {
        // Do trap
        if (dst < 0) state.cycles += 4;
        state.cycles += 16;
        state.pending_exception = @intFromEnum(cpu.Vector.chk_instr);
        state.handleException();
    } else {
        // Don't trap
        state.cycles += 6;
        state.ir = state.programFetch(enc.Size.word);
    }
}