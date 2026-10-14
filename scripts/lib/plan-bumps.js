'use strict';

const fs = require('fs');
const { spawnSync } = require('node:child_process');
const { parseExact, highestStable, selectBumps } = require('./versions');

function readDirectDeps(pkg) {
  return {
    ...(pkg.dependencies || {}),
    ...(pkg.devDependencies || {}),
  };
}

function latestSameMajor(name, major) {
  const result = spawnSync(
    'npm',
    ['view', `${name}@${major}`, 'version', '--json'],
    { encoding: 'utf8' },
  );
  if (result.status !== 0) {
    const detail = (result.stderr || result.stdout || '').trim();
    throw new Error(`npm view ${name}@${major} failed: ${detail}`);
  }
  const parsed = JSON.parse(result.stdout);
  return highestStable(parsed);
}

function planFromPackage(pkg) {
  const direct = readDirectDeps(pkg);
  const latestByName = {};
  for (const [name, current] of Object.entries(direct)) {
    const parts = parseExact(current);
    if (!parts) {
      latestByName[name] = null;
      continue;
    }
    latestByName[name] = latestSameMajor(name, parts[0]);
  }
  return selectBumps(direct, latestByName);
}

function main() {
  const pkgPath = process.argv[2];
  if (!pkgPath) {
    console.error('usage: plan-bumps.js <package.json>');
    process.exit(1);
  }
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  const plan = planFromPackage(pkg);
  process.stdout.write(`${JSON.stringify(plan, null, 2)}\n`);
}

if (require.main === module) {
  main();
}

module.exports = { readDirectDeps, planFromPackage };
