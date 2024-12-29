const std = @import("std");
const cpu = @import("cpu.zig");
const enc = @import("enc.zig");

pub const Bus = struct {
    bytes: [256]u8 = [_]u8{0} ** 256,

    pub fn rd8(self: *const Bus, addr: u24) u8 {
        return self.bytes[addr];
    }
    pub fn rd16(self: *const Bus, addr: u24) u16 {
        return std.mem.readInt(u16, self.bytes[addr..][0..2], .big);
    }
    pub fn rd32(self: *const Bus, addr: u24) u32 {
        return std.mem.readInt(u32, self.bytes[addr..][0..4], .big);
    }
    pub fn wr8(self: *Bus, addr: u24, byte: u8) void {
        self.bytes[addr] = byte;
    }
    pub fn wr16(self: *Bus, addr: u24, word: u16) void {
        std.mem.writeInt(u16, self.bytes[addr..][0..2], word, .big);
    }
    pub fn wr32(self: *Bus, addr: u24, long: u32) void {
        std.mem.writeInt(u32, self.bytes[addr..][0..4], long, .big);
    }
};

test "Bus Impl" {
    const expect = std.testing.expect;
    
    var impl = Bus{};
    var state = cpu.State.init(&impl);
    
    state.wrBus(enc.Size.byte, 4, 0xFF);
    try expect(state.rdBus(enc.Size.byte, 4) == 0xFF);
    try expect(state.rdBus(enc.Size.word, 4) == 0xFF00);
}
