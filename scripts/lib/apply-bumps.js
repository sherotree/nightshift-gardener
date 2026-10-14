'use strict';

const fs = require('fs');

function applyBumps(source, bumps) {
  let next = source;
  for (const bump of bumps) {
    const pattern = new RegExp(`("${bump.name}"\\s*:\\s*")${bump.from}(")`);
    if (!pattern.test(next)) {
      throw new Error(`pin ${bump.name}@${bump.from} not found in package.json`);
    }
    next = next.replace(pattern, `$1${bump.to}$2`);
  }
  return next;
}

function main() {
  const pkgPath = process.argv[2];
  const planPath = process.argv[3];
  if (!pkgPath || !planPath) {
    console.error('usage: apply-bumps.js <package.json> <plan.json>');
    process.exit(1);
  }
  const plan = JSON.parse(fs.readFileSync(planPath, 'utf8'));
  const source = fs.readFileSync(pkgPath, 'utf8');
  fs.writeFileSync(pkgPath, applyBumps(source, plan.bumps));
}

if (require.main === module) {
  main();
}

module.exports = { applyBumps };
