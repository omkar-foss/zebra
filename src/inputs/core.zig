const std = @import("std");
const dotenv = @import("dotenv.zig");
const osenv = @import("osenv.zig");
const toml = @import("toml.zig");
const yaml = @import("yaml.zig");
const cleanup = @import("../utils/cleanup.zig");
const security = @import("../utils/security.zig");

pub const LoadOpts = struct { unmask: bool = false };

/// Identifies file types and merges them into single configuration string hash map.
pub fn loadAsMap(allocator: std.mem.Allocator, paths: []const []const u8, opts: LoadOpts) !std.StringHashMap([]u8) {
    // init master map to hold all merged values
    var master_map = std.StringHashMap([]u8).init(allocator);

    // iterate through paths and merge into master_map
    for (paths) |path| {
        const filename = std.fs.path.basename(path);

        var file_map: std.StringHashMap([]u8) = undefined;
        if (std.mem.endsWith(u8, filename, ".toml")) {
            file_map = try toml.loadAsMap(allocator, path);
        } else if (std.mem.endsWith(u8, filename, ".yaml") or std.mem.endsWith(u8, filename, ".yml")) {
            file_map = try yaml.loadAsMap(allocator, path);
        } else if (std.mem.startsWith(u8, filename, ".env")) {
            file_map = try dotenv.loadAsMap(allocator, path);
        } else {
            continue;
        }

        // merge file_map into master_map
        var file_map_iter = file_map.iterator();
        while (file_map_iter.next()) |entry| {
            const new_key = try allocator.dupe(u8, entry.key_ptr.*);
            var new_val: []u8 = undefined;
            const keep_masked = opts.unmask == false;
            const isSensitiveKey = try security.isSensitiveKey(new_key);

            if (keep_masked and isSensitiveKey) {
                new_val = try allocator.dupe(u8, "XXXX");
            } else {
                new_val = try allocator.dupe(u8, entry.value_ptr.*);
            }

            if (try master_map.fetchPut(new_key, new_val)) |old| {
                allocator.free(new_key);
                allocator.free(old.value);
            }
        }
        cleanup.deinitMap(allocator, &file_map);
    }

    // overwrite with values obtained from os env, as it always takes priority over files
    var osenv_map = try osenv.loadAsMap(allocator);
    var osenv_iter = osenv_map.iterator();
    while (osenv_iter.next()) |entry| {
        const new_key = try allocator.dupe(u8, entry.key_ptr.*);
        var new_val: []u8 = undefined;
        const keep_masked = opts.unmask == false;
        const isSensitiveKey = try security.isSensitiveKey(new_key);

        if (keep_masked and isSensitiveKey) {
            new_val = try allocator.dupe(u8, "XXXX");
        } else {
            new_val = try allocator.dupe(u8, entry.value_ptr.*);
        }

        if (try master_map.fetchPut(new_key, new_val)) |old| {
            allocator.free(new_key);
            allocator.free(old.value);
        }
    }
    cleanup.deinitMap(allocator, &osenv_map);

    return master_map;
}

/// Identifies file types and merges them into single configuration struct.
pub fn loadAsStruct(comptime T: type, allocator: std.mem.Allocator, paths: []const []const u8, opts: LoadOpts) !T {
    // init master map to hold all merged values
    var master_map = try loadAsMap(allocator, paths, opts);

    // map master_map to the result struct
    var result: T = undefined;

    var initialized = std.meta.fields(T).len;
    _ = &initialized; // silence unused if comptime-known

    inline for (std.meta.fields(T)) |field| {
        if (master_map.get(field.name)) |val| {
            switch (field.type) {
                []const u8 => {
                    @field(result, field.name) = try allocator.dupe(u8, val);
                },
                u16 => {
                    @field(result, field.name) =
                        try std.fmt.parseInt(u16, val, 10);
                },
                bool => {
                    @field(result, field.name) =
                        std.mem.eql(u8, val, "true");
                },
                else => {
                    @compileError("Unsupported type in struct");
                },
            }
        } else if (field.default_value_ptr) |ptr| {
            const default =
                @as(*const field.type, @ptrCast(@alignCast(ptr))).*;
            @field(result, field.name) = default;
        } else {
            std.debug.print("Missing configuration key: {s}\n", .{field.name});
            return error.MissingConfiguration;
        }
    }

    cleanup.deinitMap(allocator, &master_map);

    return result;
}

// Retrieves the map's field by key in specified data type, verified at compiled time.
pub fn getMapField(comptime T: type, map: *std.StringHashMap([]u8), key: []const u8) !?T {
    const map_val_ptr = map.get(key) orelse return null;
    const str: []const u8 = map_val_ptr[0..];
    if (str.len == 0) return null;
    const ti = @typeInfo(T);
    switch (ti) {
        // signed integers (i8, i16, i32, i64, etc.)
        .int => return try std.fmt.parseInt(T, str, 10),

        // floating-point types (f32, f64)
        .float => return try std.fmt.parseFloat(T, str),

        // booleans (true, false, yes, no)
        .bool => {
            if (std.mem.eql(u8, str, "true") or std.mem.eql(u8, str, "yes")) return true;
            if (std.mem.eql(u8, str, "false") or std.mem.eql(u8, str, "no")) return false;
            return error.InvalidBoolString;
        },

        // strings and slices
        .pointer => {
            const ptr_info = ti.pointer;
            // check if pointer points to u8 (i.e., []const u8, []u8, [*]const u8)
            if (ptr_info.child == u8) {
                return str; // Return as string type
            }
            return error.UnsupportedType;
        },

        // u8 arrays (fixed-size byte arrays)
        .array => {
            const array_info = ti.array;
            if (array_info.child == u8) {
                if (str.len != array_info.len) {
                    return error.ArrayLengthMismatch;
                }
                var result: T = undefined;
                @memcpy(&result, str);
                return result;
            }
            return error.UnsupportedType;
        },

        // optional types
        .optional => {
            const optional_info = ti.optional;
            // recursively parse the child type
            const child_result = try getMapField(optional_info.child, map, key);
            return child_result;
        },

        // enums
        .@"enum" => {
            inline for (ti.@"enum".fields) |field| {
                if (std.mem.eql(u8, str, field.name)) {
                    return @enumFromInt(@as(ti.@"enum".tag_type, field.value));
                }
            }
            return error.InvalidEnumValue;
        },

        else => return error.UnsupportedType,
    }
}
