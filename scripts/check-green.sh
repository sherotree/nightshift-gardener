#!/usr/bin/env bash
# Install from the lockfile, then run the playground test and build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/playground"

npm ci --ignore-scripts --no-audit --no-fund
npm test
npm run build
