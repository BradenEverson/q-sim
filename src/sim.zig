//! Simulator

const std = @import("std");

const DELTA: usize = 10;

var prng: ?std.Random.DefaultPrng = null;

fn getRand() std.Random {
    if (prng) |*r| {
        return r.random();
    } else {
        prng = .init(blk: {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
            break :blk seed;
        });
        return prng.?.random();
    }
}

pub const Work = union(enum) {
    fixed: usize,
    range: struct { floor: usize, ceiling: usize },

    pub fn resolve(self: *const Work) usize {
        const rand = getRand();
        return switch (self.*) {
            .fixed => |f| f,
            .range => |r| rand.intRangeAtMost(usize, r.floor, r.ceiling),
        };
    }
};

pub const Instruction = union(enum) {
    work: Work,
    io: Work,
};

pub const Task = struct {
    pc: usize = 0,
    time: usize,
    instructions: []Instruction,

    pub fn init(instructions: []Instruction) Task {
        const self = Task{
            .time = 0,
            .instructions = instructions,
        };

        switch (self.instructions[self.pc]) {
            .work => |w| {
                self.time = w.resolve();
            },
            else => {},
        }
    }

    pub fn advance(self: *Task) ?Instruction {
        _ = self;

        return null;
    }
};

pub const Simulator = struct {
    tasks: std.ArrayList(Task),
    waiting: std.ArrayList(struct { id: usize, time: usize }),
    ready: std.ArrayList(usize),

    curr: usize = 0,
    time_left: usize = DELTA,

    pub fn register(alloc: std.mem.Allocator, self: *Simulator, task: Task) !void {
        try self.tasks.append(alloc, task);
    }

    fn update_waiting(self: *Simulator, alloc: std.mem.Allocator) !void {
        var i: usize = self.waiting.items.len;
        while (i > 0) {
            i -= 1;

            self.waiting.items[i].time -= 1;

            if (self.waiting.items[i].time == 0) {
                const finished = self.waiting.swapRemove(i);
                try self.ready.append(alloc, finished.id);
            }
        }
    }

    fn getCurr(self: *Simulator) *Task {
        return self.tasks.items[self.curr];
    }

    pub fn tick(self: *Simulator) void {
        // Update all IO waiting queues
        self.update_waiting();

        const next = self.getCurr().advance();
        self.time_left -= 1;

        if (self.time_left == 0) {
            // Do a preemption yield
        } else if (next) |instr| {
            if (instr == .io) {
                // Do an IO yield
            }
        }
    }
};

test "range resolve" {
    const w = Work{ .range = .{ .floor = 2, .ceiling = 5 } };

    const val = w.resolve();

    std.debug.print("{}\n", .{val});

    try std.testing.expect(val >= 2);
    try std.testing.expect(val <= 5);
}
