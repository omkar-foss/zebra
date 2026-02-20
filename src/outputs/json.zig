const std = @import("std");

pub fn writeJson(instance: anytype, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [0]u8 = undefined;
    var w = file.writer(&write_buf);

    try std.json.Stringify.value(instance, .{
        .whitespace = .indent_4,
    }, &w.interface);

    try w.interface.flush();
}

pub fn printJson(comptime T: type, instance: T) !void {
    const stdout = std.fs.File.stdout();
    var buf: [4096]u8 = undefined;
    var w = stdout.writerStreaming(&buf);
    try std.json.Stringify.value(
        instance,
        .{ .whitespace = .indent_4 },
        &w.interface,
    );
    try w.interface.writeByte('\n');
    try w.interface.flush();
}
