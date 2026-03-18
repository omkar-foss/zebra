![Zebra](images/zebra.jpg)

# Zebra ![Zig](https://img.shields.io/badge/Zig-%23F7A41D.svg?style=for-the-badge&logo=zig&logoColor=white)

A simple, fast, all-in-one config loader for Zig. Supports reading dotenv, toml,
yaml and os env. Supports and tested on Zig 0.15.2.

## Design

- Inspired by the wonderful [viper (golang)](https://github.com/spf13/viper). Stripes instead of
  fangs! 🦓
- Built to adhere to [Zen of Zig](https://ziglang.org/documentation/0.15.2/#Zen).
- Reads multiple config files and write into a single, unified hashmap or struct.
- Zero external dependencies, all loaders are native to zebra's code.
- Extensive tests to ensure zebra is as compliant as possible with file format standards.

## Usage

### Step 1. Install Zebra

- Fetch Zebra as a dependency to your Zig project:

```bash
zig fetch --save "git+https://github.com/omkar-foss/zebra#main"
```

- In your project's `build.zig`, add Zebra as a module dependency by placing below code before `b.installArtifact(exe);`:

```zig
const zebra = b.dependency("zebra", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zebra", zebra.module("zebra"));
```

### Step 2. Load yaml file as a map and print a key in it

To try out below example, copy the file [`env_test.yaml`](env_test.yaml) to your project folder, and then update your `src/main.zig` as follows:

```zig
const std = @import("std");
const zebra = @import("zebra");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var cfg: std.StringHashMap([]u8) = try zebra.core.loadAsMap(allocator, &[_][]const u8{"env.yaml"});
    defer zebra.cleanup.deinitMap(allocator, &cfg);

    std.debug.print("Output: {s}\n", .{cfg.get("person.name.first").?});
}
```

And then run `zig build run`, you'll get the below output:

```bash
$ zig build run
Output: John
```

Refer to [integration.zig](./tests/integration.zig) for detailed usage examples.

## Contributing

I'd really appreciate any help towards making Zebra better from the community. Please check out [CONTRIBUTING.md](CONTRIBUTING.md) to get started!

### Note on AI usage

Automated PRs without clear human oversight will be closed. I welcome the use of AI as a
productivity tool, but all PRs must be authored, reviewed, and justified by a human who takes full
responsibility for the logic, security, and maintenance of the code.
