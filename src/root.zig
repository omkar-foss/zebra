const std = @import("std");

pub fn loadAll(comptime T: type, allocator: std.mem.Allocator, dotenv_path: ?[]const u8) !T {
    var result: T = undefined;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    inline for (std.meta.fields(T)) |field| {
        var found_val: ?[]const u8 = null;

        // Command-line flags (e.g. --port3000)
        for (args, 0..) |arg, i| {
            if (std.mem.eql(u8, arg, "--" ++ field.name)) {
                if (i + 1 < args.len) found_val = args[i + 1];
            }
        }

        // OS environment
        if (found_val == null) {
            found_val = std.process.getEnvVarOwned(allocator, field.name) catch null;
        }

        // .env File
        if (found_val == null and dotenv_path != null) {
            found_val = try findInDotEnv(allocator, dotenv_path.?, field.name);
        }

        // default value
        if (found_val) |val| {
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

fn findInDotEnv(allocator: std.mem.Allocator, path: []const u8, target_key: []const u8) !?[]const u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
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

        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        var iter = std.mem.splitScalar(u8, trimmed, '=');
        const key = std.mem.trim(u8, iter.first(), " ");

        if (std.mem.eql(u8, key, target_key)) {
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
