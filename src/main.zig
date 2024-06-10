const std = @import("std");
const hsm = @import("root.zig");

const State1 = struct {
    pub fn process_event(event: anytype) void {
        std.debug.print("{any}\n", .{event});
    }
};

pub fn main() !void {
    const sm = hsm.StateMachine(.{State1}){};

    sm.process(1);
    sm.process(1);
}
