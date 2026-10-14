#!/usr/bin/env bash
# Start Dependency Gardener in a detached Docker Sandbox and return.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

name="${SBX_NAME:-nightshift-gardener}"
agent="${SBX_AGENT:-claude}"
cloud="${SBX_CLOUD:-0}"
mode="agent"
fresh=0
ref="${GARDENER_GIT_REF:-main}"
repo="https://github.com/sherotree/nightshift-gardener.git"

usage() {
  cat <<EOF
Usage: scripts/nightshift.sh [--script] [--cloud] [--fresh] [--agent claude|codex] [--name NAME]

  --script   Run scripts/garden.sh inside the sandbox. No model call.
  --cloud    Use sbx --cloud. Credit is optional. Local sbx is the default.
  --fresh    Remove a sandbox with this name before creating a new one.
  --agent    claude (default) or codex. Ignored with --script.
  --name     Sandbox name. Default: nightshift-gardener.

The command returns after the job is launched. Leave the sandbox running.
Do not sbx stop it until the report exists.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --script) mode="script"; shift ;;
    --cloud) cloud=1; shift ;;
    --fresh) fresh=1; shift ;;
    --agent)
      agent="${2:-}"
      shift 2
      ;;
    --name)
      name="${2:-}"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$mode" == "agent" && "$agent" != "claude" && "$agent" != "codex" ]]; then
  echo "Agent must be claude or codex." >&2
  exit 1
fi

if ! [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$ ]]; then
  echo "Sandbox name must be a short hostname-style token." >&2
  exit 1
fi

if ! [[ "$ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]{0,80}$ ]]; then
  echo "GARDENER_GIT_REF must be a branch or tag name." >&2
  exit 1
fi

if ! command -v sbx >/dev/null 2>&1; then
  cat <<EOF
sbx is not installed.

macOS:   brew install docker/tap/sbx
Windows: winget install -h Docker.sbx
Linux:   https://docs.docker.com/ai/sandboxes/

Then: sbx login
EOF
  exit 127
fi

if [[ "$cloud" == "0" ]]; then
  bash scripts/seed-outdated.sh
fi

sbx=(sbx)
if [[ "$cloud" == "1" ]]; then
  sbx=(sbx --cloud)
fi

if [[ "$fresh" == "1" ]]; then
  "${sbx[@]}" rm --force "$name" >/dev/null 2>&1 || true
fi

echo "Starting detached sandbox $name (mode=$mode agent=$agent cloud=$cloud)"
if [[ "$cloud" == "1" ]]; then
  "${sbx[@]}" run -d --name "$name" "$agent"
  "${sbx[@]}" exec "$name" -- bash -lc "
    set -euo pipefail
    dest=\"\$HOME/nightshift-gardener\"
    if [[ ! -d \"\$dest/.git\" ]]; then
      git clone --branch '$ref' '$repo' \"\$dest\"
    fi
    cd \"\$dest\"
    bash scripts/run-unattended.sh '$mode' '$agent'
  "
else
  "${sbx[@]}" run -d --name "$name" "$agent" "$ROOT"
  "${sbx[@]}" exec "$name" -- bash "$ROOT/scripts/run-unattended.sh" "$mode" "$agent"
fi

cat <<EOF

Detached. This terminal is done. The sandbox keeps running until you stop it.

Watch:
  bash scripts/detach-demo.sh status

Reconnect:
  $( [[ "$cloud" == "1" ]] && echo "sbx --cloud run --name $name" || echo "sbx run --name $name" )

Pause (this halts the job; it does not leave it running):
  bash scripts/detach-demo.sh stop
EOF
