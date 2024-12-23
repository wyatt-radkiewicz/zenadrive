ptr: *anyopaque,
fns: Fns,

const Self = @This();
pub const Fns = struct {
    rd: fn ()
};

pub fn init(bus: *anyopaque) Self {
    
}
