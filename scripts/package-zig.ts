import { writeFileSync, ensureDirSync } from 'fs-extra';
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

const srcDir = join(__dirname, '..', 'src');
ensureDirSync(srcDir);
writeFileSync(join(srcDir, 'package.json'), JSON.stringify(pkg, null, 2));

console.log('\x1b[34m', 'Package.json in src/ modified.', '\x1b[0m');


