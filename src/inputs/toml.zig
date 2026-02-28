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
        const line = std.mem.trim(u8, raw_line, " \r\t\n");
        if (line.len == 0 or line[0] == '#') continue;

        // handle table headers [table] and [[array]]
        if (line[0] == '[' and line[line.len - 1] == ']') {
            if (current_table_prefix) |p| allocator.free(p);

            const is_array = std.mem.startsWith(u8, line, "[[") and std.mem.endsWith(u8, line, "]]");
            const header_raw = if (is_array) line[2 .. line.len - 2] else line[1 .. line.len - 1];
            const header = std.mem.trim(u8, header_raw, " \t");

            if (is_array) {
                const mapVal = try array_counters.getOrPut(header);
                if (!mapVal.found_existing) {
                    mapVal.key_ptr.* = try allocator.dupe(u8, header);
                    mapVal.value_ptr.* = 0;
                } else {
                    mapVal.value_ptr.* += 1;
                }
                current_table_prefix = try std.fmt.allocPrint(allocator, "{s}.{d}", .{ header, mapVal.value_ptr.* });
            } else {
                current_table_prefix = try allocator.dupe(u8, header);
            }
        } else if (std.mem.indexOfScalar(u8, line, '=')) |eq_idx| {
            // handle key-value pairs
            const raw_key = std.mem.trim(u8, line[0..eq_idx], " \t");
            const raw_val = std.mem.trim(u8, line[eq_idx + 1 ..], " \t");

            var path_parts = std.ArrayList([]const u8){};
            defer path_parts.deinit(allocator);

            if (current_table_prefix) |p| try path_parts.append(allocator, p);

            // quote splitting for dotted keys: a."b.c".d
            var start: usize = 0;
            var in_quotes: ?u8 = null;
            for (raw_key, 0..) |char, i| {
                if ((char == '"' or char == '\'') and (i == 0 or raw_key[i - 1] != '\\')) {
                    if (in_quotes == char) in_quotes = null else if (in_quotes == null) in_quotes = char;
                }
                if (in_quotes == null and char == '.') {
                    const part = std.mem.trim(u8, raw_key[start..i], " \t\"'");
                    if (part.len > 0) try path_parts.append(allocator, part);
                    start = i + 1;
                }
            }
            const last_part = std.mem.trim(u8, raw_key[start..], " \t\"'");
            if (last_part.len > 0) try path_parts.append(allocator, last_part);

            const full_key = try std.mem.join(allocator, ".", path_parts.items);

            // route to inline table or standard value
            if (std.mem.startsWith(u8, raw_val, "{") and std.mem.endsWith(u8, raw_val, "}")) {
                try explodeInlineTable(allocator, &map, full_key, raw_val[1 .. raw_val.len - 1]);
                allocator.free(full_key);
            } else {
                const processed_val = try utils.sanitizeValue(allocator, raw_val);
                const gop = try map.getOrPut(full_key);
                if (gop.found_existing) {
                    allocator.free(full_key);
                    allocator.free(gop.value_ptr.*);
                }
                gop.value_ptr.* = processed_val;
            }
        }
    }
    return map;
}

/// flattens inline tables into map
fn explodeInlineTable(
    allocator: std.mem.Allocator,
    map: *std.StringHashMap([]u8),
    prefix: []const u8,
    content: []const u8,
) !void {
    var i: usize = 0;
    var start: usize = 0;
    var depth: usize = 0;
    var in_quotes: ?u8 = null; // track if we are inside ' or "

    while (i <= content.len) : (i += 1) {
        const char: u8 = if (i < content.len) content[i] else ','; // comma at end

        // handle quotes to ignore dots/commas inside them
        if ((char == '"' or char == '\'') and (i == 0 or content[i - 1] != '\\')) {
            if (in_quotes == char) {
                in_quotes = null;
            } else if (in_quotes == null) {
                in_quotes = char;
            }
        }
        if (in_quotes != null) continue;

        if (char == '{') depth += 1;
        if (char == '}') depth -= 1;

        // split by comma only at the current nesting level
        if (char == ',' and depth == 0) {
            const pair = std.mem.trim(u8, content[start..i], " \t\r\n");
            if (pair.len > 0) {
                if (std.mem.indexOfScalar(u8, pair, '=')) |eq_idx| {
                    const inner_key = std.mem.trim(u8, pair[0..eq_idx], " \t\"'");
                    const inner_val = std.mem.trim(u8, pair[eq_idx + 1 ..], " \t");
                    const full_key = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ prefix, inner_key });

                    if (std.mem.startsWith(u8, inner_val, "{") and std.mem.endsWith(u8, inner_val, "}")) {
                        try explodeInlineTable(allocator, map, full_key, inner_val[1 .. inner_val.len - 1]);
                        allocator.free(full_key);
                    } else {
                        // store leaf value
                        const processed_val = try utils.sanitizeValue(allocator, inner_val);
                        const map_gop = try map.getOrPut(full_key);
                        if (map_gop.found_existing) {
                            allocator.free(full_key);
                            allocator.free(map_gop.value_ptr.*);
                        }
                        map_gop.value_ptr.* = processed_val;
                    }
                }
            }
            start = i + 1;
        }
    }
}
