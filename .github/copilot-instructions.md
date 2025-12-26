# package-version-info - AI Agent Instructions

## Project Overview

A Zig library (`version_info` module) with CLI executable that generates TypeScript version information files from package.json. Demonstrates Zig's dual library+executable pattern with minimal NPM integration for metadata only - this is NOT a Node.js project.

### Core Functionality

- Reads version from `package.json`
- Generates ISO 8601 timestamps
- Extracts git information (branch and commit hash) from `.git` folder
- Outputs TypeScript file with `VERSION_INFO` constant
- Handles non-git repositories gracefully (optional git info)

## Architecture

### Dual-Module Structure

- **Library module** ([src/root.zig](../src/root.zig)): Public API via `version_info` module
  - Entry point for consumers using `@import("version_info")`
  - Public functions: `printVersion()`, `generateVersionInfo()`, `getGitInfo()`
  - Only public declarations in root.zig are accessible to external code
- **Executable** ([src/main.zig](../src/main.zig)): CLI wrapper that imports and uses the library
  - Parses command-line arguments (`--version`, `--input`, `--output`)
  - Delegates to library functions
  - Separate business logic from CLI concerns

This separation allows consumers to either:

1. Use as a library by importing the `version_info` module
2. Use as a standalone CLI tool via `zig-out/bin/version_info`

## Development Workflows

### Build System (Zig)

```bash
# Build executable (output: zig-out/bin/version_info)
zig build

# Run executable directly (generates version-info.ts)
zig build run

# Run with arguments
zig build run -- --input package.json --output version-info.ts
zig build run -- --version

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

## Core Implementation Details

### Git Information Reading

- Reads `.git/HEAD` to determine current branch reference
- Parses `refs/heads/branch-name` format
- Reads commit hash from `.git/refs/heads/{branch}` file
- Handles detached HEAD state
- Returns `null` if not in a git repository (graceful degradation)

### TypeScript Output Format

```typescript
export const VERSION_INFO = {
  version: "0.0.3",
  date: "2025-12-26T16:00:00.000Z",
  git: {
    branch: "master",
    commit: "324822ac3893dd6159ab8cb4477d45edeacf11f6",
  },
};
```

Git section is **optional** - omitted when not in a git repository.

### Memory Management Patterns

- `getGitInfo()` allocates memory for branch and commit strings
- Caller must free using `allocator.free()` for both fields
- Use explicit cleanup after file writing to avoid use-after-free
- Example pattern:
  ```zig
  const git_info = try getGitInfo(allocator);
  // ... use git_info ...
  if (git_info) |info| {
      allocator.free(info.branch);
      allocator.free(info.commit);
  }
  ```

## Testing

### Test Organization

- Library tests: in [src/root.zig](../src/root.zig)
- Executable tests: in [src/main.zig](../src/main.zig)
- Both test suites run in parallel via `zig build test`

### Testing Git Functionality

- Requires actual `.git` folder for integration testing
- Test null case by running in non-git directory
- Memory leak tests automatically verify proper cleanup

## Conventions

### Memory Management

- Explicit allocator passing (see `std.testing.allocator` usage)
- **Critical**: Always `defer` cleanup or explicit free at appropriate scope
- Avoid `defer` in optional capture blocks - use explicit cleanup after usage
- Zig detects memory leaks in tests automatically

### Output Handling

- `std.debug.print()` → stderr (debugging/logging with colored output)
- `std.fs.File.stdout()` → stdout (actual program output)
- Buffered writers require explicit `.flush()` calls

### Colored Console Output

- Uses ANSI escape codes defined in `Color` struct
- Helper `log()` function for consistent emoji + color formatting
- Example: `log(Color.BRIGHT_GREEN, "✅", "Successfully generated {s}", .{path});`

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

[package.json](../package.json) contains metadata only (author, license, scripts). No Node.js runtime usage.

Scripts are for building/publishing the Zig executable as an NPM package.

### Publishing

- `.paths` in build.zig.zon defines published files (build.zig, build.zig.zon, src/, LICENSE, README.md)
- Binary published via NPM with bin entry pointing to `zig-out/bin/version_info`

## Common Patterns

### Adding New Public Functions

1. Add to [src/root.zig](../src/root.zig) with `pub` keyword
2. Write corresponding `test` block
3. Re-export from root.zig if defined in other files
4. Ensure proper memory management for allocated resources

### Error Handling

- Use `try` for propagating errors
- Catch specific errors with `catch |err|` for graceful degradation
- Return optional types (`?T`) for operations that may fail non-critically
- Example: `getGitInfo()` returns `?GitInfo` and handles `FileNotFound` gracefully

### Creating New Dependencies

Edit [build.zig](../build.zig) `.imports` array in `exe.root_module` or module definitions

## Critical Notes

- Zig build is declarative: mutations to build graph (`b`), not direct compilation
- Test executables test ONE module at a time (requires separate test instances)
- Always specify target when creating modules used in tests
- Optional captures create new variable scope - avoid `defer` within them
- File operations must handle both git and non-git environments gracefully
