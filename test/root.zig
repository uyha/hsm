const state = @import("state.zig");

comptime {
    const t = @import("std").testing;

    t.refAllDecls(state);
}
