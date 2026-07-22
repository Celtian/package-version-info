import { readJsonSync, writeFileSync } from 'fs-extra';
import { join, resolve } from 'path';

const distDir = resolve(__dirname, '..', 'dist');
const pkg = readJsonSync(join(distDir, 'package.json'));

pkg.name = '@celtian/package-version-info';
pkg.publishConfig = {
  registry: 'https://npm.pkg.github.com'
};

writeFileSync(join(distDir, 'package.json'), JSON.stringify(pkg, null, 2));

console.log('\x1b[34m', `Package.json in dist/ modified with publishConfig and name.`, '\x1b[0m');
