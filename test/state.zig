const std = @import("std");
const state = @import("hsm");
const testing = std.testing;

const State = state.State;
const Any = state.Any;

test "Simple State" {
    const S1 = struct {};
    const S2 = struct {};

    const StateMachine = State(.{
        .{ .init = true, .src = S1, .event = i32, .dst = S2 },
        .{ .src = S2, .event = i32, .dst = S1 },
    });

    var state_machine = StateMachine.init(.{});

    try testing.expect(state_machine.is(S1));

    try testing.expect(!state_machine.detailedProcess(@as(i8, 1)));
    try testing.expect(state_machine.detailedProcess(@as(i32, 1)));

    try testing.expect(state_machine.is(S2));
    try testing.expect(state_machine.detailedProcess(@as(i32, 1)));

    try testing.expect(state_machine.is(S1));
}

test "Crossing events" {
    const S1 = struct {};
    const S2 = struct {};
    const S3 = struct {};

    const E1 = struct {};
    const E2 = struct {};
    const E3 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = S1, .event = E2, .dst = S2 },
        .{ .src = S1, .event = E3, .dst = S3 },

        .{ .src = S2, .event = E1, .dst = S1 },
        .{ .src = S2, .event = E3, .dst = S3 },

        .{ .src = S3, .event = E1, .dst = S1 },
        .{ .src = S3, .event = E2, .dst = S2 },
    });

    var state_machine = TestStateMachine.init(.{});

    try testing.expect(state_machine.is(S1));

    try testing.expect(!state_machine.detailedProcess(E1{}));
    try testing.expect(state_machine.detailedProcess(E2{}));
    try testing.expect(state_machine.is(S2));

    try testing.expect(!state_machine.detailedProcess(E2{}));
    try testing.expect(state_machine.detailedProcess(E3{}));
    try testing.expect(state_machine.is(S3));

    try testing.expect(!state_machine.detailedProcess(E3{}));
    try testing.expect(state_machine.detailedProcess(E2{}));
    try testing.expect(state_machine.is(S2));
}

const Event = struct {
    value: u32,

    pub fn isEven(self: Event) bool {
        return @rem(self.value, 2) == 0;
    }
};

fn isEven(value: u32) bool {
    return @rem(value, 2) == 0;
}

test "Guarded transitions" {
    const S1 = struct {};
    const S2 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = S1, .event = Event, .dst = S2, .guards = .{Event.isEven} },
        .{ .src = S2, .event = u32, .dst = S1, .guards = .{isEven} },
    });

    var state_machine = TestStateMachine.init(.{});

    try testing.expect(state_machine.is(S1));

    try testing.expect(!state_machine.detailedProcess(Event{ .value = 1 }));
    try testing.expect(state_machine.detailedProcess(Event{ .value = 2 }));
    try testing.expect(state_machine.is(S2));

    try testing.expect(!state_machine.detailedProcess(@as(u32, 1)));
    try testing.expect(state_machine.detailedProcess(@as(u32, 2)));
    try testing.expect(state_machine.is(S1));
}

fn isMutablePointerEven(value: *u32) bool {
    return @rem(value.*, 2) == 0;
}

test "Resources" {
    const S1 = struct {};
    const S2 = struct {};
    const E1 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = S1, .event = E1, .dst = S2, .guards = .{isMutablePointerEven} },
        .{ .src = S2, .event = E1, .dst = S1 },
    });

    var resource: u32 = 1;

    var state_machine = TestStateMachine.init(.{&resource});

    try testing.expect(state_machine.is(S1));
    try testing.expect(!state_machine.detailedProcess(E1{}));

    try testing.expect(state_machine.is(S1));

    resource = 2;

    try testing.expect(state_machine.detailedProcess(E1{}));
    try testing.expect(state_machine.is(S2));
}

fn isConstPointerEven(value: *const u32) bool {
    return @rem(value.*, 2) == 0;
}

fn increment(value: *u32) void {
    value.* += 1;
}

test "Actions" {
    const S1 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = S1, .event = bool, .acts = .{increment} },
    });

    var value: u32 = 0;

    var state_machine = TestStateMachine.init(.{&value});

    try testing.expect(state_machine.is(S1));

    try testing.expect(state_machine.detailedProcess(true));
    try testing.expectEqual(1, value);

    try testing.expect(state_machine.detailedProcess(false));
    try testing.expectEqual(2, value);
}

