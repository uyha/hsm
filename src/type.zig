pub fn coercible(Source: type, Target: type) bool {
    if (Source == Target) {
        return true;
    }

    const source_info = @typeInfo(Source);
    const target_info = @typeInfo(Target);

    switch (source_info) {
        .Pointer => |source_ptr| {
            switch (target_info) {
                .Pointer => |target_ptr| {
                    if (coercible(source_ptr.child, target_ptr.child)) {
                        return (!source_ptr.is_const or target_ptr.is_const) and
                            (!source_ptr.is_volatile or target_ptr.is_volatile) and
                            (source_ptr.alignment >= target_ptr.alignment);
                    }
                },
                else => {},
            }
        },
        else => {},
    }

    return false;
}

const testing = @import("std").testing;

test "Same type is coercible" {
    try testing.expect(coercible(bool, bool));
    try testing.expect(coercible(*u8, *u8));
    try testing.expect(coercible(*const u8, *const u8));
    try testing.expect(coercible(*volatile u8, *volatile u8));
    try testing.expect(coercible(*const volatile u8, *const volatile u8));
}

test "Stricter type is coercible" {
    try testing.expect(coercible(*u8, *const u8));
    try testing.expect(!coercible(*const u8, *u8));

    try testing.expect(coercible(*u8, *volatile u8));
    try testing.expect(!coercible(*volatile u8, *u8));

    try testing.expect(coercible(*align(8) u8, *align(1) u8));
    try testing.expect(!coercible(*align(1) u8, *align(2) u8));
}

test "Nested pointer is coercible" {
    try testing.expect(coercible(**u8, **const u8));
    try testing.expect(!coercible(**const u8, **u8));

    try testing.expect(coercible(**u8, **volatile u8));
    try testing.expect(!coercible(**volatile u8, **u8));

    try testing.expect(coercible(**align(2) u8, **align(1) u8));
    try testing.expect(!coercible(**align(1) u8, **align(2) u8));
}
