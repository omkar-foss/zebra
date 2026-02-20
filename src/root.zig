const std = @import("std");

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
        found_val = try findInDotenvFile(allocator, dotenv_path, field.name);
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

pub fn deinit(allocator: std.mem.Allocator, config: anytype) void {
    const T = @TypeOf(config);
    inline for (std.meta.fields(T)) |field| {
        if (field.type == []const u8) {
            allocator.free(@field(config, field.name));
        } else if (field.type == ?[]const u8) {
            if (@field(config, field.name)) |slice| {
                allocator.free(slice);
            }
        }
    }
}

pub fn deinitMap(allocator: std.mem.Allocator, map: *std.StringHashMap([]const u8)) void {
    var it = map.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    map.deinit();
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

pub fn loadDotenvAsMap(allocator: std.mem.Allocator, path: []const u8) !std.StringHashMap([]const u8) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer deinitMap(allocator, &map);

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

fn findInDotenvFile(allocator: std.mem.Allocator, path: ?[]const u8, target_key: ?[]const u8) !?[]const u8 {
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

pub fn writeJson(instance: anytype, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [0]u8 = undefined;
    var w = file.writer(&write_buf);

    try std.json.Stringify.value(instance, .{
        .whitespace = .indent_4,
    }, &w.interface);

    try w.interface.flush();
}

pub fn printJson(comptime T: type, instance: T) !void {
    const stdout = std.fs.File.stdout();
    var buf: [4096]u8 = undefined;
    var w = stdout.writerStreaming(&buf);
    try std.json.Stringify.value(
        instance,
        .{ .whitespace = .indent_4 },
        &w.interface,
    );
    try w.interface.writeByte('\n');
    try w.interface.flush();
}
