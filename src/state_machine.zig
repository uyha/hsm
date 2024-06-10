pub fn StateMachine(comptime transitions_: anytype) type {
    return struct {
        const Self = @This();

        const transitions = transitions_;

        current: usize = 0,

        pub fn process(self: Self, event: anytype) void {
            inline for (0.., transitions) |index, state| {
                if (self.current == index) {
                    state.process_event(event);
                }
            }
        }
    };
}
