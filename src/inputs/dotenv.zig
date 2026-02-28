const std = @import("std");
const utils = @import("utils.zig");
const cleanup = @import("../utils/cleanup.zig");

pub fn loadAsMap(allocator: std.mem.Allocator, path: []const u8) !std.StringHashMap([]u8) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var map = std.StringHashMap([]u8).init(allocator);
    errdefer cleanup.deinitMap(allocator, &map);

    var file_buf: [1024]u8 = undefined;
    var reader_wrapper = file.reader(&file_buf);
    const reader = &reader_wrapper.interface;

    while (reader.takeDelimiterInclusive('\n')) |reader_line| {
        var line = std.mem.trim(u8, reader_line, " \r\t\n");
        if (line.len == 0 or line[0] == '#') continue;

        const kw_export = "export ";
        if (std.mem.startsWith(u8, line, kw_export)) {
            line = std.mem.trim(u8, line[kw_export.len..], " ");
        }

        const index = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        {
            const raw_key = std.mem.trim(u8, line[0..index], " ");
            const key = try allocator.dupe(u8, raw_key);
            errdefer allocator.free(key);

            var raw_val = try utils.sanitizeValue(allocator, std.mem.trim(u8, line[index + 1 ..], " "));
            defer allocator.free(raw_val);

            var val: []u8 = undefined;
            if (std.mem.lastIndexOfScalar(u8, raw_val, '#')) |hash_idx| {
                val = try utils.sanitizeValue(allocator, std.mem.trim(u8, raw_val[0..hash_idx], " "));
            } else {
                val = try allocator.dupe(u8, raw_val);
            }
            errdefer allocator.free(val);

            const mapVal = try map.getOrPut(key);
            if (mapVal.found_existing) {
                allocator.free(key);
                const old_val = mapVal.value_ptr.*;
                mapVal.value_ptr.* = val;
                allocator.free(old_val);
            } else {
                mapVal.value_ptr.* = val;
            }
        }
    } else |err| {
        if (err != error.EndOfStream) return err;
    }

    return map;
}
