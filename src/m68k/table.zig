const std = @import("std");
const expect = std.testing.expect;
const instr = @import("instr.zig");

pub const InstrCycles = packed struct {
    encoding: instr.Instr,
    cycles: u8,
};

//pub const lut = compute_lut: {
//    const len = std.math.maxInt(u16) + 1;
//    var table: [len]opc.Opcode = undefined;
//    for (0..len) |idx| {
//        const opcode = opc.Opcode.decode(idx);
//        table[idx] = if (opcode.validate_word(idx)) opcode else opc.Opcode.illegal;
//    }
//    break :compute_lut table;
//};
