const std = @import("std");
const cleanup = @import("../utils/cleanup.zig");

pub fn loadAsMap(allocator: std.mem.Allocator) !std.StringHashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer cleanup.deinitMap(allocator, &map);

    // 1. load os environment variables
    {
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();

        var env_iter = env_map.iterator();
        while (env_iter.next()) |entry| {
            const raw_k = entry.key_ptr.*;
            const raw_v = entry.value_ptr.*;

            if (map.getEntry(raw_k)) |existing| {
                const old_v = existing.value_ptr.*;
                existing.value_ptr.* = try allocator.dupe(u8, raw_v);
                allocator.free(old_v);
            } else {
                const k = try allocator.dupe(u8, raw_k);
                errdefer allocator.free(k);
                const v = try allocator.dupe(u8, raw_v);
                try map.put(k, v);
            }
        }
    }

    // 2. load cli flags
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.startsWith(u8, args[i], "--")) {
            const raw_k = args[i][2..];
            if (i + 1 < args.len) {
                const raw_v = args[i + 1];

                if (map.getEntry(raw_k)) |existing| {
                    // overwriting os env with cli flag
                    const old_v = existing.value_ptr.*;
                    existing.value_ptr.* = try allocator.dupe(u8, raw_v);
                    allocator.free(old_v);
                } else {
                    // new entry from cli
                    const k = try allocator.dupe(u8, raw_k);
                    errdefer allocator.free(k);
                    const v = try allocator.dupe(u8, raw_v);
                    try map.put(k, v);
                }
                i += 1;
            }
        }
    }
    return map;
}
