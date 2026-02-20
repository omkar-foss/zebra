const std = @import("std");
const dotenv = @import("dotenv.zig");

fn getFieldValueOwned(allocator: std.mem.Allocator, field: anytype, dotenv_path: ?[]const u8) !?[]const u8 {
    var found_val: ?[]const u8 = null;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Command-line flags (e.g. --port 3000)
    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "--" ++ field.name)) {
            if (i + 1 < args.len) found_val = try allocator.dupe(u8, args[i + 1]);
            break;
        }
    }

    // OS environment
    if (found_val == null) {
        found_val = std.process.getEnvVarOwned(allocator, field.name) catch null;
    }

    // .env File
    if (found_val == null) {
        found_val = try dotenv.findInFile(allocator, dotenv_path, field.name);
    }

    return found_val;
}

pub fn loadAll(comptime T: type, allocator: std.mem.Allocator, dotenv_path: ?[]const u8) !T {
    var result: T = undefined;
    var found_val: ?[]const u8 = null;
    inline for (std.meta.fields(T)) |field| {
        found_val = try getFieldValueOwned(allocator, field, dotenv_path);
        if (found_val) |val| {
            defer allocator.free(val);
            @field(result, field.name) = switch (field.type) {
                []const u8 => try allocator.dupe(u8, val),
                u16 => try std.fmt.parseInt(u16, val, 10),
                bool => std.mem.eql(u8, val, "true"),
                else => @compileError("Unsupported type"),
            };
        } else if (field.default_value_ptr) |ptr| {
            const default = @as(*const field.type, @ptrCast(@alignCast(ptr))).*;
            @field(result, field.name) = default;
        } else {
            return error.MissingConfiguration;
        }
    }
    return result;
}

pub fn ManagedAllocator(comptime T: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        value: T,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
        }
    };
}

pub fn loadAllManaged(comptime T: type, base_allocator: std.mem.Allocator, dotenv_path: ?[]const u8) !ManagedAllocator(T) {
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    errdefer arena.deinit();
    const allocator = arena.allocator();
    const cfg = try loadAll(T, allocator, dotenv_path);
    return ManagedAllocator(T){
        .arena = arena,
        .value = cfg,
    };
}
