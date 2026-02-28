const std = @import("std");
const dotenv = @import("dotenv.zig");
const osenv = @import("osenv.zig");
const toml = @import("toml.zig");
const yaml = @import("yaml.zig");
const cleanup = @import("../utils/cleanup.zig");

/// Identifies file types and merges them into single configuration struct.
pub fn loadFromMultiple(comptime T: type, allocator: std.mem.Allocator, paths: []const []const u8) !T {
    // init master map to hold all merged values
    var master_map = std.StringHashMap([]const u8).init(allocator);
    defer cleanup.deinitMap(allocator, &master_map);

    // iterate through paths and merge into master_map
    for (paths) |path| {
        const filename = std.fs.path.basename(path);

        var file_map: std.StringHashMap([]u8) = undefined;
        if (std.mem.endsWith(u8, filename, ".toml")) {
            file_map = try toml.loadAsMap(allocator, path);
        } else if (std.mem.endsWith(u8, filename, ".yaml") or std.mem.endsWith(u8, filename, ".yml")) {
            file_map = try yaml.loadAsMap(allocator, path);
        } else if (std.mem.startsWith(u8, filename, ".env")) {
            std.debug.print("Loading dotenv file from path: {s}", .{path});
            file_map = try dotenv.loadAsMap(allocator, path);
        } else {
            continue;
        }

        // merge file_map into master_map
        var iter = file_map.iterator();
        while (iter.next()) |entry| {
            // Take the existing pointers from the file_map
            const key = entry.key_ptr.*;
            const val = entry.value_ptr.*;

            // if master_map already has this key, free the OLD one before overwriting
            if (try master_map.fetchPut(key, val)) |old| {
                allocator.free(old.key);
                allocator.free(old.value);
            }
        }
        file_map.deinit();
    }

    // overwrite with values obtained from os env, as it always takes priority over files
    var osenv_map = try osenv.loadAsMap(allocator);
    defer cleanup.deinitMap(allocator, &osenv_map);
    var osenv_iter = osenv_map.iterator();
    while (osenv_iter.next()) |entry| {
        const new_key = try allocator.dupe(u8, entry.key_ptr.*);
        const new_val = try allocator.dupe(u8, entry.value_ptr.*);

        if (try master_map.fetchPut(new_key, new_val)) |old| {
            allocator.free(old.key);
            allocator.free(old.value);
        }
    }

    // map master_map to the result struct
    var result: T = undefined;

    var initialized = std.meta.fields(T).len;
    _ = &initialized; // silence unused if comptime-known

    inline for (std.meta.fields(T)) |field| {
        if (master_map.get(field.name)) |val| {
            switch (field.type) {
                []const u8 => {
                    const duped = try allocator.dupe(u8, val);
                    errdefer allocator.free(duped);

                    @field(result, field.name) = duped;
                },
                u16 => {
                    @field(result, field.name) =
                        try std.fmt.parseInt(u16, val, 10);
                },
                bool => {
                    @field(result, field.name) =
                        std.mem.eql(u8, val, "true");
                },
                else => @compileError("Unsupported type in struct"),
            }
        } else if (field.default_value_ptr) |ptr| {
            const default =
                @as(*const field.type, @ptrCast(@alignCast(ptr))).*;
            @field(result, field.name) = default;
        } else {
            return error.MissingConfiguration;
        }
    }

    return result;
}
