# Repository Guidance

## Project Overview

- This repository provides a Zig library and CLI that generate TypeScript version information from `package.json`.
- `src/root.zig` contains the public `version_info` library API.
- `src/main.zig` contains the CLI entry point and argument parsing.
- Node.js and Yarn are used for packaging and publishing; the runtime executable is Zig.

## Toolchain

- Use Zig 0.16.0. Prefer ZVM: `zvm install 0.16.0` followed by `zvm use 0.16.0`.
- Use Yarn 1.22.22 with Node.js 24.
- Keep the Zig version synchronized in `build.zig.zon`, `README.md`, and every workflow under `.github/workflows/`.
- When upgrading toolchains, search hidden files too: `rg --hidden '<old-version>' . --glob '!.git/**'`.
- Never change the `build.zig.zon` package fingerprint.
- Do not change package versions, changelogs, tags, or release metadata unless explicitly requested.

## Zig Conventions

- Follow Zig 0.16 APIs and run `zig fmt` on changed Zig files.
- The CLI entry point uses `std.process.Init`; use its allocator and `std.Io`.
- Pass `std.Io` explicitly into public functions that perform filesystem or clock operations.
- Preserve allocator ownership: callers of `getGitInfo` own and must free the returned branch and commit strings.
- Preserve the existing CLI flags, defaults, executable name, colored logging, and generated TypeScript shape unless a task explicitly changes them.
- Git information is optional. A missing Git directory must not prevent TypeScript generation.

## Required Validation

Before handing off any Zig source, build configuration, dependency, packaging script, CI, or toolchain change, MUST run:

```bash
yarn validate
```

- `yarn validate` is the canonical validation command. It runs formatting checks, `zig build`, and `zig build test`.
- MUST run formatting checks on every changed Zig file. Keep `format:check` synchronized when Zig files are added or renamed.
- Run `zig build` separately because `zig build test` does not fully analyze the CLI `main` function.
- Behavior changes MUST include new or updated tests where practical.
- If the global Zig cache is not writable, set `ZIG_GLOBAL_CACHE_DIR` to a directory under `/tmp`.
- For CLI changes, also smoke-test `--version`, generation with a real `.git` directory, and generation with a missing Git directory.
- Write smoke-test output outside the repository so generated artifacts are not accidentally committed.
- Documentation-only changes do not require `yarn validate` unless they change commands, versions, build instructions, or other executable examples.
- MUST NOT weaken, remove, or skip tests merely to make validation pass.
- MUST NOT report a command as passing unless it was actually executed successfully.
- If a required command cannot run, report the exact command, failure, and remaining unverified behavior.

## Working Practices

- Inspect `git status` before editing and preserve unrelated or already-staged user changes.
- Use `rg --hidden` when repository configuration or CI may be involved.
- Keep changes narrowly scoped and update documentation when public APIs or prerequisites change.
- Before every handoff, MUST run `git diff --check` and report every validation command that was executed.
