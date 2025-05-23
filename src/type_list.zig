pub fn TypeList(current: anytype) type {
    comptime {
        const info = @typeInfo(@TypeOf(current)).@"struct";
        if (!info.is_tuple) {
            @compileError("`current` must be a tuple of types");
        }
        for (info.fields) |field| {
            if (field.type != type) {
                @compileError(std.fmt.comptimePrint(
                    "Field {s} must be a type, not {}\n",
                    .{ field.name, field.type },
                ));
            }
        }
    }

    return struct {
        const Self = @This();

        pub const items = current;

        pub const init: Self = .{};

        pub fn append(T: type) @TypeOf(TypeList(Self.items ++ .{T})) {
            return TypeList(Self.items ++ .{T});
        }

        test append {
            const t = std.testing;

            const list = TypeList(.{}).append(u8).append(u16);

            try t.expectEqual(u8, list.items[0]);
            try t.expectEqual(u16, list.items[1]);
        }

        pub fn index(comptime T: type) ?usize {
            inline for (0.., items) |i, t| {
                if (t == T) return i;
            }

            return null;
        }

        test index {
            const t = std.testing;

            const list = TypeList(.{ u8, u16, u8 });

            try t.expectEqual(0, list.index(u8));
            try t.expectEqual(1, list.index(u16));
            try t.expectEqual(null, list.index(u32));
        }
    };
}

const std = @import("std");
