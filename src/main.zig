const std = @import("std");
const hsm = @import("root.zig");

const state = hsm.state;
const initial = hsm.initial;

pub fn always() bool {
    return true;
}
pub fn never() bool {
    return false;
}
pub fn sometime() bool {
    const Count = struct {
        var count: usize = 0;
    };

    Count.count += 1;

    return Count.count % 2 == 0;
}

pub fn hello() void {
    std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
}
pub fn hello1() void {
    std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
}
pub fn hello2() void {
    std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
}

const Event = struct {
    Source: u8,
};

pub fn main() !void {
    var sm = hsm.stateMachine(.{
        .{ .initial = true, .src = u8, .event = Event, .actions = .{&hello} },
    });

    for (0..10) |i| {
        sm.process(Event{ .Source = @intCast(i) });
    }
}
