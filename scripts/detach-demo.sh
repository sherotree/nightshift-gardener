#!/usr/bin/env bash
# Inspect a detached gardener sandbox after you come back.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

name="${SBX_NAME:-nightshift-gardener}"
cloud="${SBX_CLOUD:-0}"
cmd="${1:-status}"

sbx=(sbx)
prefix="sbx"
if [[ "$cloud" == "1" ]]; then
  sbx=(sbx --cloud)
  prefix="sbx --cloud"
fi

show_report() {
  local file="$1"
  if [[ "$cloud" == "1" ]]; then
    "${sbx[@]}" exec "$name" -- bash -lc "cd \"\$HOME/nightshift-gardener\" && test -f '$file' && cat '$file'" || true
    return
  fi
  if [[ -f "$file" ]]; then
    echo "---- $file ----"
    cat "$file"
  fi
}

case "$cmd" in
  status)
    "${sbx[@]}" ls || true
    echo
    if [[ "$cloud" == "0" && -f reports/launch.txt ]]; then
      echo "---- reports/launch.txt ----"
      cat reports/launch.txt
      echo
      if [[ -f reports/nightshift.pid ]]; then
        pid="$(cat reports/nightshift.pid)"
        echo "Guest process:"
        if "${sbx[@]}" exec "$name" -- ps -p "$pid" -o pid,etime,cmd; then
          :
        elif [[ -f reports/STATUS.md || -f reports/FAILURE.md ]]; then
          echo "pid $pid has exited. The report below is the result."
        else
          echo "pid $pid is not running."
        fi
        echo
      fi
    fi
    if [[ -f reports/STATUS.md || "$cloud" == "1" ]]; then
      show_report reports/STATUS.md
    fi
    if [[ -f reports/FAILURE.md || "$cloud" == "1" ]]; then
      show_report reports/FAILURE.md
    fi
    if [[ "$cloud" == "0" && ! -f reports/STATUS.md && ! -f reports/FAILURE.md ]]; then
      echo "No report yet."
      if [[ -f reports/nightshift.log ]]; then
        echo "---- reports/nightshift.log (tail) ----"
        tail -n 40 reports/nightshift.log
      fi
    fi
    ;;
  logs)
    lines="${2:-80}"
    if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
      echo "line count must be a number" >&2
      exit 1
    fi
    if [[ "$cloud" == "1" ]]; then
      "${sbx[@]}" exec "$name" -- bash -lc "tail -n $lines \"\$HOME/nightshift-gardener/reports/nightshift.log\""
    elif [[ -f reports/nightshift.log ]]; then
      tail -n "$lines" reports/nightshift.log
    else
      echo "reports/nightshift.log does not exist yet."
      exit 1
    fi
    ;;
  reconnect)
    echo "The job does not need an attached session. Reattach only to watch the agent:"
    echo "  $prefix run --name $name"
    ;;
  stop)
    "${sbx[@]}" stop "$name"
    echo "Paused. Work does not continue while the sandbox is stopped."
    echo "Resume with: $prefix run --name $name"
    ;;
  *)
    echo "usage: scripts/detach-demo.sh {status|logs|reconnect|stop}" >&2
    exit 1
    ;;
esac
