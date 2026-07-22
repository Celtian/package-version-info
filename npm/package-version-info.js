#!/usr/bin/env node
'use strict';

const { existsSync } = require('node:fs');
const { join } = require('node:path');
const { spawnSync } = require('node:child_process');

const supportedPlatforms = new Map([
  ['darwin-arm64', 'version_info'],
  ['darwin-x64', 'version_info'],
  ['linux-arm64', 'version_info'],
  ['linux-x64', 'version_info'],
  ['win32-x64', 'version_info.exe'],
]);

function getBinaryPath(platform = process.platform, arch = process.arch, baseDir = __dirname) {
  const id = `${platform}-${arch}`;
  const binary = supportedPlatforms.get(id);

  if (!binary) {
    throw new Error(
      `Unsupported platform ${id}. Supported platforms: ${[...supportedPlatforms.keys()].join(', ')}.`,
    );
  }

  return join(baseDir, 'native', id, binary);
}

function resolveBinary(platform = process.platform, arch = process.arch) {
  const id = `${platform}-${arch}`;
  const binaryPath = getBinaryPath(platform, arch);
  if (!existsSync(binaryPath)) {
    throw new Error(`The package is missing its ${id} executable at ${binaryPath}.`);
  }

  return binaryPath;
}

function run(args = process.argv.slice(2)) {
  const binaryPath = resolveBinary();
  const result = spawnSync(binaryPath, args, { stdio: 'inherit' });

  if (result.error) throw result.error;
  if (result.signal) {
    process.kill(process.pid, result.signal);
    return;
  }

  process.exitCode = result.status ?? 1;
}

if (require.main === module) {
  try {
    run();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`package-version-info: ${message}`);
    process.exitCode = 1;
  }
}

module.exports = { getBinaryPath, resolveBinary, run };
