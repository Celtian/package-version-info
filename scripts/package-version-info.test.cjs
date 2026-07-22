'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { join } = require('node:path');

const { getBinaryPath } = require('../npm/package-version-info.js');

test('resolves every supported platform to its bundled binary', () => {
  const cases = [
    ['darwin', 'arm64', 'darwin-arm64', 'version_info'],
    ['darwin', 'x64', 'darwin-x64', 'version_info'],
    ['linux', 'arm64', 'linux-arm64', 'version_info'],
    ['linux', 'x64', 'linux-x64', 'version_info'],
    ['win32', 'x64', 'win32-x64', 'version_info.exe'],
  ];

  for (const [platform, arch, id, binary] of cases) {
    const expected = join(__dirname, '..', 'npm', 'native', id, binary);
    assert.equal(getBinaryPath(platform, arch, join(__dirname, '..', 'npm')), expected);
  }
});

test('reports unsupported platforms clearly', () => {
  assert.throws(
    () => getBinaryPath('freebsd', 'x64'),
    /Unsupported platform freebsd-x64.*darwin-arm64.*win32-x64/,
  );
});
