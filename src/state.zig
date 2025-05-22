const std = @import("std");

const TypeList = @import("type_list.zig").TypeList;
const coercible = @import("type.zig").coercible;

pub const Any = struct {};

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

fn DeferredEventsFromTransition(transitions: anytype) type {
    comptime var events = TypeList(.{});

    inline for (transitions) |trans| {
        if (!@hasField(@TypeOf(trans), "actions")) {
            continue;
        }

        const actions = trans.actions;
        action: inline for (actions) |action| {
            const ReturnType = @typeInfo(@TypeOf(action)).@"fn".return_type.?;

            var Type = ReturnType;

            const items = items: switch (@typeInfo(Type)) {
                .void => continue :action,
                .error_union => |info| {
                    Type = info.payload;
                    continue :items @typeInfo(Type);
                },
                .@"struct" => Type.items,
                else => @compileError(
                    @typeName(ReturnType) ++ " is not supported",
                ),
            };

            append: inline for (items) |T| {
                inline for (events.items) |item| {
                    if (T == item) {
                        continue :append;
                    }
                }

                events = events.append(T);
            }
        }
    }

    return events;
}

test DeferredEventsFromTransition {
    const just_void = struct {
        fn f() void {}
    }.f;
    const err_void = struct {
        fn f() error{}!void {}
    }.f;
    const ret_i32 = struct {
        fn f() TypeList(.{i32}) {}
    }.f;
    const err_i32 = struct {
        fn f() error{OutOfMemory}!TypeList(.{i32}) {}
    }.f;
    const ret_f32 = struct {
        fn f() TypeList(.{f32}) {}
    }.f;
    const err_f32 = struct {
        fn f() error{}!TypeList(.{f32}) {}
    }.f;

    const t = std.testing;

    const Events = DeferredEventsFromTransition(.{
        .{ .actions = .{ just_void, err_void } },
        .{ .actions = .{ ret_i32, err_i32 } },
        .{ .actions = .{ ret_i32, err_i32 } },
        .{ .actions = .{ ret_f32, err_f32 } },
    });

    try t.expectEqual(2, Events.items.len);
    try t.expect(Events.index(i32) != null);
    try t.expect(Events.index(f32) != null);
}

fn assertPredicate(Guard: type) void {
    switch (@typeInfo(Guard)) {
        .@"fn" => |func| {
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
            .@"struct" => |t| {
                if (!t.is_tuple) {
                    @compileError("A tuple of predicates / predicate pointers is expected");
                }

                for (guards) |guard| {
                    switch (@typeInfo(@TypeOf(guard))) {
                        .pointer => |ptr| assertPredicate(ptr.child),
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
        .@"fn" => {},
        else => @compileError(std.fmt.comptimePrint(
            "A tuple of functions / function pointers is expected, a {} is found inside it",
            .{Action},
        )),
    }
}

fn assertActions(actions: anytype) void {
    switch (@typeInfo(@TypeOf(actions))) {
        .@"struct" => |t| {
            if (!t.is_tuple) {
                @compileError("A tuple of functions / function pointers is expected");
            }

            for (actions) |action| {
                switch (@typeInfo(@TypeOf(action))) {
                    .pointer => |ptr| assertAction(ptr.child),
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

    if (trans_info != .@"struct") {
        @compileError(std.fmt.comptimePrint(
            "A transition has to be struct, a {} is found instead",
            .{@TypeOf(transition)},
        ));
    }

    if (@hasField(trans_type, "init") and @TypeOf(transition.init) != bool) {
        @compileError("The `init` field has to be `bool`");
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

    if (@hasField(trans_type, "dst")) {
        if (@TypeOf(transition.dst) != type) {
            @compileError("The `dst` field has to be `type`");
        }
        if (transition.dst == Any) {
            @compileError("The `dst` field cannot be `Any`");
        }
    }

    if (@hasField(trans_type, "guards")) {
        assertGuards(transition.guards);
    }

    if (@hasField(trans_type, "actions")) {
        assertActions(transition.actions);
    }
}

fn totalInits(transitions: anytype) usize {
    var inits = 0;
    for (transitions) |trans| {
        assertTransition(trans);

        if (@hasField(@TypeOf(trans), "init") and trans.init) {
            inits += 1;
        }
    }

    return inits;
}

fn assertInits(transitions: anytype) void {
    if (totalInits(transitions) == 0) {
        @compileError("At least 1 init transition has to be present");
    }
}

fn assertResources(Resources: type) void {
    switch (@typeInfo(Resources)) {
        .@"struct" => |Res| {
            if (!Res.is_tuple) {
                @compileError("resources must be a tuple of values");
            }
        },
        else => @compileError("resources must be a tuple of values"),
    }
}

fn StateIndices(transitions: anytype) type {
    return [totalInits(transitions)]usize;
}

fn initStateIndices(transitions: anytype, type_list: type) StateIndices(transitions) {
    const inits = totalInits(transitions);

    var result: StateIndices(transitions) = .{undefined} ** inits;
    var index = 0;

    for (transitions) |trans| {
        if (@hasField(@TypeOf(trans), "init") and trans.init) {
            result[index] = type_list.index(trans.src).?;
            index += 1;
        }
    }

    return result;
}

/// `events` has to be a tuple of types.
fn TaggedUnion(events: anytype) type {
    const EnumField = std.builtin.Type.EnumField;
    const UnionField = std.builtin.Type.UnionField;
    const comptimePrint = std.fmt.comptimePrint;

    const len = events.len;

    if (len == 0) {
        return void;
    }

    var enum_fields: [len]EnumField = undefined;
    var union_fields: [len]UnionField = undefined;

    inline for (events, 0..) |Event, i| {
        const name = comptimePrint("{}", .{i});
        enum_fields[i] = .{ .name = name, .value = i };
        union_fields[i] = .{
            .name = name,
            .type = Event,
            .alignment = @alignOf(Event),
        };
    }

    const Tag = @Type(.{ .@"enum" = .{
        .tag_type = std.math.IntFittingRange(0, len),
        .fields = &enum_fields,
        .is_exhaustive = true,
        .decls = &.{},
    } });
    return @Type(.{ .@"union" = .{
        .layout = .auto,
        .tag_type = Tag,
        .fields = &union_fields,
        .decls = &.{},
    } });
}

test TaggedUnion {
    const t = std.testing;

    const Event = TaggedUnion(.{ i8, bool });

    try t.expectEqual(8, (Event{ .@"0" = 8 }).@"0");
    try t.expectEqual(true, (Event{ .@"1" = true }).@"1");
}

fn CompositeState(comptime transitions: anytype) type {
    comptime assertInits(transitions);

    return struct {
        pub fn init(resources: anytype) StateMachine(transitions, @TypeOf(resources)) {
            return .{ .resources = resources };
        }
    };
}

// A State has to be initialized with a tuple of transitions
// A transition is a tuple that has the following fields
//      .init: bool (Optional)
//      .src: type
//      .event: type (Optional)
//      .dst: type (Optional)
//      .guards: tuple of fn or *fn (Optional)
//      .actions: tuple of fn or *fn (Optional)
// At least 1 transition has to have .init = true
pub const State = CompositeState;
