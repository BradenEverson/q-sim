//! Task definition

const std = @import("std");

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
