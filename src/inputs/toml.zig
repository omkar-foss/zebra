const std = @import("std");
const utils = @import("utils.zig");

pub fn loadAsMap(allocator: std.mem.Allocator, path: []const u8) !std.StringHashMap([]u8) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(source);

    var map = std.StringHashMap([]u8).init(allocator);
    errdefer {
        var it = map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        map.deinit();
    }

    var array_counters = std.StringHashMap(usize).init(allocator);
    defer {
        var it = array_counters.iterator();
        while (it.next()) |entry| allocator.free(entry.key_ptr.*);
        array_counters.deinit();
    }

    var current_table_prefix: ?[]u8 = null;
    defer if (current_table_prefix) |p| allocator.free(p);

    var lines = std.mem.tokenizeAny(u8, source, "\r\n");
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t");
        if (line.len == 0 or line[0] == '#') continue;

        if (line[0] == '[' and line[line.len - 1] == ']') {
            if (current_table_prefix) |p| allocator.free(p);

            if (std.mem.startsWith(u8, line, "[[") and std.mem.endsWith(u8, line, "]]")) {
                const header = std.mem.trim(u8, line[2 .. line.len - 2], " \t");

                const mapVal = try array_counters.getOrPut(header);
                if (!mapVal.found_existing) {
                    mapVal.key_ptr.* = try allocator.dupe(u8, header);
                    mapVal.value_ptr.* = 0;
                } else {
                    mapVal.value_ptr.* += 1;
                }

                current_table_prefix = try std.fmt.allocPrint(allocator, "{s}.{d}", .{ header, mapVal.value_ptr.* });
            } else {
                const header = std.mem.trim(u8, line[1 .. line.len - 1], " \t");
                current_table_prefix = try allocator.dupe(u8, header);
            }
        } else if (std.mem.indexOf(u8, line, "=")) |eq_idx| {
            const raw_key = std.mem.trim(u8, line[0..eq_idx], " \t");
            const raw_val = std.mem.trim(u8, line[eq_idx + 1 ..], " \t");

            const full_key = if (current_table_prefix) |prefix|
                try std.fmt.allocPrint(allocator, "{s}.{s}", .{ prefix, raw_key })
            else
                try allocator.dupe(u8, raw_key);

            const clean_val = try utils.sanitizeValue(allocator, raw_val);

            const mapVal = try map.getOrPut(full_key);
            if (mapVal.found_existing) {
                allocator.free(full_key);
                allocator.free(mapVal.value_ptr.*);
            }
            mapVal.value_ptr.* = clean_val;
        }
    }

    return map;
}
