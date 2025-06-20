test "Simple State" {
    const S1 = struct {};
    const S2 = struct {};

    const TestStateMachine = StateMachine(.{
        .{ .init = true, .src = S1, .event = i32, .dst = S2 },
        .{ .src = S2, .event = i32, .dst = S1 },
    });

    var state_machine = TestStateMachine.create({});

    try t.expect(state_machine.is(S1));

    try t.expect(!try state_machine.detailedProcess(@as(i8, 1)));
    try t.expect(try state_machine.detailedProcess(@as(i32, 1)));

    try t.expect(state_machine.is(S2));
    try t.expect(try state_machine.detailedProcess(@as(i32, 1)));

    try t.expect(state_machine.is(S1));
}

test "Crossing events" {
    const S1 = struct {};
    const S2 = struct {};
    const S3 = struct {};

    const E1 = struct {};
    const E2 = struct {};
    const E3 = struct {};

    const TestStateMachine = StateMachine(.{
        .{ .init = true, .src = S1, .event = E2, .dst = S2 },
        .{ .src = S1, .event = E3, .dst = S3 },

        .{ .src = S2, .event = E1, .dst = S1 },
        .{ .src = S2, .event = E3, .dst = S3 },

        .{ .src = S3, .event = E1, .dst = S1 },
        .{ .src = S3, .event = E2, .dst = S2 },
    });

    var state_machine = TestStateMachine.create({});

    try t.expect(state_machine.is(S1));

    try t.expect(!try state_machine.detailedProcess(E1{}));
    try t.expect(try state_machine.detailedProcess(E2{}));
    try t.expect(state_machine.is(S2));

    try t.expect(!try state_machine.detailedProcess(E2{}));
    try t.expect(try state_machine.detailedProcess(E3{}));
    try t.expect(state_machine.is(S3));

    try t.expect(!try state_machine.detailedProcess(E3{}));
    try t.expect(try state_machine.detailedProcess(E2{}));
    try t.expect(state_machine.is(S2));
}

const Event = struct {
    value: u32,

    pub fn isEven(_: void, self: Event) bool {
        return @rem(self.value, 2) == 0;
    }
};

fn isEven(_: void, value: u32) bool {
    return @rem(value, 2) == 0;
}

test "Guarded transitions" {
    const S1 = struct {};
    const S2 = struct {};

    const TestStateMachine = StateMachine(.{
        .{ .init = true, .src = S1, .event = Event, .dst = S2, .guards = .{Event.isEven} },
        .{ .src = S2, .event = u32, .dst = S1, .guards = .{isEven} },
    });

    var state_machine = TestStateMachine.create({});

    try t.expect(state_machine.is(S1));

    try t.expect(!try state_machine.detailedProcess(Event{ .value = 1 }));
    try t.expect(try state_machine.detailedProcess(Event{ .value = 2 }));
    try t.expect(state_machine.is(S2));

    try t.expect(!try state_machine.detailedProcess(@as(u32, 1)));
    try t.expect(try state_machine.detailedProcess(@as(u32, 2)));
    try t.expect(state_machine.is(S1));
}

fn isMutablePointerEven(ctx: *u32) bool {
    return @rem(ctx.*, 2) == 0;
}

test "With context" {
    const S1 = struct {};
    const S2 = struct {};
    const E1 = struct {};

    const TestStateMachine = StateMachine(.{
        .{ .init = true, .src = S1, .event = E1, .dst = S2, .guards = .{isMutablePointerEven} },
        .{ .src = S2, .event = E1, .dst = S1 },
    });

    var context: u32 = 1;

    var state_machine = TestStateMachine.create(&context);

    try t.expect(state_machine.is(S1));
    try t.expect(!try state_machine.detailedProcess(E1{}));

    try t.expect(state_machine.is(S1));

    context = 2;

    try t.expect(try state_machine.detailedProcess(E1{}));
    try t.expect(state_machine.is(S2));
}

fn isConstPointerEven(value: *const u32) bool {
    return @rem(value.*, 2) == 0;
}

fn increment(value: *u32) void {
    value.* += 1;
}

test "Actions" {
    const S1 = struct {};

    const TestStateMachine = StateMachine(.{
        .{ .init = true, .src = S1, .event = bool, .acts = .{increment} },
    });

    var ctx: u32 = 0;

    var state_machine = TestStateMachine.create(&ctx);

    try t.expect(state_machine.is(S1));

    try t.expect(try state_machine.detailedProcess(true));
    try t.expectEqual(1, ctx);

    try t.expect(try state_machine.detailedProcess(false));
    try t.expectEqual(2, ctx);
}

