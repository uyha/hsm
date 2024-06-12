const std = @import("std");
const hsm = @import("root.zig");

const state = hsm.state;
const initial = hsm.initial;

pub fn main() !void {
    @"Traffic light"();
}

fn harshStop(count: *usize) void {
    std.debug.print("Harsh stop\n", .{});
    count.* += 1;
}
fn softStop(count: *usize) void {
    std.debug.print("Soft stop\n", .{});
    count.* += 1;
}
fn slowingDown() void {
    std.debug.print("Slowing Down\n", .{});
}
fn starting() void {
    std.debug.print("Starting to run\n", .{});
}

fn @"Traffic light"() void {
    const Red = struct {};
    const Yellow = struct {};
    const Green = struct {};

    const Running = struct {};
    const Slowing = struct {};
    const Stopped = struct {};

    var stopCount: usize = 0;
    var sm = hsm.stateMachine(.{
        .{ .initial = true, .src = Running, .event = Red, .dst = Stopped, .actions = .{harshStop} },
        .{ .src = Running, .event = Yellow, .dst = Slowing, .actions = .{slowingDown} },

        .{ .src = Slowing, .event = Red, .dst = Stopped, .actions = .{softStop} },

        .{ .src = Stopped, .event = Green, .dst = Running, .actions = .{starting} },
    }, .{&stopCount});

    sm.process(Red{});
    sm.process(Green{});
    sm.process(Yellow{});
    sm.process(Red{});
    sm.process(Green{});

    std.debug.print("Stops: {}\n", .{stopCount});
}
