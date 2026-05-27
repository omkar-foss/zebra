const std = @import("std");
const zebra = @import("root.zig");

const CliArgs = struct {
    inputs: std.ArrayList([]const u8),
    output: ?[]const u8,
    keys: std.ArrayList([]const u8),
};

fn logToStdOut(contents: []const u8) !void {
    var buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;
    try stdout.print("{s}\n", .{contents});
    try stdout.flush();
}

fn printHelp() !void {
    try logToStdOut(
        \\Welcome to Zebra! Just a striped config costume for Zig 🦓
        \\
        \\Usage:
        \\  zebra --input <file1> [--input <file2> ...] [--output <file> | STDOUT] [--key KEY_1 --key KEY_2 ...]
        \\
        \\Options:
        \\  -i, --input <file>     input file(s), at least one required
        \\  -o, --output <file>    json output file, defaults to STDOUT
        \\  -k, --key              key(s) to include, defaults to all keys
        \\  -h, --help             Show this help message
        \\
        \\Example:
        \\  zebra --input service1.toml --input .env.service2 --output services.json
        \\
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip executable name
    _ = args.skip();

    var cli = CliArgs{ .inputs = std.ArrayList([]const u8){}, .output = null, .keys = std.ArrayList([]const u8){} };
    defer {
        cli.inputs.deinit(allocator);
        cli.keys.deinit(allocator);
    }

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printHelp();
            return;
        } else if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
            const value = args.next() orelse {
                std.log.err("missing value for --input\n", .{});
                try printHelp();
                std.process.exit(1);
            };
            try cli.inputs.append(allocator, value);
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            const value = args.next() orelse {
                std.log.err("missing value for --output\n", .{});
                try printHelp();
                std.process.exit(1);
            };
            cli.output = value;
        } else if (std.mem.eql(u8, arg, "--key") or std.mem.eql(u8, arg, "-k")) {
            const value = args.next() orelse {
                std.log.err("missing value for --key\n", .{});
                try printHelp();
                std.process.exit(1);
            };
            try cli.keys.append(allocator, value);
        } else {
            std.log.err("unknown argument: {s}\n", .{arg});
            try printHelp();
            std.process.exit(1);
        }
    }

    if (cli.inputs.items.len == 0) {
        std.log.err("at least one input file is required\n", .{});
        try printHelp();
        std.process.exit(1);
    }

    var cfg = try zebra.core.loadAsMap(allocator, cli.inputs.items, .{ .unmask = false, .cli_mode = true });
    defer zebra.cleanup.deinitMap(allocator, &cfg);

    const json = try zebra.outputs.json.toStringMap(allocator, cfg, cli.keys.items);
    defer allocator.free(json);

    if (cli.output == null) {
        std.log.warn("output file isn't specified, defaulting to STDOUT.\n", .{});
        try logToStdOut(json);
    } else {
        try zebra.outputs.json.writeToFile(json, cli.output.?);
        std.log.info("output json written to file path: {s}", .{cli.output.?});
    }
}
