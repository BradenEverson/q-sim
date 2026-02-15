//! Simulator

const std = @import("std");
const t = @import("task.zig");
const Task = t.Task;

const DELTA: usize = 10;

pub const Simulator = struct {
    tasks: std.ArrayList(Task) = .{},
    waiting: std.ArrayList(struct { id: usize, time: usize }) = .{},
    ready: std.ArrayList(usize) = .{},

    curr: usize = 0,
    time_left: usize = DELTA,

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
        std.debug.print("Context Switch\n", .{});
        std.debug.print("\tFrom: {}\n", .{self.curr});
        self.curr = self.ready.swapRemove(0);
        self.time_left = DELTA;
        std.debug.print("\tTo: {}\n", .{self.curr});
    }

    pub fn tick(self: *Simulator, alloc: std.mem.Allocator) !void {
        // Update metrics

        self.getCurr().running_time += 1;
        self.updateStarvation();
        self.updateWaitingTime();

        // Update all IO waiting queues
        try self.updateWaiting(alloc);

        const next = self.getCurr().advance();
        self.time_left -= 1;

        if (self.time_left == 0) {
            try self.ready.append(alloc, self.curr);
            std.debug.print("Preemptive ", .{});
            self.contextSwitch();
        } else if (next) |instr| {
            if (instr == .io) {
                // Do an IO yield
                try self.waiting.append(alloc, .{ .id = self.curr, .time = instr.io.resolve() });
                std.debug.print("IO ", .{});
                self.contextSwitch();
            }
        }
    }
};
