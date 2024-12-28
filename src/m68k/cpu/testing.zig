const std = @import("std");
const cpu = @import("cpu.zig");
const enc = @import("enc.zig");

test "Bus Impl" {
    const expect = std.testing.expect;
    
    const BusImpl = struct {
        bytes: [256]u8 = [_]u8{0} ** 256,

        fn rd8(self: *const @This(), addr: u24) u8 {
            return self.bytes[addr];
        }
        fn rd16(self: *const @This(), addr: u24) u16 {
            return std.mem.readInt(u16, self.bytes[addr..][0..2], .big);
        }
        fn rd32(self: *const @This(), addr: u24) u32 {
            return std.mem.readInt(u32, self.bytes[addr..][0..4], .big);
        }
        fn wr8(self: *@This(), addr: u24, byte: u8) void {
            self.bytes[addr] = byte;
        }
        fn wr16(self: *@This(), addr: u24, word: u16) void {
            std.mem.writeInt(u16, self.bytes[addr..][0..2], word, .big);
        }
        fn wr32(self: *@This(), addr: u24, long: u32) void {
            std.mem.writeInt(u32, self.bytes[addr..][0..4], long, .big);
        }
    };

    var impl = BusImpl{};
    var state = cpu.State.init(&impl);
    
    state.bus.wr8(4, 0xFF);
    try expect(state.bus.rd8(4) == 0xFF);
    try expect(state.bus.rd16(4) == 0xFF00);
}
