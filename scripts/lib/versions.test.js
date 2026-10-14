const test = require('node:test');
const assert = require('node:assert/strict');
const { highestStable, selectBumps } = require('./versions');

test('highestStable ignores prereleases and picks the numeric maximum', () => {
  assert.equal(
    highestStable(['1.2.0', '1.10.0', '1.9.0', '1.10.1-rc.1', '2.0.0-beta']),
    '1.10.0',
  );
  assert.equal(highestStable('7.8.5'), '7.8.5');
  assert.equal(highestStable(['1.0.0-rc.1']), null);
});

test('selectBumps keeps same-major upgrades and refuses majors', () => {
  const plan = selectBumps(
    {
      semver: '7.5.4',
      ms: '2.1.2',
      chalk: '4.1.2',
      left: '^1.0.0',
    },
    {
      semver: '7.8.5',
      ms: '2.1.3',
      chalk: '5.0.0',
      left: '1.2.0',
    },
  );

  assert.deepEqual(plan.bumps, [
    { name: 'ms', from: '2.1.2', to: '2.1.3' },
    { name: 'semver', from: '7.5.4', to: '7.8.5' },
  ]);

  const reasons = Object.fromEntries(plan.skipped.map((item) => [item.name, item.reason]));
  assert.equal(reasons.chalk, 'major bump refused');
  assert.equal(reasons.left, 'not an exact x.y.z pin');
});

test('selectBumps skips packages that are already current', () => {
  const plan = selectBumps({ ms: '2.1.3' }, { ms: '2.1.3' });
  assert.deepEqual(plan.bumps, []);
  assert.equal(plan.skipped[0].reason, 'already current');
});
