const std = @import("std");

pub fn to_csv(name: []const u8, data: []const f32) !void {
    const cwd = std.fs.cwd();

    const file = try cwd.createFile(name, .{});
    defer file.close();

    var file_writer = file.deprecatedWriter();

    try file_writer.writeAll("time,avg_starvation\n");

    var buf: [2048]u8 = undefined;

    for (data, 0..) |starve, i| {
        const write = try std.fmt.bufPrint(&buf, "{},{}\n", .{ i, starve });
        try file_writer.writeAll(write);
    }
}
