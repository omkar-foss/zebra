const std = @import("std");

pub fn loadAsMap(allocator: std.mem.Allocator, path: []const u8) !std.StringHashMap([]u8) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);

    var map = std.StringHashMap([]u8).init(allocator);
    errdefer {
        var it = map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        map.deinit();
    }

    var lines = std.mem.splitScalar(u8, buffer, '\n');
    var stack = std.ArrayList([]const u8){};
    defer stack.deinit(allocator);

    var indent_levels = std.ArrayList(usize){};
    defer indent_levels.deinit(allocator);

    while (lines.next()) |raw_line| {
        var it = std.mem.splitSequence(u8, raw_line, "#");
        const line = std.mem.trim(u8, it.first(), " \t\r\n");
        if (line.len == 0) continue;

        const current_indent = blk: {
            var count: usize = 0;
            for (raw_line) |char| {
                if (char == ' ') count += 1 else if (char == '\t') count += 4 else break;
            }
            break :blk count;
        };

        while (indent_levels.items.len > 0 and current_indent <= indent_levels.getLast()) {
            _ = indent_levels.pop();
            if (stack.pop()) |popped_key| {
                allocator.free(popped_key);
            }
        }

        if (std.mem.indexOfScalar(u8, line, ':')) |sep_idx| {
            const key = std.mem.trim(u8, line[0..sep_idx], " \"'");
            const value = std.mem.trim(u8, line[sep_idx + 1 ..], " \"'");

            if (value.len == 0) {
                try stack.append(allocator, try allocator.dupe(u8, key));
                try indent_levels.append(allocator, current_indent);
            } else {
                const full_key = try buildDotKey(allocator, stack.items, key);
                const value_copy = try allocator.dupe(u8, value);
                const kv = try map.getOrPut(full_key);
                if (kv.found_existing) {
                    allocator.free(kv.value_ptr.*);
                    allocator.free(full_key);
                    kv.value_ptr.* = value_copy;
                } else {
                    kv.key_ptr.* = full_key;
                    kv.value_ptr.* = value_copy;
                }
            }
        }
    }

    for (stack.items) |item| {
        allocator.free(item);
    }
    return map;
}

fn buildDotKey(allocator: std.mem.Allocator, stack: [][]const u8, key: []const u8) ![]u8 {
    var total_len = key.len;
    for (stack) |s| total_len += s.len + 1;

    const result = try allocator.alloc(u8, total_len);
    errdefer allocator.free(result);

    var pos: usize = 0;
    for (stack) |s| {
        @memcpy(result[pos .. pos + s.len], s);
        pos += s.len;
        result[pos] = '.';
        pos += 1;
    }
    @memcpy(result[pos..], key);
    return result;
}
