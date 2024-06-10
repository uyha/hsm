const transition = @import("transition.zig");
const TypeList = @import("type_list.zig").TypeList;

fn ConstructStates(comptime transitions: anytype) type {
    comptime var result = TypeList(.{});
    inline for (transitions) |trans| {
        if (result.index(trans.Source) == null) {
            result = result.append(trans.Source);
        }
        if (trans.Destination) |Dest| {
            if (result.index(Dest) == null) {
                result = result.append(Dest);
            }
        }
    }

    return result;
}

pub fn StateMachine(comptime transitions: anytype) type {
    comptime {
        var initials = 0;
        for (transitions) |trans| {
            transition.assertTransition(trans);

            if (trans.initial) {
                initials += 1;
            }
        }

        if (initials == 0) {
            @compileError("At least 1 initial transition has to be present");
        }
    }

    return struct {
        const std = @import("std");
        current: usize = 0,

        const Self = @This();
        const States = ConstructStates(transitions);

        pub fn process(self: *Self, event: anytype) void {
            inline for (transitions) |trans| {
                if (getIndex(trans.Source) == self.current) {
                    if (trans.Event) |Event| {
                        if (@TypeOf(event) == Event) {
                            var passed = true;
                            inline for (trans.guards) |guard| {
                                if (passed) {
                                    passed = passed and self.invoke(guard);
                                }
                            }
                            if (passed) {
                                inline for (trans.actions) |action| {
                                    self.invoke(action);
                                }

                                if (trans.Destination) |Dest| {
                                    self.current = getIndex(Dest);
                                    return;
                                }
                            }
                        }
                    }
                }
            }
        }

        fn ReturnType(comptime info: std.builtin.Type) type {
            return @typeInfo(info.Pointer.child).Fn.return_type.?;
        }

        fn getIndex(comptime T: type) usize {
            return States.index(T).?;
        }

        fn invoke(_: *const Self, fnPtr: anytype) ReturnType(@typeInfo(@TypeOf(fnPtr))) {
            return fnPtr();
        }
    };
}

pub fn stateMachine(comptime transitions: anytype) StateMachine(transitions) {
    return StateMachine(transitions){};
}
