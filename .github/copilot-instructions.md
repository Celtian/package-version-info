# package-version-info - AI Agent Instructions

## Project Overview

A Zig library (`version_info` module) with CLI executable, demonstrating Zig's dual library+executable pattern. Minimal NPM integration for metadata only - this is NOT a Node.js project.

## Architecture

### Dual-Module Structure

- **Library module** ([src/root.zig](../src/root.zig)): Public API via `version_info` module
  - Entry point for consumers using `@import("version_info")`
  - Only public declarations in root.zig are accessible to external code
- **Executable** ([src/main.zig](../src/main.zig)): CLI wrapper that imports and uses the library
  - Separate business logic from CLI concerns
  - Root module imports library module as dependency

This separation allows consumers to either:

1. Use as a library by importing the `version_info` module
2. Use as a standalone CLI tool

## Development Workflows

### Build System (Zig)

```bash
# Build executable (output: zig-out/bin/version_info)
zig build

# Run executable directly
zig build run

# Run with arguments
zig build run -- arg1 arg2

# Run all tests (runs both library and executable tests in parallel)
zig build test

# Clean build artifacts
rm -rf zig-cache zig-out
```

### Key Build Concepts

- [build.zig](../build.zig) uses Zig's build graph DSL (not imperative)
- Target and optimization flags: `zig build -Dtarget=... -Doptimize=ReleaseFast`
- Two separate test executables: one for library module, one for executable module
- `b.addModule()` exposes modules to package consumers
- `b.createModule()` creates internal modules (not exposed)

## Testing

### Test Organization

- Library tests: in [src/root.zig](../src/root.zig) (e.g., `test "basic add functionality"`)
- Executable tests: in [src/main.zig](../src/main.zig) (e.g., `test "simple test"`, `test "fuzz example"`)
- Both test suites run in parallel via `zig build test`

### Fuzzing Support

Use `--fuzz` flag for fuzz testing: `zig build test --fuzz`
Example in [src/main.zig](../src/main.zig#L20-L27) shows `std.testing.fuzz()` pattern

## Conventions

### Memory Management

- Explicit allocator passing (see `std.testing.allocator` usage)
- **Critical**: Always `defer` cleanup (e.g., `defer list.deinit(gpa)`)
- Zig detects memory leaks in tests automatically

### Output Handling

- `std.debug.print()` → stderr (debugging)
- `std.fs.File.stdout()` → stdout (actual program output)
- Buffered writers require explicit `.flush()` calls

### Module Imports

```zig
const std = @import("std");
const version_info = @import("version_info");  // Local module
```

## Package Management

### Dependencies

- Managed via [build.zig.zon](../build.zig.zon)
- Add deps: `zig fetch --save <url>`
- Fetch all: `zig build --fetch`
- No dependencies currently configured (see commented example in build.zig.zon)

### Package Identity

- `.fingerprint` in build.zig.zon: **NEVER change** (security/trust implications)
- Regenerate only when forking an abandoned project
- Minimum Zig version: 0.15.2

## Project Metadata

### NPM Integration

[package.json](../package.json) contains metadata only (author, license). No Node.js runtime usage.

### Publishing

- `.paths` in build.zig.zon defines published files (build.zig, build.zig.zon, src/)
- Consider adding LICENSE/README.md to .paths before publishing

## Common Patterns

### Adding New Public Functions

1. Add to [src/root.zig](../src/root.zig) with `pub` keyword
2. Write corresponding `test` block
3. Re-export from root.zig if defined in other files

### Creating New Dependencies

Edit [build.zig](../build.zig) `.imports` array in `exe.root_module` or module definitions

## Critical Notes

- Zig build is declarative: mutations to build graph (`b`), not direct compilation
- Test executables test ONE module at a time (requires separate test instances)
- Always specify target when creating modules used in tests
