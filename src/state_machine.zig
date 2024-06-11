const transition = @import("transition.zig");
const TypeList = @import("type_list.zig").TypeList;

fn ConstructStates(comptime transitions: anytype) type {
    comptime var result = TypeList(.{});
    inline for (transitions) |trans| {
        if (result.index(trans.src) == null) {
            result = result.append(trans.src);
        }
        if (@hasField(@TypeOf(trans), "dst") and @TypeOf(trans.dst) == type) {
            result = result.append(trans.dst);
        }
    }

    return result;
}

pub fn StateMachine(comptime transitions: anytype) type {
    comptime {
        var initials = 0;
        for (transitions) |trans| {
            transition.assertTransition(trans);

            if (@hasField(@TypeOf(trans), "initial") and trans.initial) {
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
                if (getIndex(trans.src) == self.current) {
                    const Trans = @TypeOf(trans);

                    if (@hasField(Trans, "event")) {
                        if (@TypeOf(event) == trans.event) {
                            var passed = true;
                            comptime if (@hasField(Trans, "guards")) {
                                for (trans.guards) |guard| {
                                    if (passed) {
                                        passed = passed and self.invoke(guard);
                                    }
                                }
                            };
                            if (passed) {
                                inline for (trans.actions) |action| {
                                    self.invoke(action);
                                }

                                if (@hasField(@TypeOf(trans), "dst")) {
                                    self.current = getIndex(trans.dst);
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
