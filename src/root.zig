const type_list = @import("type_list.zig");
pub const TypeList = type_list.TypeList;

pub const transition = @import("transition.zig");
pub const Transition = transition.Transition;
pub const state = transition.state;
pub const initial = transition.initial;

const state_machine = @import("state_machine.zig");
pub const StateMachine = state_machine.StateMachine;
pub const stateMachine = state_machine.stateMachine;

comptime {
    const testing = @import("std").testing;

    testing.refAllDecls(type_list);
    testing.refAllDecls(transition);
    testing.refAllDecls(state_machine);
}
