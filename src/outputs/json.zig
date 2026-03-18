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

    for (keys) |key| {
        if (map.get(key)) |value| {
            try json_ready_map.map.put(allocator, key, value);
        }
    }

    return toString(allocator, JsonMap, json_ready_map);
}
