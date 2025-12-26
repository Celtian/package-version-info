import { ensureDirSync, writeFileSync } from 'fs-extra';
import { join, resolve } from 'path';

const pkg = require(resolve(__dirname, '..', 'package.json'));

pkg.scripts = undefined;
pkg.devDependencies = undefined;
pkg.packageManager = undefined;
pkg.engines = undefined;
pkg.files = undefined;
pkg.bin = {
  "package-version-info": "bin/version_info"
};

pkg.name = '@celtian/ngx-fixed-footer';
pkg.publishConfig = {
  registry: 'https://npm.pkg.github.com'
};

const distDir = join(__dirname, '..', 'dist');
ensureDirSync(distDir);
writeFileSync(join(distDir, 'package.json'), JSON.stringify(pkg, null, 2));

console.log('\x1b[34m', `Package.json in dist/ modified with publishConfig and name.`, '\x1b[0m');
