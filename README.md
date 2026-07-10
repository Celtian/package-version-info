# Package Version Info

[![npm version](https://badge.fury.io/js/package-version-info.svg)](https://badge.fury.io/js/package-version-info)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A blazingly fast CLI tool written in Zig that generates TypeScript version information files from your `package.json`. Perfect for embedding version, build date, and git information into your applications.

## ✨ Features

- 🚀 **Fast**: Written in Zig for maximum performance
- 📦 **Zero Dependencies**: No runtime dependencies required
- 👤 **Author Information**: Extracts author details from package.json
- 🌿 **Git Integration**: Automatically extracts branch and commit information
- ⚡ **TypeScript Output**: Generates type-safe TypeScript constants
- 🎯 **Graceful Degradation**: Works with or without a git repository or author info
- 🔧 **Configurable**: Customize input and output paths

## 🚀 Quick Start

### Installation

```bash
npm install package-version-info --save-dev
# or
yarn add package-version-info --dev
```

### Usage

```bash
# Generate version-info.ts from package.json
npx package-version-info

# Show version
npx package-version-info --version

# Custom paths (.git is the default Git directory)
npx package-version-info --input package.json --output src/version-info.ts --git ../.git

# Short options
npx package-version-info -i package.json -o src/version-info.ts -g ../.git
```

### Output Example

**Full Output (with author and git):**

```typescript
export const VERSION_INFO = {
  version: "1.0.0",
  date: "2025-12-26T16:00:00.000Z",
  author: {
    name: "Dominik Hladík",
    email: "dominik.hladik@seznam.cz",
    url: "https://github.com/Celtian",
  },
  git: {
    branch: "master",
    commit: "324822ac3893dd6159ab8cb4477d45edeacf11f6",
  },
};
```

**Minimal Output (without author and git):**

```typescript
export const VERSION_INFO = {
  version: "1.0.0",
  date: "2025-12-26T16:00:00.000Z",
};
```

## 📖 Usage in Your Application

Once generated, import and use the version info in your application:

```typescript
import { VERSION_INFO } from "./version-info";

console.log(`Version: ${VERSION_INFO.version}`);
console.log(`Build Date: ${VERSION_INFO.date}`);

if (VERSION_INFO.author) {
  console.log(`Author: ${VERSION_INFO.author.name}`);
  console.log(`Email: ${VERSION_INFO.author.email}`);
  console.log(`URL: ${VERSION_INFO.author.url}`);
}

if (VERSION_INFO.git) {
  console.log(`Branch: ${VERSION_INFO.git.branch}`);
  console.log(`Commit: ${VERSION_INFO.git.commit}`);
}
```

## 🔧 CLI Options

| Option      | Alias | Default           | Description                    |
| ----------- | ----- | ----------------- | ------------------------------ |
| `--version` | `-v`  | -                 | Display version information    |
| `--input`   | `-i`  | `package.json`    | Path to package.json file      |
| `--output`  | `-o`  | `version-info.ts` | Path to output TypeScript file |

## 🛠️ Integration with Build Tools

### NPM Scripts

Add to your `package.json`:

```json
{
  "scripts": {
    "prebuild": "package-version-info",
    "build": "your-build-command"
  }
}
```

### With TypeScript Projects

```json
{
  "scripts": {
    "version-info": "package-version-info --output src/version-info.ts",
    "prebuild": "npm run version-info",
    "build": "tsc"
  }
}
```

## 🏗️ Development

This project is written in Zig. To build from source:

### Prerequisites

- [Zig](https://ziglang.org/) >= 0.15.2

### Build Commands

```bash
# Build the executable
zig build

# Run the executable
zig build run

# Run with arguments
zig build run -- --input package.json --output version-info.ts --git .git

# Run tests
zig build test

# Clean build artifacts
rm -rf zig-cache zig-out
```

## 🎯 Why Zig?

- **Performance**: Compiled binary with minimal overhead
- **Size**: Small executable footprint
- **Cross-platform**: Easy to build for multiple platforms
- **Memory Safety**: No runtime exceptions or undefined behavior

## 📦 Dependencies

_None_ - This is a standalone binary with zero runtime dependencies.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 🪪 License

Copyright &copy; 2025 - 2026 [Dominik Hladik](https://github.com/Celtian)

All contents are licensed under the [MIT license](LICENSE).
