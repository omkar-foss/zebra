const std = @import("std");

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
