const std = @import("std");
const zebra = @import("zebra");

test "it fetches config properties from the OS environment" {
    const allocator = std.testing.allocator;

    const CfgStruct = struct { ZEBRA_TEST_OS_PORT: u16, ZEBRA_TEST_OS_API_KEY: []const u8, ZEBRA_TEST_OS_IS_DEBUG: bool, ZEBRA_TEST_OS_NODE_ENV: []const u8 };

    // let's send an empty paths list just for testing
    var config = zebra.Config(CfgStruct).init(allocator);
    defer config.deinit();

    const loadedCfg = try config.loadAsStruct(&[_][]const u8{});
    try std.testing.expect(loadedCfg.ZEBRA_TEST_OS_PORT == 3000);
    try std.testing.expectEqualStrings(loadedCfg.ZEBRA_TEST_OS_API_KEY, "secret_123");
    try std.testing.expect(loadedCfg.ZEBRA_TEST_OS_IS_DEBUG == true);
    try std.testing.expectEqualStrings(loadedCfg.ZEBRA_TEST_OS_NODE_ENV, "testing");

    const json = try zebra.outputs.json.toString(allocator, CfgStruct, loadedCfg);
    defer std.testing.allocator.free(json);
    const expectedJson =
        \\{
        \\    "ZEBRA_TEST_OS_PORT": 3000,
        \\    "ZEBRA_TEST_OS_API_KEY": "secret_123",
        \\    "ZEBRA_TEST_OS_IS_DEBUG": true,
        \\    "ZEBRA_TEST_OS_NODE_ENV": "testing"
        \\}
    ;
    try std.testing.expectEqualStrings(expectedJson, json);
}

test "it fetches config properties from the OS environment and dotenv file" {
    const allocator = std.testing.allocator;

    const CfgStruct = struct { ZEBRA_TEST_OS_PORT: u16, ZEBRA_TEST_OS_API_KEY: []const u8, ZEBRA_TEST_OS_IS_DEBUG: bool, ZEBRA_TEST_OS_NODE_ENV: []const u8, URL: []const u8 };

    // dotenv test file provided, but os env will overwrite values if any keys are same
    var config = zebra.Config(CfgStruct).init(allocator);
    defer config.deinit();

    const loadedCfg = try config.loadAsStruct(&[_][]const u8{".env.test"});
    try std.testing.expect(loadedCfg.ZEBRA_TEST_OS_PORT == 3000);
    try std.testing.expectEqualStrings(loadedCfg.ZEBRA_TEST_OS_API_KEY, "secret_123");
    try std.testing.expect(loadedCfg.ZEBRA_TEST_OS_IS_DEBUG == true);
    try std.testing.expectEqualStrings(loadedCfg.ZEBRA_TEST_OS_NODE_ENV, "testing");
    try std.testing.expectEqualStrings(loadedCfg.URL, "https://api.example.com/v1?query=test");
}

test "it loads a dotenv file as a map with all edge cases" {
    const allocator = std.testing.allocator;
    var cfg = try zebra.core.loadAsMap(allocator, &[_][]const u8{".env.test"});
    defer zebra.cleanup.deinitMap(allocator, &cfg);

    // 1. whitespace trimming
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
    var cfg = try zebra.core.loadAsMap(allocator, &[_][]const u8{"env_test.toml"});
    defer zebra.cleanup.deinitMap(allocator, &cfg);

    // 1. complex & dotted keys
    try std.testing.expectEqualStrings("value", cfg.get("key").?);
    try std.testing.expectEqualStrings("UTF-8", cfg.get("character.encoding").?);
    // Note: Quoted keys usually retain quotes in the key string to avoid ambiguity
    if (cfg.get("\"127.0.0.1\"")) |val| {
        try std.testing.expectEqualStrings("localhost", val);
    }
    try std.testing.expectEqualStrings("allowed", cfg.get("quoted . dot").?);

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

    // 6. misc tests
    // path merging (a.b.c and [a] d=2 should both exist under 'a')
    try std.testing.expectEqualStrings("1", cfg.get("a.b.c").?);
    try std.testing.expectEqualStrings("2", cfg.get("a.d").?);
    // strings escaping
    try std.testing.expect(std.mem.containsAtLeast(u8, cfg.get("regex").?, 1, "Hello"));
    try std.testing.expectEqualStrings("C:\\Users\\Name\\", cfg.get("literal_path").?);
    try std.testing.expectEqualStrings("", cfg.get("blank").?);
    // numbers
    try std.testing.expectEqualStrings("0xDEAD_BEEF", cfg.get("hex_val").?);
    try std.testing.expectEqualStrings("inf", cfg.get("float_inf").?);
    // arrays
    // most basic loaders flatten arrays or store them as a raw string block
    try std.testing.expect(cfg.get("trailing_arr") != null);
    try std.testing.expect(cfg.get("nested_mixed") != null);
    // inline tables with nesting
    try std.testing.expectEqualStrings("1", cfg.get("inline_point.x").?);
    try std.testing.expectEqualStrings("2", cfg.get("inline_point.y.z").?);

    // 7. simple inline tables
    if (cfg.get("server.port.http")) |port| {
        try std.testing.expectEqualStrings("80", port);
    }

    // 8. array of tables
    // first item of [[products]]
    try std.testing.expectEqualStrings("Hammer", cfg.get("products.0.name").?);
    try std.testing.expectEqualStrings("738594937", cfg.get("products.0.sku").?);
    // second item of [[products]]
    try std.testing.expectEqualStrings("Nail", cfg.get("products.1.name").?);
    try std.testing.expectEqualStrings("gray", cfg.get("products.1.color").?);
}

