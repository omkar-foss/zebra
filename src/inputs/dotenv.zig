const std = @import("std");
const cleanup = @import("../utils/cleanup.zig");

pub fn loadAsMap(allocator: std.mem.Allocator, path: []const u8) !std.StringHashMap([]const u8) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer cleanup.deinitMap(allocator, &map);

    var file_buf: [1024]u8 = undefined;
    var reader_wrapper = file.reader(&file_buf);
    const reader = &reader_wrapper.interface;

    while (reader.takeDelimiterInclusive('\n')) |line| {
        const trimmed = std.mem.trim(u8, line, " \r\t");
        if (trimmed.len == 0 or trimmed[0] == '#') {
            continue;
        }

        var iter = std.mem.splitScalar(u8, trimmed, '=');
        const raw_key = std.mem.trim(u8, iter.first(), " \n\r\t");
        const raw_val = std.mem.trim(u8, iter.next() orelse "", " \n\r\t");

        const key = try allocator.dupe(u8, raw_key);
        errdefer allocator.free(key);
        const val = try allocator.dupe(u8, raw_val);
        errdefer allocator.free(val);

        try map.put(key, val);
    } else |err| {
        if (err == error.EndOfStream) {
            return map;
        } else return err;
    }

    return map;
}

pub fn findInFile(allocator: std.mem.Allocator, path: ?[]const u8, target_key: ?[]const u8) !?[]const u8 {
    if (path == null or target_key == null) {
        return null;
    }
    const file = std.fs.cwd().openFile(path.?, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close();

    var file_buf: [1024]u8 = undefined;
    var reader_wrapper = file.reader(&file_buf);
    const reader = &reader_wrapper.interface;
    while (reader.takeDelimiterExclusive('\n')) |line| {
        reader.toss(1);

        const trimmed = std.mem.trim(u8, line, " \r\t");

        // this is important to skip commented lines in the file.
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        var iter = std.mem.splitScalar(u8, trimmed, '=');
        const key = std.mem.trim(u8, iter.first(), " ");

        if (std.mem.eql(u8, key, target_key.?)) {
            const val = std.mem.trim(u8, iter.rest(), " \"'");
            return try allocator.dupe(u8, val);
        }
    } else |err| {
        if (err == error.EndOfStream) {
            return null;
        }
        return err;
    }

    return null;
}
