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
        .{ .work = .{ .fixed = 500 } },
        .{ .work = .{ .range = .{ .floor = 5, .ceiling = 15 } } },
    };
    const task_a = task.Task.init(instrs_a);

    const instrs_b = &[_]task.Instruction{
        .{ .work = .{ .range = .{ .floor = 5, .ceiling = 7 } } },
        .{ .io = .{ .range = .{ .floor = 35, .ceiling = 50 } } },
    };
    const task_b = task.Task.init(instrs_b);

    try simulator.register(alloc, task_a);
    try simulator.register(alloc, task_b);

    var buf: [16]u8 = undefined;
    const stdin = std.fs.File.stdin().deprecatedReader();

    while (true) {
        std.debug.print("\nEnter ticks to simulate (or \"exit\"): ", .{});

        if (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            const input = std.mem.trimRight(u8, line, "\r");
            if (std.mem.eql(u8, input, "exit")) break;

            const ticks = std.fmt.parseInt(u32, input, 10) catch {
                std.debug.print("Invalid input. Please enter a number or \"exit\".\n", .{});
                continue;
            };

            for (0..ticks) |_| {
                try simulator.tick(alloc);
            }

            simulator.summarize();
        }
    }
}

test {
    _ = @import("sim.zig");
    _ = @import("task.zig");
}
