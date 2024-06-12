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
pub fn hell(event: u8) void {
    std.debug.print("{s}:{} ({s}) ", .{ @src().file, @src().line, @src().fn_name });
    std.debug.print("{}\n", .{event});
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
    Source: usize,
};

pub fn main() !void {
    var sm = hsm.stateMachine(.{
        .{
            .initial = true,
            .src = u8,
            .event = Event,
            .dst = u16,
            .guards = .{sometime},
            .actions = .{hello},
        },
        .{ .src = u8, .event = Event1, .actions = .{hell} },
    }, .{@as(u8, 1)});

    sm.process(Event1{ .Source = 1 });
    //
    // for (0..10) |i| {
    //     sm.process(Event{ .Source = @intCast(i) });
    // }
}
