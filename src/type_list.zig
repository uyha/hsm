const std = @import("std");

pub fn TypeList(current: anytype) type {
    comptime {
        switch (@typeInfo(@TypeOf(current))) {
            .Struct => |t| {
                if (!t.is_tuple) {
                    @compileError("`current` must be a tuple of types");
                }
                for (t.fields) |field| {
                    if (field.type != type) {
                        @compileError(std.fmt.comptimePrint(
                            "Field {s} must be a type, but it is {}\n",
                            .{ field.name, field.type },
                        ));
                    }
                }
            },
            else => @compileError("`current` must be a tuple of types"),
        }
    }

    return struct {
        const types = current;

        pub fn append(T: type) @TypeOf(TypeList(@This().types ++ .{T})) {
            return TypeList(@This().types ++ .{T});
        }

        pub fn index(comptime T: type) ?usize {
            inline for (0.., types) |i, t| {
                if (t == T) return i;
            }

            return null;
        }
    };
}

test "append shall add the argument to the type" {
    const type_list = TypeList(.{}).append(u8).append(u16);

    try std.testing.expectEqual(u8, type_list.types[0]);
    try std.testing.expectEqual(u16, type_list.types[1]);
}

test "index shall return the index of the type appearing first" {
    const type_list = TypeList(.{ u8, u16, u8 });

    try std.testing.expectEqual(0, type_list.index(u8));
    try std.testing.expectEqual(1, type_list.index(u16));
    try std.testing.expectEqual(null, type_list.index(u32));
}
