const std = @import("std");
const zebra = @import("zebra");

test "it fetches config properties from the OS environment with a user-managed allocator" {
    const allocator = std.testing.allocator;

    const Config = struct { ZEBRA_TEST_PORT: u16 = 8080, ZEBRA_TEST_API_KEY: []const u8, ZEBRA_TEST_IS_DEBUG: bool = false, ZEBRA_TEST_NODE_ENV: []const u8 };
    const cfg = try zebra.core.loadAll(Config, allocator, null);
    defer zebra.cleanup.deinit(allocator, cfg);

    try std.testing.expect(cfg.ZEBRA_TEST_PORT == 3000);
    try std.testing.expectEqualStrings(cfg.ZEBRA_TEST_API_KEY, "secret_123");
    try std.testing.expect(cfg.ZEBRA_TEST_IS_DEBUG == true);
    try std.testing.expectEqualStrings(cfg.ZEBRA_TEST_NODE_ENV, "testing");
}

test "it fetches config properties from the OS environment with a zebra-managed arena allocator" {
    const allocator = std.testing.allocator;

    const Config = struct { ZEBRA_TEST_PORT: u16 = 8080, ZEBRA_TEST_API_KEY: []const u8, ZEBRA_TEST_IS_DEBUG: bool = false, ZEBRA_TEST_NODE_ENV: []const u8 };
    var cfg = try zebra.core.loadAllManaged(Config, allocator, null);
    defer cfg.deinit();

    try std.testing.expect(cfg.value.ZEBRA_TEST_PORT == 3000);
    try std.testing.expectEqualStrings(cfg.value.ZEBRA_TEST_API_KEY, "secret_123");
    try std.testing.expect(cfg.value.ZEBRA_TEST_IS_DEBUG == true);
    try std.testing.expectEqualStrings(cfg.value.ZEBRA_TEST_NODE_ENV, "testing");
}

test "it loads a dotenv file as a map" {
    const allocator = std.testing.allocator;

    var cfg = try zebra.dotenv.loadAsMap(allocator, ".env_test");
    defer zebra.cleanup.deinitMap(allocator, &cfg);

    try std.testing.expectEqualStrings(cfg.get("ZEBRA_TEST_PORT").?, "3000");
    try std.testing.expectEqualStrings(cfg.get("ZEBRA_TEST_API_KEY").?, "secret_123");
    try std.testing.expectEqualStrings(cfg.get("ZEBRA_TEST_NODE_ENV").?, "testing");
    try std.testing.expectEqualStrings(cfg.get("ZEBRA_TEST_IS_DEBUG").?, "true");
}
