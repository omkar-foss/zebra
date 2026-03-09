const std = @import("std");
pub const core = @import("inputs/core.zig");
pub const cleanup = @import("utils/cleanup.zig");
pub const dotenv = @import("inputs/dotenv.zig");
pub const toml = @import("inputs/toml.zig");
pub const yaml = @import("inputs/yaml.zig");
pub const outputs = @import("outputs/outputs.zig");

pub fn Config(comptime T: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        map: ?std.StringHashMap([]const u8),
        data: ?T,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .map = null,
                .data = null,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.data) |*d| {
                cleanup.deinit(self.allocator, d.*);
            }
            if (self.map != null) {
                cleanup.deinitMap(self.allocator, &self.map.?);
            }
        }

        pub fn loadAsMap(self: *Self, paths: []const []const u8) !std.StringHashMap([]u8) {
            self.map = try core.loadAsMap(self.allocator, paths);
            return self.map;
        }

        pub fn loadAsStruct(self: *Self, paths: []const []const u8) !T {
            self.data = try core.loadAsStruct(T, self.allocator, paths);
            return self.data.?;
        }

        pub fn getMapField(self: *Self, comptime FT: type, key: []const u8) !?FT {
            return core.getMapField(FT, self.map, key);
        }
    };
}
