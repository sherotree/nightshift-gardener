#!/usr/bin/env bash
# Launch a non-interactive coding agent with the gardener prompt.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

agent="${1:-${SBX_AGENT:-claude}}"
prompt="$(cat "$ROOT/agent/PROMPT.md")"

case "$agent" in
  claude)
    if ! command -v claude >/dev/null 2>&1; then
      echo "claude is not on PATH inside the sandbox." >&2
      exit 127
    fi
    claude --dangerously-skip-permissions -p "$prompt"
    ;;
  codex)
    if ! command -v codex >/dev/null 2>&1; then
      echo "codex is not on PATH inside the sandbox." >&2
      exit 127
    fi
    codex exec --dangerously-bypass-approvals-and-sandbox "$prompt"
    ;;
  *)
    echo "Unsupported agent: $agent. Use claude, codex, or --script." >&2
    exit 2
    ;;
esac
