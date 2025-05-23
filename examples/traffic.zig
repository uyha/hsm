const State = hsm.State;
const Any = hsm.Any;

pub fn main() !void {
    try @"Traffic light"();
}

const Traffic = struct {
    stops: usize = 0,
    ticks: usize = 0,

    fn harshStop(count: *Traffic) void {
        std.debug.print("Harsh stop\n", .{});
        count.stops += 1;
    }
    fn softStop(count: *Traffic) void {
        std.debug.print("Soft stop\n", .{});
        count.stops += 1;
    }
    fn slowingDown() void {
        std.debug.print("Slowing Down\n", .{});
    }
    fn starting() void {
        std.debug.print("Starting to run\n", .{});
    }

    fn tick(source: *Traffic) void {
        source.ticks += 1;
    }
};

fn @"Traffic light"() !void {
    const Red = struct {};
    const Yellow = struct {};
    const Green = struct {};

    const Running = struct {};
    const Slowing = struct {};
    const Stopped = struct {};

    const Observing = struct {};

    var count: Traffic = .{};
    var sm = hsm.State(.{
        .{ .init = true, .src = Running, .event = Red, .dst = Stopped, .acts = .{Traffic.harshStop} },
        .{ .src = Running, .event = Yellow, .dst = Slowing, .acts = .{Traffic.slowingDown} },

        .{ .src = Slowing, .event = Red, .dst = Stopped, .acts = .{Traffic.softStop} },

        .{ .src = Stopped, .event = Green, .dst = Running, .acts = .{Traffic.starting} },

        .{ .init = true, .src = Observing, .event = Any, .acts = .{Traffic.tick} },
    }).create(&count);

    try sm.process(Red{});
    try sm.process(Green{});
    try sm.process(Yellow{});
    try sm.process(Red{});
    try sm.process(Green{});

    std.debug.print("Stops: {}\n", .{count.stops});
    std.debug.print("Ticks: {}\n", .{count.ticks});
}

const std = @import("std");
const hsm = @import("hsm");
