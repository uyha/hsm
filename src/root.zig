const type_list = @import("type_list.zig");
pub const TypeList = type_list.TypeList;

/// This can be a source state or an event
pub const Any = struct {};

/// This can be an event
pub const Entering = struct {};
/// This can be an event
pub const Entered = struct {};
/// This can be an event
pub const Exiting = struct {};
/// This can be an event
pub const Exited = struct {};

const state = @import("state.zig");
pub const StateMachine = state.StateMachine;

// const transitions = @import("transitions.zig");
// pub const Transitions = transitions.Transitions;

comptime {
    const testing = @import("std").testing;

    testing.refAllDecls(type_list);
    testing.refAllDecls(state);
    // testing.refAllDecls(transitions);
}
