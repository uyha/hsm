//  {
//    state: {
//      event: [
//        {
//          guards: [predicate],
//          actions: [action],
//          destination: type
//        }
//      ]
//    }
//  }

pub fn Transitions(transitions: anytype) type {
    return struct {
        pub fn initCount() usize {
            return comptime result: {
                var result: usize = 0;

                for (transitions) |tran| {
                    if (@hasField(@TypeOf(tran), "init") and tran.init) {
                        result += 1;
                    }
                }
                break :result result;
            };
        }

        pub fn states() type {
            return comptime result: {
                var result: type = TypeList(.{});

                for (transitions) |tran| {
                    const Tran = @TypeOf(tran);
                    if (@hasField(Tran, "src") and
                        result.index(tran.src) == null)
                    {
                        result = result.append(tran.src);
                    }
                    if (@hasField(Tran, "dst") and
                        result.index(tran.dst) == null)
                    {
                        result = result.append(tran.dst);
                    }
                }

                break :result result;
            };
        }

        pub fn transitionsFromSource(source: type) type {
            return comptime result: {
                var events: type = TypeList(.{});
                // Guard action destination
                var gads: type = TypeList(.{});

                for (transitions) |tran| {
                    if (tran.src != source) {
                        continue;
                    }

                    if (events.index(tran.event)) {}
                }
            };
        }
    };
}

fn State(source: type, event: type) type {
    return struct {};
}

/// Guards actions and destination
fn Gad(guards_: anytype, actions_: anytype, destination_: type) type {
    return struct {
        pub const guards = guards_;
        pub const actions = actions_;
        pub const destination = destination_;
    };
}

fn Branch(events_: anytype, gads_: type) type {
    return struct {
        const events: type = TypeList(events_);
        const gads: type = TypeList(gads_);

        fn append(event: type, gad: type) type {
            if (events.index(event)) |index| {}
        }
    };
}

test "initCount" {
    try t.expectEqual(0, Transitions(.{}).initCount());
    try t.expectEqual(1, Transitions(.{
        .{ .init = true },
    }).initCount());
    try t.expectEqual(0, Transitions(.{
        .{ .init = false },
    }).initCount());
    try t.expectEqual(1, Transitions(.{
        .{ .init = true },
        .{ .init = false },
    }).initCount());
    try t.expectEqual(1, Transitions(.{
        .{},
        .{ .init = true },
        .{ .init = false },
    }).initCount());
    try t.expectEqual(2, Transitions(.{
        .{},
        .{ .init = true },
        .{ .init = true },
    }).initCount());
}

test "states" {
    try t.expectEqual(.{}, Transitions(.{}).states().items);
    try t.expectEqual(.{u8}, Transitions(.{
        .{ .src = u8 },
    }).states().items);
    try t.expectEqual(.{u8}, Transitions(.{
        .{ .src = u8 },
        .{ .src = u8 },
    }).states().items);
    try t.expectEqual(.{ u8, u16 }, Transitions(.{
        .{ .src = u8, .dst = u16 },
    }).states().items);
    try t.expectEqual(.{ u8, u16 }, Transitions(.{
        .{ .src = u8, .dst = u16 },
        .{ .src = u16, .dst = u8 },
    }).states().items);
    try t.expectEqual(.{ u8, u16 }, Transitions(.{
        .{ .src = u8, .dst = u16 },
        .{ .dst = u8 },
    }).states().items);
}

const std = @import("std");
const t = std.testing;

const hsm = @import("root.zig");
const TypeList = hsm.TypeList;
