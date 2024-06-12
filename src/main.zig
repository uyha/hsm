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
pub fn sometime(event: Event) bool {
    return event.Source % 2 == 0;
}

pub fn hello(event: Event) void {
    std.debug.print("{s}:{} ({s}) ", .{ @src().file, @src().line, @src().fn_name });
    std.debug.print("{}\n", .{event});
}
pub fn hell(event: Event1, counter: *u8) void {
    std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
    counter.* += event.Source;
}
pub fn hello1() void {
    std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
}
pub fn hello2() void {
    std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
}

const Event = struct {
    Source: usize,
};
const Event1 = struct {
    Source: u8,
};

pub fn main() !void {
    var counter: u8 = 0;
    var sm = hsm.stateMachine(.{
        .{
            .initial = true,
            .src = u8,
            .event = Event,
            .actions = .{hello},
        },
        .{ .src = u8, .event = Event1, .actions = .{hell} },
    }, .{&counter});

    sm.process(Event1{ .Source = 1 });
    sm.process(Event{ .Source = 1 });
    sm.process(Event1{ .Source = 1 });
    sm.process(Event{ .Source = 1 });

    std.debug.print("{}\n", .{counter});
    //
    // for (0..10) |i| {
    //     sm.process(Event{ .Source = @intCast(i) });
    // }
}
