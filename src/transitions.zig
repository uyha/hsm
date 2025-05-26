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
