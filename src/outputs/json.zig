const std = @import("std");

pub fn toString(allocator: std.mem.Allocator, comptime T: type, instance: T) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    const json_fmt = std.json.fmt(instance, .{ .whitespace = .indent_4 });
    try list.writer(allocator).print("{f}", .{json_fmt});
    return list.toOwnedSlice(allocator);
}

pub fn toStringMap(allocator: std.mem.Allocator, map: anytype, keys: []const []const u8) ![]u8 {
    const JsonMap = std.json.ArrayHashMap([]const u8);
    var json_ready_map = JsonMap{};
    defer json_ready_map.deinit(allocator);

    if (keys.len > 0) {
        for (keys) |key| {
            if (map.get(key)) |value| {
                try json_ready_map.map.put(allocator, key, value);
            }
        }
    } else {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            try json_ready_map.map.put(
                allocator,
                entry.key_ptr.*,
                entry.value_ptr.*,
            );
        }
    }

    return toString(allocator, JsonMap, json_ready_map);
}

pub fn writeToFile(json_string: []const u8, file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{
        .read = false,
        .truncate = true,
        .mode = 0o400,
    });
    defer file.close();

    var write_buffer: [4096]u8 = undefined;
    var buffered_file_writer = file.writer(&write_buffer);
    const writer = &buffered_file_writer.interface;

    try writer.writeAll(json_string);
    try writer.flush();
}