test "Multiple regions" {
    const @"S1.1" = struct {};
    const @"S1.2" = struct {};
    const @"S2.1" = struct {};
    const @"S2.2" = struct {};
    const E1 = struct {};
    const E2 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = @"S1.1", .event = E1, .dst = @"S1.2" },
        .{ .src = @"S1.2", .event = E1, .dst = @"S1.1" },
        .{ .init = true, .src = @"S2.1", .event = E2, .dst = @"S2.2" },
        .{ .src = @"S2.2", .event = E2, .dst = @"S2.1" },
    });

    var state_machine = TestStateMachine.init(.{});
    try testing.expect(state_machine.is(@"S1.1"));
    try testing.expect(state_machine.is(@"S2.1"));

    try testing.expect(state_machine.detailedProcess(E1{}));
    try testing.expect(state_machine.is(@"S1.2"));
    try testing.expect(state_machine.is(@"S2.1"));

    try testing.expect(state_machine.detailedProcess(E2{}));
    try testing.expect(state_machine.is(@"S1.2"));
    try testing.expect(state_machine.is(@"S2.2"));

    try testing.expect(state_machine.detailedProcess(E2{}));
    try testing.expect(state_machine.is(@"S1.2"));
    try testing.expect(state_machine.is(@"S2.1"));

    try testing.expect(state_machine.detailedProcess(E1{}));
    try testing.expect(state_machine.is(@"S1.1"));
    try testing.expect(state_machine.is(@"S2.1"));
}

test "Multiple regions with shared event" {
    const @"S1.1" = struct {};
    const @"S1.2" = struct {};
    const @"S2.1" = struct {};
    const @"S2.2" = struct {};
    const E1 = struct {};
    const E2 = struct {};
    const E3 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = @"S1.1", .event = E1, .dst = @"S1.2" },

        .{ .src = @"S1.2", .event = E1, .dst = @"S1.1" },
        .{ .src = @"S1.2", .event = E3, .dst = @"S1.1" },

        .{ .init = true, .src = @"S2.1", .event = E2, .dst = @"S2.2" },

        .{ .src = @"S2.2", .event = E2, .dst = @"S2.1" },
        .{ .src = @"S2.2", .event = E3, .dst = @"S2.1" },
    });

    var state_machine = TestStateMachine.init(.{});
    try testing.expect(state_machine.is(@"S1.1"));
    try testing.expect(state_machine.is(@"S2.1"));

    try testing.expect(state_machine.detailedProcess(E1{}));
    try testing.expect(state_machine.is(@"S1.2"));
    try testing.expect(state_machine.is(@"S2.1"));

    try testing.expect(state_machine.detailedProcess(E2{}));
    try testing.expect(state_machine.is(@"S1.2"));
    try testing.expect(state_machine.is(@"S2.2"));

    try testing.expect(state_machine.detailedProcess(E3{}));
    try testing.expect(state_machine.is(@"S1.1"));
    try testing.expect(state_machine.is(@"S2.1"));
}

test "Transition with .src being `Any` state is triggered with the specified event no matter the current state" {
    const S1 = struct {};
    const S2 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = S1, .event = bool, .dst = S2 },
        .{ .src = S2, .event = bool, .dst = S1 },

        .{ .src = Any, .event = comptime_float, .dst = S1, .acts = .{increment} },
    });

    var value: u32 = 0;
    var state_machine = TestStateMachine.init(.{&value});

    try testing.expect(state_machine.is(S1));

    try testing.expect(state_machine.detailedProcess(true));
    try testing.expectEqual(0, value);
    try testing.expect(state_machine.is(S2));

    try testing.expect(state_machine.detailedProcess(0.0));
    try testing.expectEqual(1, value);
    try testing.expect(state_machine.is(S1));

    try testing.expect(state_machine.detailedProcess(0.0));
    try testing.expectEqual(2, value);
    try testing.expect(state_machine.is(S1));
}

test "`Any` event is triggered with any event" {
    const S1 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = S1, .event = Any, .acts = .{increment} },
    });

    var value: u32 = 0;
    var state_machine = TestStateMachine.init(.{&value});

    try testing.expect(state_machine.is(S1));
    try testing.expect(state_machine.detailedProcess(1));
    try testing.expectEqual(1, value);
    try testing.expect(state_machine.detailedProcess(1.0));
    try testing.expectEqual(2, value);
    try testing.expect(state_machine.detailedProcess(true));
    try testing.expectEqual(3, value);
    try testing.expect(state_machine.detailedProcess(""));
    try testing.expectEqual(4, value);
}

test "An event shall not be further processed once it's already consumed by a transition" {
    const S1 = struct {};
    // const S2 = struct {};

    const E1 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = S1, .event = E1 },
        .{ .src = S1, .event = E1, .acts = .{increment} },
    });

    var value: u32 = 0;
    var state_machine = TestStateMachine.init(.{&value});

    try testing.expect(state_machine.detailedProcess(E1{}));
    try testing.expectEqual(0, value);
}
