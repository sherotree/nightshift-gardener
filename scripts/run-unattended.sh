#!/usr/bin/env bash
# Start the gardener in its own session and return immediately.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p reports

mode="${1:-script}"
agent="${2:-claude}"

if [[ "$mode" != "script" && "$mode" != "agent" ]]; then
  echo "mode must be script or agent" >&2
  exit 2
fi

# New session so the launching `sbx exec` can return without killing the job.
# setsid forks when it is already a process-group leader, so $! can be a
# parent that exits immediately. The command records its own pid.
rm -f reports/nightshift.pid
setsid bash -c 'echo $$ > reports/nightshift.pid; exec bash scripts/run-job.sh "$@"' _ "$mode" "$agent" \
  > reports/nightshift.log 2>&1 < /dev/null &
disown || true

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if [[ -s reports/nightshift.pid ]]; then
    break
  fi
  sleep 0.1
done

if [[ ! -s reports/nightshift.pid ]]; then
  echo "gardener did not record a pid" >&2
  exit 1
fi

cat > reports/launch.txt <<EOF
mode=$mode
agent=$agent
pid=$(cat reports/nightshift.pid)
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "started pid $(cat reports/nightshift.pid) mode=$mode agent=$agent"
echo "log: reports/nightshift.log"
