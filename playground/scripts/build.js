const fs = require('fs');
const path = require('path');
const { formatDuration, isCompatible } = require('../src/index');

if (formatDuration(1000) !== '1s') {
  console.error('build check failed: formatDuration');
  process.exit(1);
}

if (!isCompatible('1.2.3', '^1.0.0')) {
  console.error('build check failed: isCompatible');
  process.exit(1);
}

const dist = path.join(__dirname, '..', 'dist');
fs.mkdirSync(dist, { recursive: true });
fs.copyFileSync(
  path.join(__dirname, '..', 'src', 'index.js'),
  path.join(dist, 'index.js'),
);
console.log('build ok');
