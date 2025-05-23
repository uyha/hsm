/// A State has to be initialized with a tuple of transitions.
///
/// A transition is a tuple that has the following fields
///   - `.init`: bool (Optional)
///   - `.src`: type
///   - `.event`: type (Optional)
///   - `.dst`: type (Optional)
///   - `.guards`: A tuple of guards (Optional). A guard is a function or
///     function pointer with the following signature:
///     `fn (ctx: Context, event: anytype) bool`.
///   - `.acts`: A tuple of acts (Optional). An action is a function or
///     function pointer with the following signatures:
///     - If there is no deferred event:
///       `fn (ctx: *Context, event: anytype) !void`
///     - Otherwise:
///       `fn (ctx: *Context, event: anytype, deferrer: anytype) !Events`
///
/// - `Context` is the type of the variable being passed to the `.init` function.
/// - `Events` is either `void` or a type whose has an `items` declaration that
///   is a tuple of types.
/// - `Later` is struct that has an `add` function that accepts all instances of
///   types returned by `acts` in all the transitions.
///
/// At least 1 transition has to have `.init` being `true`.
pub const State = CompositeState;

fn CompositeState(comptime transitions: anytype) type {
    comptime assertInits(transitions);

    return struct {
        pub const States = StatesFromTransitions(transitions);
        pub const deferred_events = DeferredEventsFromTransition(transitions).items;
        pub const DeferredEvent = if (deferred_events.len == 0) void else TaggedUnion(deferred_events);

        pub const create = if (deferred_events.len == 0)
            createNoContainer
        else
            createWithDeferContainer;

        fn createWithDeferContainer(
            ctx: anytype,
            container: anytype,
        ) StateMachine(
            transitions,
            std.meta.Child(@TypeOf(ctx)),
            std.meta.Child(@TypeOf(container)),
        ) {
            return .{ .ctx = ctx, .deferrer = .init(container) };
        }

        fn createNoContainer(ctx: anytype) StateMachine(
            transitions,
            std.meta.Child(@TypeOf(ctx)),
            void,
        ) {
            return .{ .ctx = ctx, .deferrer = {} };
        }
    };
}

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
        if (!@hasField(@TypeOf(trans), "acts")) {
            continue;
        }

        const acts = trans.acts;
        action: inline for (acts) |action| {
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
        .{ .acts = .{ just_void, err_void } },
        .{ .acts = .{ ret_i32, err_i32 } },
        .{ .acts = .{ ret_i32, err_i32 } },
        .{ .acts = .{ ret_f32, err_f32 } },
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

fn assertActions(acts: anytype) void {
    switch (@typeInfo(@TypeOf(acts))) {
        .@"struct" => |t| {
            if (!t.is_tuple) {
                @compileError("A tuple of functions / function pointers is expected");
            }

            for (acts) |action| {
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

fn assertTransition(transition: anytype) void {
    const Transition = @TypeOf(transition);
    const info = @typeInfo(Transition);

    if (info != .@"struct") {
        @compileError(@typeName(@TypeOf(transition)) ++ " is not a tuple");
    }

    if (@hasField(Transition, "init") and @TypeOf(transition.init) != bool) {
        @compileError("The `init` field has to be `bool`");
    }

    if (!@hasField(Transition, "src")) {
        @compileError("A transition has to has a `src` field");
    }
    if (@TypeOf(transition.src) != type) {
        @compileError("The `src` field has to be `type`");
    }

    if (@hasField(Transition, "event") and @TypeOf(transition.event) != type) {
        @compileError("The `event` field has to be `type`");
    }

    if (@hasField(Transition, "dst")) {
        if (@TypeOf(transition.dst) != type) {
            @compileError("The `dst` field has to be `type`");
        }
        if (transition.dst == Any) {
            @compileError("The `dst` field cannot be `Any`");
        }
    }

    if (@hasField(Transition, "guards")) {
        assertGuards(transition.guards);
    }

    if (@hasField(Transition, "acts")) {
        assertActions(transition.acts);
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

fn Regions(transitions: anytype) type {
    return [totalInits(transitions)]usize;
}

fn initRegions(transitions: anytype, type_list: type) Regions(transitions) {
    const inits = totalInits(transitions);

    var result: Regions(transitions) = .{undefined} ** inits;
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

pub fn Deferrer(events: anytype, Container: type) type {
    if (events.len == 0) return void;

    return struct {
        const Self = @This();
        const DeferredEvent = TaggedUnion(events);

        container: *Container,

        pub fn init(container: *Container) Self {
            return .{ .container = container };
        }

        pub fn add(self: *const Self, event: anytype) !void {
            const name = name: {
                inline for (events, 0..) |Event, i| {
                    if (@TypeOf(event) == Event) {
                        break :name comptimePrint("{}", .{i});
                    }
                }
                @compileError(
                    @typeName(@TypeOf(event)) ++ " does not exist in the deferred event list",
                );
            };
            try self.container.append(@unionInit(DeferredEvent, name, event));
        }

        pub fn remove(self: *const Self) ?DeferredEvent {
            if (self.container.items.len > 0) {
                return self.container.orderedRemove(0);
            } else {
                return null;
            }
        }
    };
}

fn hasError(func: anytype) bool {
    const Func = @TypeOf(func);
    switch (@typeInfo(@typeInfo(Func).@"fn".return_type.?)) {
        .error_union => return true,
        else => return false,
    }
}

fn StateMachine(
    comptime transitions: anytype,
    Context: type,
    Container: type,
) type {
    return struct {
        const Self = @This();

        const States = StatesFromTransitions(transitions);
        const deferred_events = DeferredEventsFromTransition(transitions).items;
        const DeferredEvent = TaggedUnion(deferred_events);

        regions: Regions(transitions) = initRegions(transitions, States),
        ctx: if (Context == void) void else *Context,
        deferrer: Deferrer(deferred_events, Container),

        pub inline fn process(self: *Self, event: anytype) anyerror!void {
            _ = try self.detailedProcess(event);
        }

        pub fn detailedProcess(self: *Self, event: anytype) anyerror!bool {
            var processed = false;

            for (0.., self.regions) |region, state| {
                inline for (transitions) |trans| {
                    if (try self.handleState(trans, event, state) and
                        comptime @hasField(@TypeOf(trans), "dst"))
                    {
                        self.regions[region] = States.index(trans.dst).?;
                        processed = true;
                    }
                }
            }

            while (self.deferrer.remove()) |deferred_event| {
                switch (deferred_event) {
                    inline else => |payload| {
                        _ = try self.detailedProcess(payload);
                    },
                }
            }

            return processed;
        }

        inline fn handleState(
            self: *Self,
            trans: anytype,
            event: anytype,
            state: usize,
        ) !bool {
            const Trans = @TypeOf(trans);
            const Event = @TypeOf(event);

            const index = comptime States.index(trans.src).?;
            if (index != state and comptime trans.src != Any) {
                return false;
            }

            if (comptime !@hasField(Trans, "event")) {
                return false;
            }

            if (comptime trans.event != Event and trans.event != Any) {
                return false;
            }

            if (comptime @hasField(Trans, "guards")) {
                inline for (trans.guards) |guard| {
                    const Guard = @TypeOf(guard);
                    const info = @typeInfo(Guard).@"fn";

                    switch (info.params.len) {
                        0 => if (!guard()) return false,
                        1 => if (!guard(self.ctx)) return false,
                        2 => if (!guard(self.ctx, event)) return false,
                        else => @compileError(
                            @typeName(Guard) ++ " is an invalid guard",
                        ),
                    }
                }
            }

            if (comptime @hasField(Trans, "acts")) {
                inline for (trans.acts) |action| {
                    const info = @typeInfo(@TypeOf(action)).@"fn";
                    const args = switch (info.params.len) {
                        1 => .{self.ctx},
                        2 => .{ self.ctx, event },
                        3 => .{ self.ctx, event, self.deferrer },
                        else => @compileError(
                            @typeName(@TypeOf(action)) ++ " is an invalid action",
                        ),
                    };

                    if (comptime hasError(action)) {
                        _ = try @call(.auto, action, args);
                    } else {
                        _ = @call(.auto, action, args);
                    }
                }
            }

            return true;
        }

        pub fn is(self: *const Self, current: type) bool {
            if (comptime States.index(current)) |index| {
                for (self.regions) |stateIndex| {
                    if (index == stateIndex) {
                        return true;
                    }
                }
                return false;
            }

            @compileError(
                @typeName(current) ++ " does not exist in the state machine",
            );
        }
    };
}

test StateMachine {
    const t = std.testing;

    const Download = struct {
        const Self = @This();

        const Done = struct {};
        const Failed = struct {};

        started: bool = false,
        progress: u8 = 0,
        random_gen: std.Random.DefaultPrng,
        result: ?enum { success, failure } = null,

        pub fn init() Self {
            return .{
                .random_gen = .init(@intCast(std.time.milliTimestamp())),
            };
        }

        fn start(self: *Self) void {
            self.started = true;
        }

        fn getMore(self: *Self, _: anytype, deferrer: anytype) !TypeList(.{ Done, Failed }) {
            self.progress += 1;

            if (self.progress == 100) {
                if (self.random_gen.random().boolean()) {
                    self.result = .success;
                    try deferrer.add(Done{});
                } else {
                    self.result = .failure;
                    try deferrer.add(Failed{});
                }
            }

            return .init;
        }
    };

    const Waiting = struct {};
    const Downloading = struct {};
    const Success = struct {};
    const Failure = struct {};

    const Start = struct {};
    const Resume = struct {};

    const SM = State(.{
        .{ .init = true, .src = Waiting, .event = Start, .acts = .{Download.start}, .dst = Downloading },

        .{ .src = Downloading, .event = Resume, .acts = .{Download.getMore} },
        .{ .src = Downloading, .event = Download.Done, .dst = Success },
        .{ .src = Downloading, .event = Download.Failed, .dst = Failure },
    });

    var container: std.ArrayList(SM.DeferredEvent) = .init(t.allocator);
    defer container.deinit();

    var download: Download = .init();
    var sm = SM.create(&download, &container);

    try t.expect(sm.is(Waiting));

    try sm.process(Start{});
    try t.expect(sm.is(Downloading));
    try t.expect(download.started);

    for (1..100) |i| {
        try sm.process(Resume{});
        try t.expect(sm.is(Downloading));
        try t.expectEqual(i, download.progress);
    }

    try sm.process(Resume{});
    try t.expect(null != download.result);
    switch (download.result.?) {
        .success => try t.expect(sm.is(Success)),
        .failure => try t.expect(sm.is(Failure)),
    }
}

const std = @import("std");
const comptimePrint = std.fmt.comptimePrint;

const hsm = @import("root.zig");
const TypeList = hsm.TypeList;
