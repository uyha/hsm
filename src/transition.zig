const std = @import("std");

pub fn Transition(guards: anytype, actions: anytype) type {
    return struct {
        pub const Guards = @TypeOf(guards);
        pub const Actions = @TypeOf(actions);

        initial: bool = false,
        Source: type,
        Event: ?type = null,
        Destination: ?type = null,

        guards: Guards = guards,
        actions: Actions = actions,

        const Self = @This();

        pub fn with(self: Self, comptime Event: type) Self {
            comptime {
                if (self.Event != null) {
                    @compileError("event is already set");
                }
            }

            return .{
                .initial = self.initial,
                .Source = self.Source,
                .Event = Event,
                .Destination = self.Destination,

                .guards = self.guards,
                .actions = self.actions,
            };
        }

        pub fn when(self: Self, comptime new_guards: anytype) Transition(self.guards ++ new_guards, self.actions) {
            comptime assertGuards(new_guards);

            return .{
                .initial = self.initial,
                .Source = self.Source,
                .Event = self.Event,
                .Destination = self.Destination,

                .guards = self.guards ++ new_guards,
                .actions = self.actions,
            };
        }

        pub fn then_do(self: Self, comptime new_actions: anytype) Transition(self.guards, self.actions ++ new_actions) {
            comptime assertActions(new_actions);

            return .{
                .initial = self.initial,
                .Source = self.Source,
                .Event = self.Event,
                .Destination = self.Destination,

                .guards = self.guards,
                .actions = self.actions ++ new_actions,
            };
        }

        pub fn then_enter(self: Self, comptime Destination: type) Self {
            comptime {
                if (self.Destination != null) {
                    @compileError("event is already set");
                }
            }

            return .{
                .initial = self.initial,
                .Source = self.Source,
                .Event = self.Event,
                .Destination = Destination,

                .guards = self.guards,
                .actions = self.actions,
            };
        }
    };
}

pub fn assertGuards(guards: anytype) void {
    comptime {
        switch (@typeInfo(@TypeOf(guards))) {
            .Struct => |t| {
                if (!t.is_tuple) {
                    @compileError("A tuple of function pointers is expected");
                }

                for (guards) |guard| {
                    if (@typeInfo(@TypeOf(guard)) != .Pointer) {
                        @compileError(std.fmt.comptimePrint(
                            "A tuple of predicate pointers is expected, a {} is found inside it",
                            .{@TypeOf(guard)},
                        ));
                    }
                    switch (@typeInfo(@TypeOf(guard.*))) {
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
                            "A tuple of predicate pointers is expected, a {} is found inside it",
                            .{@TypeOf(guard)},
                        )),
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

pub fn assertActions(actions: anytype) void {
    comptime {
        switch (@typeInfo(@TypeOf(actions))) {
            .Struct => |t| {
                if (!t.is_tuple) {
                    @compileError("A tuple of function pointers is expected");
                }

                for (actions) |action| {
                    if (@typeInfo(@TypeOf(action)) != .Pointer) {
                        @compileError(std.fmt.comptimePrint(
                            "A tuple of function pointers is expected, a {} is found inside it",
                            .{@TypeOf(action)},
                        ));
                    }
                    switch (@typeInfo(@TypeOf(action.*))) {
                        .Fn => {},
                        else => @compileError(std.fmt.comptimePrint(
                            "A tuple of function pointers is expected, a {} is found inside it",
                            .{@TypeOf(action)},
                        )),
                    }
                }
            },
            else => |t| @compileError(std.fmt.comptimePrint(
                "A tuple of function pointers is expected, {} was provided",
                .{t},
            )),
        }
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

    if (!@hasField(trans_type, "initial")) {
        @compileError("A transition has to has a `initial` field");
    }
    if (@TypeOf(transition.initial) != bool) {
        @compileError("The `initial` field has to be `bool`");
    }

    if (!@hasField(trans_type, "Source")) {
        @compileError("A transition has to has a `Source` field");
    }
    if (@TypeOf(transition.Source) != type) {
        @compileError("The `Source` field has to be `type`");
    }

    if (!@hasField(trans_type, "Event")) {
        @compileError("A transition has to has a `Event` field");
    }
    if (@TypeOf(transition.Event) != ?type and @TypeOf(transition.Event) != type) {
        @compileError("The `Event` field has to be `?type` or `type`");
    }

    if (!@hasField(trans_type, "Destination")) {
        @compileError("A transition has to has a `Destination` field");
    }
    if (@TypeOf(transition.Destination) != ?type and @TypeOf(transition.Destination) != type) {
        @compileError("The `Destination` field has to be `?type` or `type`");
    }

    if (!@hasField(trans_type, "guards")) {
        @compileError("A transition has to has a `guards` field");
    }
    assertGuards(transition.guards);

    if (!@hasField(trans_type, "actions")) {
        @compileError("A transition has to has a `actions` field");
    }
    assertActions(transition.actions);
}

pub fn state(Source: type) Transition(.{}, .{}) {
    return Transition(.{}, .{}){
        .Source = Source,
    };
}

pub fn initial(Source: type) Transition(.{}, .{}) {
    return Transition(.{}, .{}){
        .initial = true,
        .Source = Source,
    };
}
