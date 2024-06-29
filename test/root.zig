const state = @import("state.zig");

comptime {
    const testing = @import("std").testing;

    testing.refAllDecls(state);
}
