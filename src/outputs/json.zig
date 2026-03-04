const std = @import("std");

pub fn toString(allocator: std.mem.Allocator, comptime T: type, instance: T) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    const json_fmt = std.json.fmt(instance, .{ .whitespace = .indent_4 });
    try list.writer(allocator).print("{f}", .{json_fmt});
    return list.toOwnedSlice(allocator);
}
