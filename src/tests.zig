const std = @import("std");
const zebra = @import("root.zig");

test "it fetches config properties from the OS environment" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const base_allocator = gpa.allocator();

    const Config = struct { PORT: u16 = 8080, API_KEY: []const u8, IS_DEBUG: bool = false, NODE_ENV: []const u8 };
    var cfg = try zebra.loadAllManaged(Config, base_allocator, null);
    defer cfg.deinit();

    try zebra.printJson(Config, cfg.value);

    try std.testing.expect(cfg.value.PORT == 3000);
    try std.testing.expectEqualStrings(cfg.value.API_KEY, "secret_123");
    try std.testing.expect(cfg.value.IS_DEBUG == true);
    try std.testing.expectEqualStrings(cfg.value.NODE_ENV, "testing");
}

// @TODO: This is a sample test from zig init, need to remove it while adding tests.
test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

// @TODO: This is a sample test from zig init, need to remove it while adding tests.
test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
