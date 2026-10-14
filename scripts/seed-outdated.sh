#!/usr/bin/env bash
# Restore the committed outdated playground pins from the base branch.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

base="${GARDENER_BASE:-main}"
# Before this scaffold is on main, reset from the branch you have checked out.
if ! git cat-file -e "$base:playground/package-lock.json" 2>/dev/null; then
  current="$(git branch --show-current || true)"
  if [[ -n "${current:-}" ]] && git cat-file -e "$current:playground/package-lock.json" 2>/dev/null; then
    base="$current"
  fi
fi

ref=""
if git rev-parse --verify --quiet "$base" >/dev/null; then
  ref="$base"
elif git rev-parse --verify --quiet "origin/$base" >/dev/null; then
  ref="origin/$base"
else
  ref="HEAD"
fi

if git cat-file -e "$ref:playground/package.json" 2>/dev/null \
  && git cat-file -e "$ref:playground/package-lock.json" 2>/dev/null; then
  git checkout "$ref" -- playground/package.json playground/package-lock.json
  echo "Restored playground pins from $ref"
else
  echo "No playground lockfile on $ref. Left the current package files in place."
fi

rm -rf playground/node_modules playground/dist
node -e '
const pkg = require("./playground/package.json");
const deps = { ...(pkg.dependencies || {}), ...(pkg.devDependencies || {}) };
for (const name of Object.keys(deps).sort()) {
  console.log(`  ${name}@${deps[name]}`);
}
'
