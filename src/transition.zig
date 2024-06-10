const std = @import("std");

pub fn Transition(guards: anytype, actions: anytype) type {
    return struct {
        pub const Guards = @TypeOf(guards);
        pub const Actions = @TypeOf(actions);

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
                .Source = self.Source,
                .Event = Event,
                .Destination = self.Destination,

                .guards = self.guards,
                .actions = self.actions,
            };
        }

        pub fn when(self: Self, comptime new_guards: anytype) Transition(self.guards ++ new_guards, self.actions) {
            comptime {
                switch (@typeInfo(@TypeOf(new_guards))) {
                    .Struct => |t| {
                        if (!t.is_tuple) {
                            @compileError("A tuple of function pointers is expected");
                        }

                        for (new_guards) |guard| {
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

            return .{
                .Source = self.Source,
                .Event = self.Event,
                .Destination = self.Destination,

                .guards = self.guards ++ new_guards,
                .actions = self.actions,
            };
        }

        pub fn then_do(self: Self, comptime new_actions: anytype) Transition(self.guards, self.actions ++ new_actions) {
            comptime {
                switch (@typeInfo(@TypeOf(new_actions))) {
                    .Struct => |t| {
                        if (!t.is_tuple) {
                            @compileError("A tuple of function pointers is expected");
                        }

                        for (new_actions) |action| {
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

            return .{
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
                .Source = self.Source,
                .Event = self.Event,
                .Destination = Destination,

                .guards = self.guards,
                .actions = self.actions,
            };
        }
    };
}

pub fn state(source: type) Transition(.{}, .{}) {
    return Transition(.{}, .{}){
        .Source = source,
    };
}
