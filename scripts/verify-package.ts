import { mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join, resolve } from 'path';
import { spawnSync } from 'child_process';

import { platforms } from './platforms';

const rootDir = resolve(__dirname, '..');
const distDir = join(rootDir, 'dist');
const pkg = JSON.parse(readFileSync(join(distDir, 'package.json'), 'utf8'));

if (pkg.bin?.['package-version-info'] !== 'bin/package-version-info.js') {
  throw new Error('The package bin does not point to the portable launcher.');
}

statSync(join(distDir, 'bin', 'package-version-info.js'));
for (const platform of platforms) {
  statSync(join(distDir, 'bin', 'native', platform.id, platform.binary));
}

const versionResult = spawnSync(
  process.execPath,
  [join(distDir, 'bin', 'package-version-info.js'), '--version'],
  { encoding: 'utf8' },
);
if (versionResult.status !== 0 || !`${versionResult.stdout}${versionResult.stderr}`.includes(`Version: ${pkg.version}`)) {
  throw new Error(`Packaged launcher has incorrect version metadata:\n${versionResult.stdout}${versionResult.stderr}`);
}

const testDir = mkdtempSync(join(tmpdir(), 'package-version-info-package-'));
try {
  writeFileSync(join(testDir, 'package.json'), JSON.stringify({ name: 'smoke-test', version: '1.2.3' }));
  const outputPath = join(testDir, 'version-info.ts');
  const result = spawnSync(
    process.execPath,
    [join(distDir, 'bin', 'package-version-info.js'), '--output', outputPath, '--git', join(testDir, '.git')],
    { cwd: testDir, encoding: 'utf8' },
  );

  if (result.status !== 0) {
    throw new Error(`Packaged launcher failed:\n${result.stdout}${result.stderr}`);
  }

  const generated = readFileSync(outputPath, 'utf8');
  if (!generated.includes('version: "1.2.3"') || generated.includes('git:')) {
    throw new Error('Packaged launcher generated unexpected version information.');
  }
} finally {
  rmSync(testDir, { recursive: true, force: true });
}

console.log('Packaged launcher and all native executables verified.');
