const std = @import("std");

test "cli: --help flag prints the help text" {
    const allocator = std.testing.allocator;
    var child = std.process.Child.init(
        &.{
            "./zebra",
            "--help",
        },
        allocator,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const stdout = try child.stdout.?.readToEndAlloc(
        allocator,
        4096,
    );
    defer allocator.free(stdout);
    const term = try child.wait();

    try std.testing.expectStringStartsWith(
        stdout,
        "Welcome to Zebra!",
    );
    try std.testing.expect(term.Exited == 0);
}

test "cli: -h flag also prints the help text" {
    const allocator = std.testing.allocator;
    var child = std.process.Child.init(
        &.{
            "./zebra",
            "-h",
        },
        allocator,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const stdout = try child.stdout.?.readToEndAlloc(
        allocator,
        4096,
    );
    defer allocator.free(stdout);
    const term = try child.wait();

    try std.testing.expectStringStartsWith(
        stdout,
        "Welcome to Zebra!",
    );
    try std.testing.expect(term.Exited == 0);
}

test "cli: --input flag reads the specified file" {
    const allocator = std.testing.allocator;
    var child = std.process.Child.init(
        &.{ "./zebra", "--input", "env_test.toml" },
        allocator,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const stdout = try child.stdout.?.readToEndAlloc(
        allocator,
        4096,
    );
    defer allocator.free(stdout);
    const term = try child.wait();

    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"127.0.0.1\": \"localhost\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"nested_arrays\": \"[ [ 1, 2 ], [3, 4, 5] ]\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"products.0.name\": \"Hammer\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"AZURE_CLIENT_SECRET\": \"XXXX\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"AWS_SECRET_ACCESS_KEY\": \"XXXX\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"quoted . dot\": \"allowed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"float_inf\": \"inf\"") != null);
    try std.testing.expect(term.Exited == 0);
}

test "cli: -i flag reads the specified file" {
    const allocator = std.testing.allocator;
    var child = std.process.Child.init(
        &.{ "./zebra", "-i", "env_test.toml" },
        allocator,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const stdout = try child.stdout.?.readToEndAlloc(
        allocator,
        4096,
    );
    defer allocator.free(stdout);
    const term = try child.wait();

    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"127.0.0.1\": \"localhost\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"nested_arrays\": \"[ [ 1, 2 ], [3, 4, 5] ]\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"products.0.name\": \"Hammer\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"AZURE_CLIENT_SECRET\": \"XXXX\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"AWS_SECRET_ACCESS_KEY\": \"XXXX\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"quoted . dot\": \"allowed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"float_inf\": \"inf\"") != null);
    try std.testing.expect(term.Exited == 0);
}

test "cli: -k flag only build output json for specific keys from the specified file - case 1 (single key)" {
    const allocator = std.testing.allocator;
    var child = std.process.Child.init(
        &.{ "./zebra", "-i", "env_test.toml", "-k", "float_inf" },
        allocator,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const stdout = try child.stdout.?.readToEndAlloc(
        allocator,
        4096,
    );
    defer allocator.free(stdout);
    const term = try child.wait();

    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"127.0.0.1\": \"localhost\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"nested_arrays\": \"[ [ 1, 2 ], [3, 4, 5] ]\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"products.0.name\": \"Hammer\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"AZURE_CLIENT_SECRET\": \"XXXX\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"AWS_SECRET_ACCESS_KEY\": \"XXXX\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"quoted . dot\": \"allowed\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"float_inf\": \"inf\"") != null);
    try std.testing.expect(term.Exited == 0);
}

test "cli: -k flag only build output json for specific keys from the specified file - case 2 (two keys)" {
    const allocator = std.testing.allocator;
    var child = std.process.Child.init(
        &.{ "./zebra", "-i", "env_test.toml", "-k", "float_inf", "-k", "products.0.name" },
        allocator,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const stdout = try child.stdout.?.readToEndAlloc(
        allocator,
        4096,
    );
    defer allocator.free(stdout);
    const term = try child.wait();

    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"127.0.0.1\": \"localhost\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"nested_arrays\": \"[ [ 1, 2 ], [3, 4, 5] ]\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"AZURE_CLIENT_SECRET\": \"XXXX\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"AWS_SECRET_ACCESS_KEY\": \"XXXX\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"quoted . dot\": \"allowed\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"products.0.name\": \"Hammer\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stdout, "\"float_inf\": \"inf\"") != null);
    try std.testing.expect(term.Exited == 0);
}

test "cli: --input flag without --output flag shows an warning to use STDOUT as default output" {
    const allocator = std.testing.allocator;
    var child = std.process.Child.init(
        &.{ "./zebra", "-i", "env_test.toml" },
        allocator,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const stderr = try child.stderr.?.readToEndAlloc(
        allocator,
        4096,
    );
    defer allocator.free(stderr);
    const term = try child.wait();

    try std.testing.expectStringStartsWith(stderr, "warning: output file isn't specified, defaulting to STDOUT.");
    try std.testing.expect(term.Exited == 0);
}
