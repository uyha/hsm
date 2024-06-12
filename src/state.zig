const std = @import("std");

const TypeList = @import("type_list.zig").TypeList;

fn StatesFromTransitions(transitions: anytype) type {
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

fn assertPredicate(Guard: type) void {
    switch (@typeInfo(Guard)) {
        .Fn => |func| {
            if (func.return_type != bool) {
                @compileError(
                    std.fmt.comptimePrint(
                        "A predicate has to have its return type being a `bool`, the return type of the function is {} instead",
                        .{func.return_type.?},
                    ),
                );
            }
        },
        else => @compileError(std.fmt.comptimePrint(
            "A tuple of predicate / predicate pointers is expected, a {} is found inside it",
            .{Guard},
        )),
    }
}

fn assertGuards(guards: anytype) void {
    comptime {
        switch (@typeInfo(@TypeOf(guards))) {
            .Struct => |t| {
                if (!t.is_tuple) {
                    @compileError("A tuple of predicates / predicate pointers is expected");
                }

                for (guards) |guard| {
                    switch (@typeInfo(@TypeOf(guard))) {
                        .Pointer => |ptr| assertPredicate(ptr.child),
                        else => assertPredicate(@TypeOf(guard)),
                    }
                }
            },
            else => |t| @compileError(std.fmt.comptimePrint(
                "A tuple of predicate pointers is expected, {} was provided",
                .{t},
            )),
        }
    }
}

fn assertAction(Action: type) void {
    switch (@typeInfo(Action)) {
        .Fn => {},
        else => @compileError(std.fmt.comptimePrint(
            "A tuple of functions / function pointers is expected, a {} is found inside it",
            .{Action},
        )),
    }
}

fn assertActions(actions: anytype) void {
    switch (@typeInfo(@TypeOf(actions))) {
        .Struct => |t| {
            if (!t.is_tuple) {
                @compileError("A tuple of functions / function pointers is expected");
            }

            for (actions) |action| {
                switch (@typeInfo(@TypeOf(action))) {
                    .Pointer => |ptr| assertAction(ptr.child),
                    else => assertAction(@TypeOf(action)),
                }
            }
        },
        else => |t| @compileError(std.fmt.comptimePrint(
            "A tuple of functions / function pointers is expected, {} was provided",
            .{t},
        )),
    }
}

pub fn assertTransition(transition: anytype) void {
    const trans_type = @TypeOf(transition);
    const trans_info = @typeInfo(trans_type);

    if (trans_info != .Struct) {
        @compileError(std.fmt.comptimePrint(
            "A transition has to be struct, a {} is found instead",
            .{@TypeOf(transition)},
        ));
    }

    if (@hasField(trans_type, "initial") and @TypeOf(transition.initial) != bool) {
        @compileError("The `initial` field has to be `bool`");
    }

    if (!@hasField(trans_type, "src")) {
        @compileError("A transition has to has a `src` field");
    }
    if (@TypeOf(transition.src) != type) {
        @compileError("The `src` field has to be `type`");
    }

    if (@hasField(trans_type, "event") and @TypeOf(transition.event) != type) {
        @compileError("The `event` field has to be `type`");
    }

    if (@hasField(trans_type, "dst") and @TypeOf(transition.dst) != type) {
        @compileError("The `dst` field has to be `type`");
    }

    if (@hasField(trans_type, "guards")) {
        assertGuards(transition.guards);
    }

    if (@hasField(trans_type, "actions")) {
        assertActions(transition.actions);
    }
}

fn totalInitials(transitions: anytype) usize {
    var initials = 0;
    for (transitions) |trans| {
        assertTransition(trans);

        if (@hasField(@TypeOf(trans), "initial") and trans.initial) {
            initials += 1;
        }
    }

    return initials;
}

fn assertInitials(transitions: anytype) void {
    if (totalInitials(transitions) == 0) {
        @compileError("At least 1 initial transition has to be present");
    }
}

fn assertResources(Resources: type) void {
    switch (@typeInfo(Resources)) {
        .Struct => |Res| {
            if (!Res.is_tuple) {
                @compileError("resources must be a tuple of values");
            }
        },
        else => @compileError("resources must be a tuple of values"),
    }
}

fn StateIndices(transitions: anytype) type {
    return [totalInitials(transitions)]usize;
}

fn initialStateIndices(transitions: anytype, type_list: type) StateIndices(transitions) {
    const inititals = totalInitials(transitions);

    var result: StateIndices(transitions) = .{undefined} ** inititals;
    var index = 0;

    for (transitions) |trans| {
        if (@hasField(@TypeOf(trans), "initial") and trans.initial) {
            result[index] = type_list.index(trans.src).?;
            index += 1;
        }
    }

    return result;
}

fn StateMachine(comptime transitions: anytype, Resources: type) type {
    comptime assertResources(Resources);

    return struct {
        const Self = @This();
        const States = StatesFromTransitions(transitions);

        stateIndices: StateIndices(transitions) = initialStateIndices(transitions, States),
        resources: Resources,

        pub fn process(self: *Self, event: anytype) void {
            region: for (0.., self.stateIndices) |index, stateIndex| {
                inline for (transitions) |trans| {
                    if (States.index(trans.src).? == stateIndex) {
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
                                if (comptime @hasField(Trans, "actions")) {
                                    inline for (trans.actions) |action| {
                                        self.invoke(action, event);
                                    }
                                }

                                if (@hasField(@TypeOf(trans), "dst")) {
                                    self.stateIndices[index] = States.index(trans.dst).?;
                                    continue :region;
                                }
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

        fn invoke(self: *const Self, func: anytype, event: anytype) ReturnType(@typeInfo(@TypeOf(func))) {
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
                    inline for (self.resources) |resource| {
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

fn CompositeState(comptime transitions: anytype) type {
    comptime assertInitials(transitions);

    return struct {
        pub fn init(resources: anytype) StateMachine(transitions, @TypeOf(resources)) {
            return .{ .resources = resources };
        }
    };
}

pub const State = CompositeState;