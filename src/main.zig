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

const Event = struct {};

pub fn main() !void {
    var sm = hsm.stateMachine(.{
        initial(u8).with(Event).when(.{&always}).then_do(.{&hello}).then_enter(u16),
        state(u16).with(Event).when(.{&sometime}).then_do(.{&hello2}).then_enter(u8),
        state(u16).with(Event).when(.{&always}).then_do(.{&hello1}).then_enter(u8),
    });

    for (0..10) |_| {
        sm.process(Event{});
    }
}
