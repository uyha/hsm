const std = @import("std");

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

pub fn assertGuards(guards: anytype) void {
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
    comptime {
        switch (@typeInfo(Action)) {
            .Fn => {},
            else => @compileError(std.fmt.comptimePrint(
                "A tuple of functions / function pointers is expected, a {} is found inside it",
                .{Action},
            )),
        }
    }
}

pub fn assertActions(actions: anytype) void {
    comptime {
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
