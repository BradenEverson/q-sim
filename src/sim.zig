//! Main simulation

const std = @import("std");
const t = @import("task.zig");
const Task = t.Task;

pub const Simulator = struct {
    tasks: std.ArrayList(Task) = .{},
    waiting: std.ArrayList(struct { id: usize, time: usize }) = .{},
    ready: std.ArrayList(usize) = .{},

    time: usize = 0,

    curr: usize = 0,
    time_left: usize = 10,

    use_q_learning: bool = false,

    hist: std.ArrayList(f32) = .{},

    pub fn deinit(self: *Simulator, alloc: std.mem.Allocator) void {
        self.tasks.deinit(alloc);
        self.waiting.deinit(alloc);
        self.ready.deinit(alloc);
        self.hist.deinit(alloc);
    }

    pub fn register(self: *Simulator, alloc: std.mem.Allocator, task: Task) !void {
        const idx = self.tasks.items.len;
        try self.tasks.append(alloc, task);
        if (idx != 0) {
            try self.ready.append(alloc, idx);
        }

        std.debug.print("Registered: {}\n", .{idx});
    }

    fn updateStarvation(self: *Simulator) void {
        for (self.ready.items) |r| self.getTask(r).starvation_time += 1;
    }
    fn updateWaitingTime(self: *Simulator) void {
        for (self.waiting.items) |w| self.getTask(w.id).waiting_io_time += 1;
    }

    fn updateWaiting(self: *Simulator, alloc: std.mem.Allocator) !void {
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

    fn getTask(self: *Simulator, idx: usize) *Task {
        return &self.tasks.items[idx];
    }

    fn getCurr(self: *Simulator) *Task {
        return &self.tasks.items[self.curr];
    }

    fn contextSwitch(self: *Simulator) void {
        if (self.ready.items.len == 0) {
            std.debug.print("All jobs waiting on IO\n", .{});
            @panic("TODO: ALL JOBS WAITING ON IO\n");
        } else {
            self.curr = self.ready.swapRemove(0);
            const delta = if (self.use_q_learning)
                self.getCurr().getDelta()
            else
                self.getCurr().getDeltaNoQ();

            self.time_left = delta;

            // const curr = self.getCurr();
            // curr.running_time = 0;
            // curr.waiting_io_time = 0;
        }
    }

    pub fn avgStarvation(self: *const Simulator) f32 {
        var starvation: f32 = 0.0;
        const time: f32 = @floatFromInt(self.time);

        for (self.tasks.items) |task| {
            const starve: f32 = @floatFromInt(task.starvation_time);
            starvation += starve / time;
        }

        const n: f32 = @floatFromInt(self.tasks.items.len);
        return starvation / n;
    }

    pub fn summarize(self: *const Simulator) void {
        var starvation: usize = 0;
        const time: f32 = @floatFromInt(self.time);
        std.debug.print("+---------------+-----------------------+-----------------------+\n", .{});
        std.debug.print("|\tTask\t|\tStarvation\t|\tCPU Runtime\t|\n", .{});
        std.debug.print("+---------------+-----------------------+-----------------------+\n", .{});
        for (self.tasks.items, 0..) |task, idx| {
            const starvation_f: f32 = @floatFromInt(task.starvation_time);

            starvation += task.starvation_time;

            std.debug.print("|\t{}\t", .{idx});
            std.debug.print("|\t{:.2}\t\t|", .{starvation_f / time});
            task.printAvgCpuTime();
            std.debug.print("\t|\n", .{});
            std.debug.print("+---------------+-----------------------+-----------------------+\n", .{});
        }

        for (self.tasks.items) |task| {
            std.debug.print("{any}\n", .{task.agent.deltas});
        }

        var avg_starve: f32 = @floatFromInt(starvation);
        const len: f32 = @floatFromInt(self.tasks.items.len);
        avg_starve /= len;

        std.debug.print("\nAverage Task Starvation: {:.2}\n", .{avg_starve / time});
    }

    pub fn tick(self: *Simulator, alloc: std.mem.Allocator) !void {
        // Update metrics

        self.time += 1;

        self.getCurr().running_time += 1;

        self.updateStarvation();
        try self.hist.append(alloc, self.avgStarvation());

        self.updateWaitingTime();

        // Update all IO waiting queues
        try self.updateWaiting(alloc);

        const next = self.getCurr().advance();
        self.time_left -= 1;

        if (self.time_left == 0) {
            try self.ready.append(alloc, self.curr);
            self.contextSwitch();
        } else if (next) |instr| {
            if (instr == .io) {
                // Do an IO yield
                const time = instr.io.resolve();
                try self.waiting.append(alloc, .{ .id = self.curr, .time = time });
                self.contextSwitch();
            }
        }
    }
};
