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

fn assertResources(resources: anytype) void {
    switch (@typeInfo(@TypeOf(resources))) {
        .Struct => |Resources| {
            if (!Resources.is_tuple) {
                @compileError("resources must be a tuple of values");
            }
        },
        else => @compileError("resources must be a tuple of values"),
    }
}

pub fn StateMachine(comptime transitions: anytype, resources: anytype) type {
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

        assertResources(resources);
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

                    if (comptime @hasField(Trans, "event") and
                        @TypeOf(event) == trans.event)
                    {
                        var passed = true;
                        if (comptime @hasField(Trans, "guards")) {
                            inline for (trans.guards) |guard| {
                                if (passed) {
                                    passed = passed and self.invoke(guard, event);
                                }
                            }
                        }
                        if (passed) {
                            inline for (trans.actions) |action| {
                                self.invoke(action, event);
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

        fn ReturnType(comptime info: std.builtin.Type) type {
            return switch (info) {
                .Pointer => |ptr| @typeInfo(ptr.child).Fn.return_type.?,
                .Fn => |func| func.return_type.?,
                else => unreachable,
            };
        }

        fn getIndex(comptime T: type) usize {
            return States.index(T).?;
        }

        fn invoke(_: *const Self, func: anytype, event: anytype) ReturnType(@typeInfo(@TypeOf(func))) {
            const Fn = switch (@typeInfo(@TypeOf(func))) {
                .Pointer => |ptr| ptr.child,
                .Fn => @TypeOf(func),
                else => unreachable,
            };
            const Args = std.meta.ArgsTuple(Fn);
            const len = @typeInfo(Args).Struct.fields.len;

            var args: Args = if (len == 0) .{} else .{undefined} ** len;

            inline for (0.., @typeInfo(Args).Struct.fields) |i, Arg| {
                comptime var found = false;

                if (comptime Arg.type == @TypeOf(event)) {
                    args[i] = event;
                    found = true;
                } else {
                    inline for (resources) |resource| {
                        if (comptime !found and Arg.type == @TypeOf(resource)) {
                            args[i] = resource;
                            found = true;
                        }
                    }
                }

                if (comptime !found) {
                    @compileError(
                        std.fmt.comptimePrint("{} not available\n", .{Arg.type}),
                    );
                }
            }

            return @call(.auto, func, args);
        }
    };
}

pub fn stateMachine(comptime transitions: anytype, resources: anytype) StateMachine(
    transitions,
    resources,
) {
    return .{};
}