test "Multiple regions" {
    const @"S1.1" = struct {};
    const @"S1.2" = struct {};
    const @"S2.1" = struct {};
    const @"S2.2" = struct {};
    const E1 = struct {};
    const E2 = struct {};

    const TestStateMachine = StateMachine(.{
        .{ .init = true, .src = @"S1.1", .event = E1, .dst = @"S1.2" },
        .{ .src = @"S1.2", .event = E1, .dst = @"S1.1" },
        .{ .init = true, .src = @"S2.1", .event = E2, .dst = @"S2.2" },
        .{ .src = @"S2.2", .event = E2, .dst = @"S2.1" },
    });

    var state_machine = TestStateMachine.create({});
    try t.expect(state_machine.is(@"S1.1"));
    try t.expect(state_machine.is(@"S2.1"));

    try t.expect(try state_machine.detailedProcess(E1{}));
    try t.expect(state_machine.is(@"S1.2"));
    try t.expect(state_machine.is(@"S2.1"));

    try t.expect(try state_machine.detailedProcess(E2{}));
    try t.expect(state_machine.is(@"S1.2"));
    try t.expect(state_machine.is(@"S2.2"));

    try t.expect(try state_machine.detailedProcess(E2{}));
    try t.expect(state_machine.is(@"S1.2"));
    try t.expect(state_machine.is(@"S2.1"));

    try t.expect(try state_machine.detailedProcess(E1{}));
    try t.expect(state_machine.is(@"S1.1"));
    try t.expect(state_machine.is(@"S2.1"));
}

test "Multiple regions with shared event" {
    const @"S1.1" = struct {};
    const @"S1.2" = struct {};
    const @"S2.1" = struct {};
    const @"S2.2" = struct {};
    const E1 = struct {};
    const E2 = struct {};
    const E3 = struct {};

    const TestStateMachine = StateMachine(.{
        .{ .init = true, .src = @"S1.1", .event = E1, .dst = @"S1.2" },

        .{ .src = @"S1.2", .event = E1, .dst = @"S1.1" },
        .{ .src = @"S1.2", .event = E3, .dst = @"S1.1" },

        .{ .init = true, .src = @"S2.1", .event = E2, .dst = @"S2.2" },

        .{ .src = @"S2.2", .event = E2, .dst = @"S2.1" },
        .{ .src = @"S2.2", .event = E3, .dst = @"S2.1" },
    });

    var state_machine = TestStateMachine.create({});
    try t.expect(state_machine.is(@"S1.1"));
    try t.expect(state_machine.is(@"S2.1"));

    try t.expect(try state_machine.detailedProcess(E1{}));
    try t.expect(state_machine.is(@"S1.2"));
    try t.expect(state_machine.is(@"S2.1"));

    try t.expect(try state_machine.detailedProcess(E2{}));
    try t.expect(state_machine.is(@"S1.2"));
    try t.expect(state_machine.is(@"S2.2"));

    try t.expect(try state_machine.detailedProcess(E3{}));
    try t.expect(state_machine.is(@"S1.1"));
    try t.expect(state_machine.is(@"S2.1"));
}

test "Transition with .src being `Any` state is triggered with the specified event no matter the current state" {
    const S1 = struct {};
    const S2 = struct {};

    const TestStateMachine = StateMachine(.{
        .{ .init = true, .src = S1, .event = bool, .dst = S2 },
        .{ .src = S2, .event = bool, .dst = S1 },

        .{ .src = Any, .event = comptime_float, .dst = S1, .acts = .{increment} },
    });

    var ctx: u32 = 0;
    var state_machine = TestStateMachine.create(&ctx);

    try t.expect(state_machine.is(S1));

    try t.expect(try state_machine.detailedProcess(true));
    try t.expectEqual(0, ctx);
    try t.expect(state_machine.is(S2));

    try t.expect(try state_machine.detailedProcess(0.0));
    try t.expectEqual(1, ctx);
    try t.expect(state_machine.is(S1));

    try t.expect(try state_machine.detailedProcess(0.0));
    try t.expectEqual(2, ctx);
    try t.expect(state_machine.is(S1));
}

test "`Any` event is triggered with any event" {
    const S1 = struct {};

    const TestStateMachine = StateMachine(.{
        .{ .init = true, .src = S1, .event = Any, .acts = .{increment} },
    });

    var ctx: u32 = 0;
    var state_machine = TestStateMachine.create(&ctx);

    try t.expect(state_machine.is(S1));
    try t.expect(try state_machine.detailedProcess(1));
    try t.expectEqual(1, ctx);
    try t.expect(try state_machine.detailedProcess(1.0));
    try t.expectEqual(2, ctx);
    try t.expect(try state_machine.detailedProcess(true));
    try t.expectEqual(3, ctx);
    try t.expect(try state_machine.detailedProcess(""));
    try t.expectEqual(4, ctx);
}

test "An event shall not be further processed once it's already consumed by a transition" {
    const S1 = struct {};
    const S2 = struct {};

    const E1 = struct {};

    const TestStateMachine = StateMachine(.{
        .{ .init = true, .src = S1, .event = E1 },
        .{ .src = S1, .event = E1, .acts = .{increment} },

        .{ .init = true, .src = S2, .event = E1 },
        .{ .src = S2, .event = E1, .acts = .{increment} },
    });

    var ctx: u32 = 0;
    var state_machine = TestStateMachine.create(&ctx);

    try t.expect(try state_machine.detailedProcess(E1{}));
    try t.expectEqual(0, ctx);
}

const std = @import("std");
const state = @import("hsm");
const t = std.testing;

const StateMachine = state.StateMachine;
const Any = state.Any;
