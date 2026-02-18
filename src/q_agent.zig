//! Discrete Q-Table Bins for CPU utilization percents

const std = @import("std");

/// Learning Rate
const ALPHA: f32 = 0.1;

/// Discount Factor, importance of future rewards
const GAMMA: f32 = 0.9;

/// Exploration rate, probability we try a random action
const EPSILON: f32 = 0.1;

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
const Action = enum { Shorten, Keep, Lengthen };
const NumActions = @typeInfo(Action).@"enum".fields.len;

q_table: [BUCKETS][NumActions]f32 = std.mem.zeroes([BUCKETS][NumActions]f32),
deltas: [BUCKETS]usize = [_]usize{10} ** BUCKETS,

current_state: usize = 0,
last_action: Action = .Keep,

const QAgent = @This();

pub fn updateDelta(self: *QAgent) void {
    switch (self.last_action) {
        .Shorten => self.deltas[self.current_state] -= 1,
        .Keep => {},
        .Lengthen => self.deltas[self.current_state] += 1,
    }
}

const AVG_DELTA: f32 = 10.0;

pub inline fn distPenalty(self: *QAgent) f32 {
    const f_del: f32 = @floatFromInt(self.deltas[self.current_state]);

    return std.math.pow(f32, f_del - AVG_DELTA, 2);
}

/// How much we want to incorporate the total percentage of time
/// spent NOT being starved
const P_NO_WAIT: f32 = 75;

/// How much we want to punish very high or very low deltas
const P_LARGE_SMALL: f32 = 100;

pub inline fn update(self: *QAgent, cpu: f32, wait: f32, rand: std.Random) usize {
    // TODO: Better reward
    const reward = (P_NO_WAIT * std.math.tan(cpu - wait)) -
        (P_LARGE_SMALL * self.distPenalty());

    const next_state = getStateFromPct(cpu);
    var max_q_next = self.q_table[next_state][0];

    inline for (1..NumActions) |i| {
        if (self.q_table[next_state][i] > max_q_next) {
            max_q_next = self.q_table[next_state][i];
        }
    }

    self.q_table[self.current_state][@intFromEnum(self.last_action)] = ALPHA * (reward + (GAMMA * max_q_next));

    if (rand.float(f32) < EPSILON) {
        // Random exploration
        self.last_action = @enumFromInt(rand.intRangeAtMost(usize, 0, NumActions - 1));
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
}