test "it loads a yaml file as a map with all edge cases" {
    const allocator = std.testing.allocator;

    var cfg: std.StringHashMap([]u8) = try zebra.core.loadAsMap(allocator, &[_][]const u8{"env_test.yaml"});
    defer zebra.cleanup.deinitMap(allocator, &cfg);

    // 1. standard nesting
    try std.testing.expectEqualStrings("John", cfg.get("person.name.first").?);
    try std.testing.expectEqualStrings("Doe", cfg.get("person.name.last").?);
    try std.testing.expectEqualStrings("30", cfg.get("person.age").?);
    try std.testing.expectEqual(30, try zebra.core.getMapField(i64, &cfg, "person.age"));

    // 2. indentation shifts (4-space vs 2-space)
    try std.testing.expectEqualStrings("2026-03-01", cfg.get("metadata.created_at").?);
    try std.testing.expectEqualStrings("true", cfg.get("metadata.tags.internal").?);
    try std.testing.expectEqualStrings("1.0", cfg.get("metadata.tags.version").?);
    try std.testing.expectEqual(1.0, zebra.core.getMapField(f64, &cfg, "metadata.tags.version"));

    // 3. quoted keys and values
    try std.testing.expectEqualStrings("Silicon Valley", cfg.get("company.info").?);
    try std.testing.expectEqualStrings("Active", cfg.get("status").?);

    // 4. inline comments
    try std.testing.expectEqualStrings("Earth", cfg.get("location").?);

    // 5. deep nesting
    try std.testing.expectEqualStrings("value", cfg.get("a.b.c.d").?);

    // 6. empty/null values (parents are not stored as values, only leaves)
    try std.testing.expect(cfg.get("empty_key") == null);
    try std.testing.expectEqualStrings("valid_value", cfg.get("next_key").?);

    // 7. special characters
    try std.testing.expectEqualStrings("/usr/local/bin", cfg.get("path").?);
    try std.testing.expectEqualStrings("https://ziglang.org", cfg.get("url").?);

    // 8. misc tests
    // handling noise and deep nesting
    try std.testing.expectEqualStrings("John", cfg.get("person.name.first").?);
    try std.testing.expectEqualStrings("75", cfg.get("person.details.weight").?);
    try std.testing.expectEqual(75, try zebra.core.getMapField(i16, &cfg, "person.details.weight"));

    // indentation spaghetti
    try std.testing.expectEqualStrings("deep", cfg.get("level1.level2.level3.level4").?);
    try std.testing.expectEqualStrings("value", cfg.get("back_to_one").?);

    // dots inside quotes (should not be split by the parser)
    try std.testing.expectEqualStrings("value.with.dots", cfg.get("quoted.key.with.dots").?);

    // special characters (urls and symbols)
    try std.testing.expectEqualStrings("https://ziglang.org", cfg.get("url_test").?);

    // end value
    try std.testing.expectEqualStrings("last_value", cfg.get("final_key").?);
}
