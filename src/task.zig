//! Task definition

const std = @import("std");
const Agent = @import("q_agent.zig");

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
    instructions: []const Instruction,

    running_time: usize = 0,
    waiting_io_time: usize = 0,
    starvation_time: usize = 0,

    agent: Agent = .{},

    pub fn printAvgCpuTime(self: *const Task) void {
        const tot = self.running_time + self.waiting_io_time;

        const tot_f: f32 = @floatFromInt(tot);
        const cpu_f: f32 = @floatFromInt(self.running_time);

        var percent = (cpu_f / tot_f) * 100;
        if (tot_f == 0.0) percent = 100.0;
        std.debug.print("\t{:.2}%\t", .{percent});
    }

    pub fn init(instructions: []const Instruction) Task {
        var self = Task{
            .time = 0,
            .instructions = instructions,
        };

        switch (self.instructions[self.pc]) {
            .work => |w| {
                self.time = w.resolve();
            },
            else => {},
        }

        return self;
    }

    pub fn getDeltaNoQ(self: *Task) usize {
        _ = self;
        return 10;
    }

    pub fn getDelta(self: *Task) usize {
        const tot = self.running_time + self.waiting_io_time;

        const tot_f: f32 = @floatFromInt(tot);
        const cpu_f: f32 = @floatFromInt(self.running_time);
        const wait_f: f32 = @floatFromInt(self.waiting_io_time);

        return self.agent.update(cpu_f / tot_f, wait_f / tot_f, getRand());
    }

    pub fn advance(self: *Task) ?Instruction {
        switch (self.instructions[self.pc]) {
            .work => |_| {
                self.time -= 1;
                if (self.time == 0) {
                    self.pc += 1;
                    if (self.pc >= self.instructions.len) self.pc = 0;
                    switch (self.instructions[self.pc]) {
                        .work => |w| {
                            self.time = w.resolve();
                        },
                        else => {},
                    }

                    return self.instructions[self.pc];
                } else {
                    return null;
                }
            },
            .io => |_| {
                self.pc += 1;
                if (self.pc >= self.instructions.len) self.pc = 0;
                switch (self.instructions[self.pc]) {
                    .work => |w| {
                        self.time = w.resolve();
                    },
                    else => {},
                }

                return self.instructions[self.pc];
            },
        }
    }
};

test "range resolve" {
    const w = Work{ .range = .{ .floor = 2, .ceiling = 5 } };

    const val = w.resolve();

    try std.testing.expect(val >= 2);
    try std.testing.expect(val <= 5);
}
