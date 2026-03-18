![Zebra](images/zebra.jpg)

# Zebra ![Zig](https://img.shields.io/badge/Zig-%23F7A41D.svg?style=for-the-badge&logo=zig&logoColor=white)

A simple, fast, all-in-one config loader for Zig. Supports reading dotenv, toml,
yaml and os env.

## Design

- Inspired by the wonderful [viper (golang)](https://github.com/spf13/viper). Stripes instead of
  fangs! 🦓
- Built to adhere to [Zen of Zig](https://ziglang.org/documentation/0.15.2/#Zen).
- Reads multiple config files and write into a single, unified hashmap or struct.
- Zero external dependencies, all loaders are native to zebra's code.
- Extensive tests to ensure zebra is as compliant as possible with file format standards.

## Usage

### Installation

- Fetch Zebra as a dependency to your Zig project:

```bash
zig fetch --save "git+https://github.com/omkar-foss/zebra#main"
```

- In build.zig, add Zebra as a module dependency:

```zig
const zebra = b.dependency("zebra", .{
    .target = target,
    .optimize = optimize,
});
```

### Loading a config file as a map

Refer to [integration.zig](./tests/integration.zig) for detailed examples.

## Contributing

I'd really appreciate any help towards making Zebra better from the Zig community. Please check out [CONTRIBUTING.md](CONTRIBUTING.md) to get started!

### Note on AI usage

Automated PRs without clear human oversight will be closed. I welcome the use of AI as a
productivity tool, but all PRs must be authored, reviewed, and justified by a human who takes full
responsibility for the logic, security, and maintenance of the code.
