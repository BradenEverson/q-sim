//! Discrete Q-Table Bins for CPU utilization percents
const std = @import("std");

/// Learning Rate
const ALPHA: f32 = 0.001;

/// Discount Factor, importance of future rewards
const GAMMA: f32 = 0.7;

/// Exploration rate, probability we try a random action
const EPSILON: f32 = 0.05;

pub const QAgent = extern struct {
    /// Number of times we split up the CPU utilization percents
    /// into discrete buckets
    /// Ex: 10 buckets gives us 0-10%, 11-20%, ...
    const BUCKETS: usize = 10;
    const BUCKETS_F: f32 = @floatFromInt(BUCKETS);

    pub fn getStateFromPct(cpu_pct: f32) usize {
        const bucket: f32 = cpu_pct * BUCKETS_F;

        const bin: usize = @intFromFloat(bucket);
        if (bin >= BUCKETS) return BUCKETS - 1;
        return bin;
    }

    /// Actions the agent can take
    const Action = enum(u8) { Shorten, Keep, Lengthen };
    const NumActions = @typeInfo(Action).@"enum".fields.len;

    q_table: [BUCKETS][NumActions]f32 = std.mem.zeroes([BUCKETS][NumActions]f32),
    deltas: [BUCKETS]usize = [_]usize{10} ** BUCKETS,

    current_state: usize = 0,
    last_action: Action = .Keep,

    const MIN_DELTA: usize = 5;
    const MAX_DELTA: usize = 200;

    pub fn updateDelta(self: *QAgent) void {
        switch (self.last_action) {
            .Shorten => if (self.deltas[self.current_state] > MIN_DELTA) {
                self.deltas[self.current_state] -= 1;
            },
            .Keep => {},
            .Lengthen => if (self.deltas[self.current_state] < MAX_DELTA) {
                self.deltas[self.current_state] += 1;
            },
        }
    }

    const FAIRNESS_PENALTY: f32 = 10;
    const READY_WAIT_WEIGHT: f32 = 10;

    const B: f32 = 0.5;
    const K: f32 = 0.5;

    pub fn sigmoidPunishment(self: *QAgent) f32 {
        const d: f32 = @floatFromInt(self.deltas[self.current_state]);

        return 1 / (1 + std.math.pow(f32, std.math.e, -1 * (d - 45)));
    }

    pub inline fn exponentialDeltaPunishment(self: *QAgent) f32 {
        const d: f32 = @floatFromInt(self.deltas[self.current_state]);

        return B * std.math.exp(K * (d - 20));
    }

    pub inline fn update(self: *QAgent, cpu: f32, ready_wait: f32, io_wait: f32, avg_sys_wait: f32, num_tasks: f32, rng: std.Random) usize {
        const best_cpu_avg_wait = 1 / num_tasks;

        var reward = cpu - (READY_WAIT_WEIGHT * ready_wait) + io_wait - (FAIRNESS_PENALTY * (avg_sys_wait - best_cpu_avg_wait));

        // const throughput = cpu;
        // const ready_penalty = (ready_wait * ready_wait) * READY_WAIT_WEIGHT;
        // const io_bonus = io_wait * 2.0;
        // const system_pressure = (avg_sys_wait - (1.0 / num_tasks)) * FAIRNESS_PENALTY;
        // var reward = throughput + io_bonus - ready_penalty - system_pressure;

        // var reward = (cpu - ready_wait) + io_wait;

        if (self.last_action != .Shorten) {
            reward -= self.exponentialDeltaPunishment();
        } else if (reward < 10) {
            reward -= 0.5;
        }

        // "Inertia" punishment
        if (self.last_action != .Keep) {
            reward -= 3.75;
        }

        std.debug.print("{} - {}\n", .{ self.last_action, reward });

        const next_state = getStateFromPct(cpu);
        var max_q_next = self.q_table[next_state][0];

        inline for (1..NumActions) |i| {
            if (self.q_table[next_state][i] > max_q_next) {
                max_q_next = self.q_table[next_state][i];
            }
        }

        const curr = self.q_table[self.current_state][@intFromEnum(self.last_action)];
        self.q_table[self.current_state][@intFromEnum(self.last_action)] = curr + ALPHA * (reward + (GAMMA * max_q_next) - curr);

        if (rng.float(f32) < EPSILON) {
            // Random exploration
            self.last_action = @enumFromInt(rng.intRangeAtMost(usize, 0, NumActions - 1));
        } else {
            var best_action: Action = .Keep;
            inline for (1..NumActions) |i| {
                if (self.q_table[next_state][i] > self.q_table[next_state][@intFromEnum(best_action)]) {
                    best_action = @enumFromInt(i);
                }
            }

            self.last_action = best_action;
        }

        self.current_state = next_state;
        self.updateDelta();

        return self.deltas[self.current_state];
        // baseline test:
        // return 10;
    }
};
