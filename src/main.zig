const std = @import("std");
const sim = @import("sim.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var simulator = sim.Simulator{};
    defer simulator.deinit(alloc);

    const instrs_a = &[_]sim.Instruction{
        .{ .work = .{ .fixed = 5 } },
        .{ .work = .{ .fixed = 10 } },
    };
    const task_a = sim.Task.init(instrs_a);

    const instrs_b = &[_]sim.Instruction{
        .{ .work = .{ .fixed = 5 } },
        .{ .work = .{ .fixed = 10 } },
    };
    const task_b = sim.Task.init(instrs_b);

    try simulator.register(alloc, task_a);
    try simulator.register(alloc, task_b);

    while (true) {
        try simulator.tick(alloc);
    }
}

test {
    _ = @import("sim.zig");
}
