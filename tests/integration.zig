const std = @import("std");
const zebra = @import("zebra");

test "it fetches config properties from the OS environment with a user-managed allocator" {
    const allocator = std.testing.allocator;

    const Config = struct { PORT: u16 = 8080, API_KEY: []const u8, IS_DEBUG: bool = false, NODE_ENV: []const u8 };
    const cfg = try zebra.loadAll(Config, allocator, null);
    defer zebra.freeConfig(allocator, cfg);

    try std.testing.expect(cfg.PORT == 3000);
    try std.testing.expectEqualStrings(cfg.API_KEY, "secret_123");
    try std.testing.expect(cfg.IS_DEBUG == true);
    try std.testing.expectEqualStrings(cfg.NODE_ENV, "testing");
}

test "it fetches config properties from the OS environment with a zebra-managed arena allocator" {
    const allocator = std.testing.allocator;

    const Config = struct { PORT: u16 = 8080, API_KEY: []const u8, IS_DEBUG: bool = false, NODE_ENV: []const u8 };
    var cfg = try zebra.loadAllManaged(Config, allocator, null);
    defer cfg.deinit();

    try std.testing.expect(cfg.value.PORT == 3000);
    try std.testing.expectEqualStrings(cfg.value.API_KEY, "secret_123");
    try std.testing.expect(cfg.value.IS_DEBUG == true);
    try std.testing.expectEqualStrings(cfg.value.NODE_ENV, "testing");
}
