const std = @import("std");
const cleanup = @import("../utils/cleanup.zig");

fn unescapeQuotes(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const has_escaped_quotes = std.mem.indexOfScalar(u8, input, '\\') != null;
    const is_double_quoted = input.len >= 2 and input[0] == '"' and input[input.len - 1] == '"';
    const is_single_quoted = input.len >= 2 and input[0] == '\'' and input[input.len - 1] == '\'';

    if (!has_escaped_quotes) {
        const to_dupe = if (is_double_quoted or is_single_quoted) input[1 .. input.len - 1] else input;
        return try allocator.dupe(u8, to_dupe);
    }

    const value = if (is_double_quoted or is_single_quoted) input[1 .. input.len - 1] else input;
    var result = std.ArrayList(u8){};
    defer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, value.len);
    var idx: usize = 0;
    while (idx < value.len) {
        if (value[idx] == '\\' and idx + 1 < value.len) {
            const next_char = value[idx + 1];
            if (is_double_quoted) {
                const escaped_char = switch (next_char) {
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    '\\' => '\\',
                    '\"' => '\"',
                    '\'' => '\'',
                    else => next_char,
                };
                try result.append(allocator, escaped_char);
            } else {
                if (next_char == '\'') {
                    try result.append(allocator, '\'');
                } else {
                    try result.append(allocator, '\\');
                    try result.append(allocator, next_char);
                }
            }
            idx += 2;
        } else {
            try result.append(allocator, value[idx]);
            idx += 1;
        }
    }
    return try result.toOwnedSlice(allocator);
}

pub fn loadAsMap(allocator: std.mem.Allocator, path: []const u8) !std.StringHashMap([]u8) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var map = std.StringHashMap([]u8).init(allocator);
    errdefer {
        var it = map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        map.deinit();
    }

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

            var raw_val = try unescapeQuotes(allocator, std.mem.trim(u8, line[index + 1 ..], " "));
            defer allocator.free(raw_val);

            var val: []u8 = undefined;
            if (std.mem.lastIndexOfScalar(u8, raw_val, '#')) |hash_idx| {
                val = try unescapeQuotes(allocator, std.mem.trim(u8, raw_val[0..hash_idx], " "));
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
