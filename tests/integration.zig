const std = @import("std");
const zebra = @import("zebra");

test "it fetches config properties from the OS environment with a user-managed allocator" {
    const allocator = std.testing.allocator;

    const Config = struct { ZEBRA_TEST_OS_PORT: u16 = 8080, ZEBRA_TEST_OS_API_KEY: []const u8, ZEBRA_TEST_OS_IS_DEBUG: bool = false, ZEBRA_TEST_OS_NODE_ENV: []const u8 };
    const cfg = try zebra.core.loadAll(Config, allocator, null);
    defer zebra.cleanup.deinit(allocator, cfg);

    try std.testing.expect(cfg.ZEBRA_TEST_OS_PORT == 3000);
    try std.testing.expectEqualStrings(cfg.ZEBRA_TEST_OS_API_KEY, "secret_123");
    try std.testing.expect(cfg.ZEBRA_TEST_OS_IS_DEBUG == true);
    try std.testing.expectEqualStrings(cfg.ZEBRA_TEST_OS_NODE_ENV, "testing");
}

test "it fetches config properties from the OS environment with a zebra-managed arena allocator" {
    const allocator = std.testing.allocator;

    const Config = struct { ZEBRA_TEST_OS_PORT: u16 = 8080, ZEBRA_TEST_OS_API_KEY: []const u8, ZEBRA_TEST_OS_IS_DEBUG: bool = false, ZEBRA_TEST_OS_NODE_ENV: []const u8 };
    var cfg = try zebra.core.loadAllManaged(Config, allocator, null);
    defer cfg.deinit();

    try std.testing.expect(cfg.value.ZEBRA_TEST_OS_PORT == 3000);
    try std.testing.expectEqualStrings(cfg.value.ZEBRA_TEST_OS_API_KEY, "secret_123");
    try std.testing.expect(cfg.value.ZEBRA_TEST_OS_IS_DEBUG == true);
    try std.testing.expectEqualStrings(cfg.value.ZEBRA_TEST_OS_NODE_ENV, "testing");
}

test "it loads a dotenv file as a map with all edge cases" {
    const allocator = std.testing.allocator;

    var cfg = try zebra.dotenv.loadAsMap(allocator, ".env_test");
    defer zebra.cleanup.deinitMap(allocator, &cfg);

    // 1. basic & whitespace trimming
    try std.testing.expectEqualStrings("lowercase basic", cfg.get("basic").?);
    // Note: WITH_SPACE="  val  " -> internal spaces kept, outer quotes removed
    try std.testing.expectEqualStrings("  spaced value  ", cfg.get("WITH_SPACE").?);
    try std.testing.expectEqualStrings("no_quotes_needed", cfg.get("TRIM_TEST").?);

    // 2. delimiter logic (split only at FIRST '=') and empty values
    try std.testing.expectEqualStrings("key=value=extra", cfg.get("MULTIPLE_EQUALS").?);
    try std.testing.expectEqualStrings("https://api.example.com/v1?query=test", cfg.get("URL").?);
    try std.testing.expectEqualStrings("", cfg.get("EMPTY_VAL").?);

    // 3. single quote literalism (no newline conversion, but ' allowed)
    // 'literal\nnewline' -> literal backslash and 'n'
    try std.testing.expectEqualStrings("literal\\nnewline", cfg.get("SINGLE_QUOTE").?);
    try std.testing.expectEqualStrings("It's a string", cfg.get("SQ_ESCAPED").?);
    try std.testing.expectEqualStrings("String with \"double\" quotes", cfg.get("SQ_INTERNAL_DQ").?);

    // 4. double quote interpreted (real newline conversion)
    // "interpreted\nnewline" -> ascii 10
    try std.testing.expectEqualStrings("interpreted\nnewline", cfg.get("DOUBLE_QUOTE").?);
    try std.testing.expectEqualStrings("Contains \"quotes\" and \\ backslashes", cfg.get("DQ_ESCAPED").?);
    try std.testing.expectEqualStrings("String with 'single' quotes", cfg.get("DQ_INTERNAL_SQ").?);

    // 5. comments and invalid lines (should not exist in map)
    try std.testing.expect(cfg.get("# This is a full-line comment") == null);
    try std.testing.expect(cfg.get("STRAY_TEXT_WITHOUT_EQUALS") == null);
    // result should be 'nested' (outer double quotes removed, inner single quotes preserved)
    try std.testing.expectEqualStrings("'nested'", cfg.get("MIXED_QUOTES").?);
    // inline comments
    try std.testing.expectEqualStrings("value", cfg.get("KEY_WITH_COMMENT").?);
    try std.testing.expectEqualStrings("secret#password", cfg.get("KEY_WITH_COMMENT_SECRET").?);

    // 6. case sensitivity (dotenv keys are case-sensitive)
    // So "BASIC" exists, "basic" should not.
    // If file has 'basic=lower', cfg.get("BASIC") should be null or different
    try std.testing.expectEqualStrings("UPPERCASE BASIC", cfg.get("BASIC").?);
    try std.testing.expectEqualStrings("lowercase basic", cfg.get("basic").?);

    // 7. Exported keys
    try std.testing.expectEqualStrings("this is an exported var", cfg.get("EXPORTED_VAR").?);
}

test "it loads a toml file as a map with all edge cases" {
    const allocator = std.testing.allocator;

    var cfg = try zebra.toml.loadAsMap(allocator, "env_test.toml");
    defer zebra.cleanup.deinitMap(allocator, &cfg);

    // 1. complex & dotted keys
    try std.testing.expectEqualStrings("value", cfg.get("key").?);
    try std.testing.expectEqualStrings("UTF-8", cfg.get("character.encoding").?);
    // Note: Quoted keys usually retain quotes in the key string to avoid ambiguity
    if (cfg.get("\"127.0.0.1\"")) |val| {
        try std.testing.expectEqualStrings("localhost", val);
    }

    // 2. string varieties
    // Literal strings (single quotes) should not process escape sequences
    try std.testing.expectEqualStrings("C:\\Users\\Node\\config.ini", cfg.get("literal").?);

    // 3. number formats
    try std.testing.expectEqualStrings("0xDEADBEEF", cfg.get("int_hex").?);
    try std.testing.expectEqualStrings("1_000_000", cfg.get("int_underscores").?);

    // 4. datetimes
    try std.testing.expectEqualStrings("1979-05-27T07:32:00Z", cfg.get("odt").?);

    // 5. standard tables
    try std.testing.expectEqualStrings("10.0.0.1", cfg.get("server.host").?);

    // 6. inline tables (nested dot notation)
    // If parser flattens { http = 80 }, verify the sub-keys
    if (cfg.get("server.port.http")) |port| {
        try std.testing.expectEqualStrings("80", port);
    }

    // 7. array of tables (index-based dot notation)
    // first entry in [[products]]
    try std.testing.expectEqualStrings("Hammer", cfg.get("products.0.name").?);
    try std.testing.expectEqualStrings("738594937", cfg.get("products.0.sku").?);
    // second entry in [[products]]
    try std.testing.expectEqualStrings("Nail", cfg.get("products.1.name").?);
    try std.testing.expectEqualStrings("gray", cfg.get("products.1.color").?);
}
