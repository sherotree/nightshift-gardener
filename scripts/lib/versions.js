'use strict';

// Exact x.y.z only. Prereleases and ranges are refused on purpose.
function parseExact(version) {
  if (typeof version !== 'string') return null;
  const match = version.trim().match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) return null;
  return [Number(match[1]), Number(match[2]), Number(match[3])];
}

function compare(left, right) {
  for (let i = 0; i < 3; i += 1) {
    if (left[i] !== right[i]) return left[i] - right[i];
  }
  return 0;
}

function highestStable(value) {
  const list = Array.isArray(value) ? value : [value];
  let best = null;
  for (const raw of list) {
    const parsed = parseExact(raw);
    if (!parsed) continue;
    if (!best || compare(parsed, best.parsed) > 0) {
      best = { raw, parsed };
    }
  }
  return best ? best.raw : null;
}

function selectBumps(directDeps, latestByName) {
  const bumps = [];
  const skipped = [];

  for (const name of Object.keys(directDeps).sort()) {
    const current = directDeps[name];
    const target = latestByName[name];
    const currentParts = parseExact(current);
    const targetParts = parseExact(target);

    if (!currentParts) {
      skipped.push({
        name,
        current,
        target: target || null,
        reason: 'not an exact x.y.z pin',
      });
      continue;
    }

    if (!targetParts) {
      skipped.push({
        name,
        current,
        target: target || null,
        reason: 'no stable same-major release',
      });
      continue;
    }

    if (currentParts[0] !== targetParts[0]) {
      skipped.push({
        name,
        current,
        target,
        reason: 'major bump refused',
      });
      continue;
    }

    if (compare(targetParts, currentParts) <= 0) {
      skipped.push({
        name,
        current,
        target,
        reason: 'already current',
      });
      continue;
    }

    bumps.push({ name, from: current, to: target });
  }

  return { bumps, skipped };
}

module.exports = {
  parseExact,
  compare,
  highestStable,
  selectBumps,
};
