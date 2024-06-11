const std = @import("std");

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
