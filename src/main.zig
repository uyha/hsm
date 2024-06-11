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

pub fn hello(event: Event) void {
    std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
    std.debug.print("{}\n", .{event});
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
        .{ .initial = true, .src = u8, .event = Event, .dst = u16, .actions = .{&hello} },
        .{ .src = u16, .event = Event, .dst = u32, .actions = .{&hello1} },
        .{ .src = u32, .event = Event, .dst = u8, .actions = .{&hello2} },
    });

    for (0..10) |i| {
        sm.process(Event{ .Source = @intCast(i) });
    }

    // const Args = std.meta.ArgsTuple(@TypeOf((&hello1).*));
    // const len = @typeInfo(Args).Struct.fields.len;
    // const args: Args = if (len == 0) .{} else .{undefined} ** len;
    //
    // std.debug.print("{any}\n", .{args});
}
