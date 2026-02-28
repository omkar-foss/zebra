![Zebra](images/zebra.jpg)
**Image courtesy:** [Pixabay](https://pixabay.com/photos/zebra-zebra-herd-black-and-white-9576710/)

# Zebra ![Zig](https://img.shields.io/badge/Zig-%23F7A41D.svg?style=for-the-badge&logo=zig&logoColor=white)

A zero dependency all-in-one config loader for Zig. Supports reading dotenv, toml,
yaml and os env.

## Design

- Inspired by the wonderful [viper (golang)](https://github.com/spf13/viper). No fangs, although we have stripes! 🦓
- Built to adhere to the [Zen of Zig](https://ziglang.org/documentation/0.15.2/#Zen).
- Reads multiple config files and write into a single, unified json file
- Has no external dependencies, all loaders are native to zebra's code.
- Extensive tests to ensure zebra is compliant with file format standards.

## Usage

### Installation
- Fetch zebra as a dependency to your Zig project:

```bash
zig fetch --save "git+https://github.com/omkar-foss/zebra#main"
```

- In builg.zig, add zebra as a module dependency:

```zig
const zebra = b.dependency("zebra", .{
    .target = target,
    .optimize = optimize,
});
```

### Loading toml file as a map

Sample main:
```zig
const std = @import("std");
const zebra = @import("zebra");

pub fn main() !void {
    const allocator = std.testing.allocator;

    // load your toml file as a map (key value pairs)
    var cfg = try zebra.toml.loadAsMap(allocator, "env_test.toml");
    defer zebra.cleanup.deinitMap(allocator, &cfg);
}
```


## Thoughts on AI usage

I strive to abide by the [Not By AI 90% Rule](https://notbyai.fyi/not-by-ai-90-rule):

[![NotByAI](https://notbyai.fyi/img/written-by-human-not-by-ai-white.svg)](https://notbyai.fyi/)
