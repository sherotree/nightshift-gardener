const ms = require('ms');
const semver = require('semver');
const debug = require('debug')('playground');

function formatDuration(value) {
  const text = ms(value);
  debug('formatDuration %s -> %s', value, text);
  return text;
}

function isCompatible(version, range) {
  return semver.satisfies(version, range);
}

if (require.main === module) {
  const raw = process.argv[2] || '1500';
  const value = /^\d+$/.test(raw) ? Number(raw) : raw;
  console.log(formatDuration(value));
}

module.exports = { formatDuration, isCompatible };
