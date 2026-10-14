#!/usr/bin/env bash
# Work that keeps running after the launching sbx exec returns.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p reports

mode="${1:-script}"
agent="${2:-claude}"

echo "run-job mode=$mode agent=$agent start=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

case "$mode" in
  script)
    bash scripts/garden.sh
    ;;
  agent)
    if ! bash scripts/run-agent.sh "$agent"; then
      code=$?
      if [[ ! -f reports/STATUS.md && ! -f reports/FAILURE.md ]]; then
        cat > reports/FAILURE.md <<EOF
# Dependency Gardener

- Result: red
- Pull request: not opened
- Failed step: agent ($agent) exited $code without writing a report
EOF
      fi
      exit "$code"
    fi
    if [[ ! -f reports/STATUS.md && ! -f reports/FAILURE.md ]]; then
      cat > reports/FAILURE.md <<EOF
# Dependency Gardener

- Result: red
- Pull request: not opened
- Failed step: agent ($agent) exited without writing a report
EOF
      exit 1
    fi
    ;;
  *)
    echo "Unknown mode: $mode" >&2
    exit 2
    ;;
esac

echo "run-job end=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
