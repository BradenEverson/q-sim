//! Simulator

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

    pub fn deinit(self: *Simulator, alloc: std.mem.Allocator) void {
        self.tasks.deinit(alloc);
        self.waiting.deinit(alloc);
        self.ready.deinit(alloc);
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
            const delta = self.getCurr().getDelta();
            self.time_left = delta;

            // const curr = self.getCurr();
            // curr.running_time = 0;
            // curr.waiting_io_time = 0;
        }
    }

    pub fn summarize(self: *const Simulator) void {
        std.debug.print("+---------------+-----------------------+-----------------------+\n", .{});
        std.debug.print("|\tTask\t|\tStarvation\t|\tCPU Runtime\t|\n", .{});
        std.debug.print("+---------------+-----------------------+-----------------------+\n", .{});
        for (self.tasks.items, 0..) |task, idx| {
            std.debug.print("|\t{}\t", .{idx});
            std.debug.print("|\t{}\t\t|", .{task.starvation_time});
            task.printAvgCpuTime();
            std.debug.print("\t|\n", .{});
            std.debug.print("+---------------+-----------------------+-----------------------+\n", .{});
        }
    }

    pub fn tick(self: *Simulator, alloc: std.mem.Allocator) !void {
        // Update metrics

        self.time += 1;

        self.getCurr().running_time += 1;
        self.updateStarvation();
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
