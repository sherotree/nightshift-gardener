const test = require('node:test');
const assert = require('node:assert/strict');
const { formatDuration, isCompatible } = require('../src/index');

test('formats durations with ms', () => {
  assert.equal(formatDuration(1000), '1s');
  assert.equal(formatDuration(500), '500ms');
  assert.equal(formatDuration('2s'), 2000);
});

test('checks version ranges with semver', () => {
  assert.equal(isCompatible('1.2.3', '^1.0.0'), true);
  assert.equal(isCompatible('2.0.0', '^1.0.0'), false);
});
