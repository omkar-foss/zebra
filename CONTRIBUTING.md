# Contributing to Zebra

Thank you for your interest! I welcome bug reports, feature requests and code contributions.

## Prerequisites

- **Zig Version**: 0.15.2, this is the current supported version for Zebra.
- **IDE**: Preferably use [VSCodium](https://github.com/VSCodium/vscodium) along with [official Zig extension](https://github.com/ziglang/vscode-zig.git).

## Development Workflow

1. **Fork & Clone**: Create your copy of the repository.
2. **Build**: Run `make build` to ensure the environment is set up.
3. **Branch**: Create a feature or fix branch
   - Feature branch: `git checkout -b feature/my-new-feature`
   - Fix branch: `git checkout -b fix/my-bug-fix`
4. **Code**: Implement your changes.
5. **Format**: Always run `make format` before committing.
6. **Test**: Ensure all tests pass with `make test`.

## Commit Guidelines

- Use clear and descriptive commit messages.
- Reference any relevant issues (e.g., `Fixes #123`).

## Submitting a PR

- Open a Pull Request against the `main` branch.
- Describe your changes and why they are necessary.
