const std = @import("std");
const state = @import("hsm");

const State = state.State;

test "Simple State" {
    const testing = std.testing;

    const S1 = struct {};
    const S2 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = S1, .event = i32, .dst = S2 },
        .{ .src = S2, .event = i32, .dst = S1 },
    });

    var state_machine = TestStateMachine.init(.{});

    try testing.expect(state_machine.is(S1));

    try testing.expect(!state_machine.process(@as(i8, 1)));
    try testing.expect(state_machine.process(@as(i32, 1)));

    try testing.expect(state_machine.is(S2));
    try testing.expect(state_machine.process(@as(i32, 1)));

    try testing.expect(state_machine.is(S1));
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
    const testing = std.testing;

    const S1 = struct {};
    const S2 = struct {};

    const TestStateMachine = State(.{
        .{ .init = true, .src = S1, .event = Event, .dst = S2, .guards = .{Event.isEven} },
        .{ .src = S2, .event = u32, .dst = S1, .guards = .{isEven} },
    });

    var state_machine = TestStateMachine.init(.{});

    try testing.expect(state_machine.is(S1));

    try testing.expect(!state_machine.process(Event{ .value = 1 }));
    try testing.expect(state_machine.process(Event{ .value = 2 }));
    try testing.expect(state_machine.is(S2));

    try testing.expect(!state_machine.process(@as(u32, 1)));
    try testing.expect(state_machine.process(@as(u32, 2)));
    try testing.expect(state_machine.is(S1));
}
