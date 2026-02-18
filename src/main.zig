const std = @import("std");
const sim = @import("sim.zig");
const task = @import("task.zig");

const csv = @import("csv.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var simulator = sim.Simulator{};
    defer simulator.deinit(alloc);

    const instrs_a = &[_]task.Instruction{
        .{ .work = .{ .fixed = 500 } },
        .{ .io = .{ .range = .{ .floor = 2, .ceiling = 10 } } },
        .{ .work = .{ .fixed = 1500 } },
    };
    const task_a = task.Task.init(instrs_a);

    const instrs_b = &[_]task.Instruction{
        .{ .work = .{ .range = .{ .floor = 25, .ceiling = 450 } } },
        .{ .io = .{ .range = .{ .floor = 3, .ceiling = 5 } } },
    };
    const task_b = task.Task.init(instrs_b);

    const instrs_c = &[_]task.Instruction{
        .{ .work = .{ .range = .{ .floor = 25, .ceiling = 450 } } },
        .{ .io = .{ .range = .{ .floor = 3, .ceiling = 5 } } },
    };
    const task_c = task.Task.init(instrs_c);

    try simulator.register(alloc, task_a);
    try simulator.register(alloc, task_b);
    try simulator.register(alloc, task_c);

    // simulator.use_q_learning = true;

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

    try csv.to_csv("baseline_3_cpu_heavy.csv", simulator.hist.items);
}

test {
    _ = @import("sim.zig");
    _ = @import("task.zig");
    _ = @import("q_agent.zig");
}
