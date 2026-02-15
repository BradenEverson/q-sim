const std = @import("std");
const sim = @import("sim.zig");
const task = @import("task.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var simulator = sim.Simulator{};
    defer simulator.deinit(alloc);

    const instrs_a = &[_]task.Instruction{
        .{ .work = .{ .fixed = 5 } },
        .{ .work = .{ .fixed = 10 } },
    };
    const task_a = task.Task.init(instrs_a);

    const instrs_b = &[_]task.Instruction{
        .{ .work = .{ .fixed = 5 } },
        .{ .io = .{ .fixed = 50 } },
    };
    const task_b = task.Task.init(instrs_b);

    try simulator.register(alloc, task_a);
    try simulator.register(alloc, task_b);

    while (true) {
        try simulator.tick(alloc);
    }
}

test {
    _ = @import("sim.zig");
    _ = @import("task.zig");
}
