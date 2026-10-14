#!/usr/bin/env bash
# Bump same-major direct deps, then open a draft PR only if install, build, and test pass.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLAYGROUND="$ROOT/playground"
REPORTS="$ROOT/reports"
mkdir -p "$REPORTS"

base="${GARDENER_BASE:-$(git branch --show-current)}"
open_pr="${GARDENER_OPEN_PR:-1}"
branch=""
dry_run=0
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=1
elif [[ -n "${1:-}" ]]; then
  echo "usage: scripts/garden.sh [--dry-run]" >&2
  exit 1
fi

sanitize_file() {
  local file="$1"
  local tmp
  [[ -f "$file" ]] || return 0
  tmp="$(mktemp)"
  sed -E \
    -e 's#https://[^[:space:]/@]+:[^[:space:]/@]+@#https://#g' \
    -e 's#://[^[:space:]/@]+:[^[:space:]/@]+@#://#g' \
    "$file" > "$tmp"
  mv "$tmp" "$file"
}

write_failure() {
  local step="$1"
  local log_file="${2:-}"
  {
    echo "# Dependency Gardener"
    echo
    echo "- Result: red"
    echo "- Pull request: not opened"
    echo "- Failed step: $step"
    echo "- Branch: not kept"
    if [[ -f "$REPORTS/plan.json" ]] && node -e 'JSON.parse(require("fs").readFileSync("reports/plan.json","utf8"))' >/dev/null 2>&1; then
      echo
      echo "## Planned bumps"
      echo
      node -e '
        const plan = require("./reports/plan.json");
        if (!plan.bumps || !plan.bumps.length) console.log("None.");
        for (const bump of plan.bumps || []) {
          console.log(`- ${bump.name} ${bump.from} -> ${bump.to}`);
        }
      '
    fi
    if [[ -n "$log_file" && -f "$log_file" ]]; then
      echo
      echo "## Log"
      echo
      echo '```'
      tail -n 80 "$log_file"
      echo '```'
    fi
  } > "$REPORTS/FAILURE.md"
  sanitize_file "$REPORTS/FAILURE.md"
  rm -f "$REPORTS/STATUS.md"
  echo "Red gate at step: $step. No pull request opened."
  echo "Report: reports/FAILURE.md"
}

abort_bump() {
  local step="$1"
  local log_file="${2:-}"
  write_failure "$step" "$log_file"
  git checkout -- playground/package.json playground/package-lock.json >/dev/null 2>&1 || true
  if [[ -n "${branch:-}" ]]; then
    git checkout "$base" >/dev/null 2>&1 || true
    git branch -D "$branch" >/dev/null 2>&1 || true
  fi
  if [[ -f playground/package-lock.json ]]; then
    (cd "$PLAYGROUND" && npm ci --ignore-scripts --no-audit --no-fund) >/dev/null 2>&1 || true
  fi
  exit 2
}

if [[ -z "$base" ]]; then
  write_failure "detached HEAD; checkout the scaffold branch first"
  exit 1
fi

if ! git rev-parse --verify --quiet "$base" >/dev/null; then
  write_failure "base branch $base is missing"
  exit 1
fi

current="$(git branch --show-current)"
if [[ "$current" != "$base" ]]; then
  write_failure "working tree is on ${current:-detached}; checkout $base first"
  exit 1
fi

dirty="$(git status --porcelain | grep -v -E '^\?\? reports/' || true)"
if [[ -n "$dirty" ]]; then
  write_failure "working tree is dirty"
  {
    echo
    echo "## Git status"
    echo
    echo '```'
    printf '%s\n' "$dirty"
    echo '```'
  } >> "$REPORTS/FAILURE.md"
  sanitize_file "$REPORTS/FAILURE.md"
  exit 1
fi

if ! node scripts/lib/plan-bumps.js "$PLAYGROUND/package.json" > "$REPORTS/plan.json" 2>"$REPORTS/plan.err"; then
  abort_bump "registry lookup" "$REPORTS/plan.err"
fi
sanitize_file "$REPORTS/plan.err"

bump_count="$(node -e 'const plan = require("./reports/plan.json"); process.stdout.write(String(plan.bumps.length));')"
if [[ "$bump_count" == "0" ]]; then
  {
    echo "# Dependency Gardener"
    echo
    echo "- Result: idle"
    echo "- Pull request: not opened"
    echo "- Reason: no same-major updates for exact direct pins"
  } > "$REPORTS/STATUS.md"
  rm -f "$REPORTS/FAILURE.md"
  echo "No same-major bumps. No pull request opened."
  exit 0
fi

if [[ "$dry_run" == "1" ]]; then
  node -e '
    const plan = require("./reports/plan.json");
    for (const bump of plan.bumps) {
      console.log(`${bump.name} ${bump.from} -> ${bump.to}`);
    }
  '
  echo "Dry run only. Package files were not changed."
  exit 0
fi

branch="garden/deps-$(date -u +%Y%m%d-%H%M%S)"
git checkout -b "$branch"

if ! node scripts/lib/apply-bumps.js "$PLAYGROUND/package.json" "$REPORTS/plan.json" 2>"$REPORTS/apply.err"; then
  abort_bump "apply bumps" "$REPORTS/apply.err"
fi

if ! (cd "$PLAYGROUND" && npm install --ignore-scripts --no-audit --no-fund) >"$REPORTS/install.log" 2>&1; then
  sanitize_file "$REPORTS/install.log"
  abort_bump "npm install" "$REPORTS/install.log"
fi
sanitize_file "$REPORTS/install.log"

if ! bash scripts/check-green.sh >"$REPORTS/check.log" 2>&1; then
  sanitize_file "$REPORTS/check.log"
  abort_bump "install, build, or test" "$REPORTS/check.log"
fi
sanitize_file "$REPORTS/check.log"

export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Sherotree}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-support@sherotree.com}"
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"

bump_lines="$(node -e '
  const plan = require("./reports/plan.json");
  for (const bump of plan.bumps) console.log(`- ${bump.name} ${bump.from} -> ${bump.to}`);
')"

git add playground/package.json playground/package-lock.json
git commit -m "$(cat <<EOF
chore(playground): bump outdated direct dependencies

${bump_lines}
EOF
)"
commit_sha="$(git rev-parse --short HEAD)"

pr_line="not opened"
pr_reason=""

write_pr_body() {
  cat > "$REPORTS/pr-body.md" <<EOF
## Summary

Dependency Gardener bumped exact direct pins in \`playground/\` and kept the same major version.

${bump_lines}

## Gate

- \`npm ci --ignore-scripts\`
- \`npm test\`
- \`npm run build\`

All three passed before this draft was opened. A red run does not open a pull request.

## Review

This is a draft. \`$base\` stays on the outdated pins so the Night Shift demo can be run again.
EOF
  sanitize_file "$REPORTS/pr-body.md"
}

if [[ "$open_pr" == "0" ]]; then
  pr_reason="GARDENER_OPEN_PR=0"
else
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -z "$origin_url" ]]; then
    pr_reason="no origin remote"
  elif [[ "$origin_url" =~ ://[^/@]+:[^/@]+@ ]]; then
    pr_reason="origin URL contains embedded credentials; refusing to push"
  elif ! command -v gh >/dev/null 2>&1; then
    pr_reason="gh is not installed in this environment"
  elif ! gh auth status >/dev/null 2>&1; then
    pr_reason="gh is not authenticated"
  else
    write_pr_body
    if ! git push -u origin "$branch" >"$REPORTS/push.log" 2>&1; then
      sanitize_file "$REPORTS/push.log"
      pr_reason="git push failed; see reports/push.log"
    else
      sanitize_file "$REPORTS/push.log"
      if url="$(gh pr create --draft --base "$base" --head "$branch" --title "chore(playground): bump outdated direct dependencies" --body-file "$REPORTS/pr-body.md" 2>"$REPORTS/pr.err")"; then
        sanitize_file "$REPORTS/pr.err"
        pr_line="$url"
      else
        sanitize_file "$REPORTS/pr.err"
        pr_reason="gh pr create failed; see reports/pr.err"
      fi
    fi
  fi
fi

{
  echo "# Dependency Gardener"
  echo
  echo "- Result: green"
  echo "- Branch: $branch"
  echo "- Base: $base"
  echo "- Commit: $commit_sha"
  echo "- Install: pass"
  echo "- Build: pass"
  echo "- Test: pass"
  echo "- Pull request: $pr_line"
  if [[ -n "$pr_reason" ]]; then
    echo "- Pull request note: $pr_reason"
    echo
    echo "The green commit is on \`$branch\`. Open the draft yourself when auth is ready:"
    echo
    echo '```bash'
    echo "git push -u origin $branch"
    echo "gh pr create --draft --base $base --head $branch --title 'chore(playground): bump outdated direct dependencies' --body-file reports/pr-body.md"
    echo '```'
  fi
  echo
  echo "## Bumps"
  echo
  printf '%s\n' "$bump_lines"
} > "$REPORTS/STATUS.md"
sanitize_file "$REPORTS/STATUS.md"
rm -f "$REPORTS/FAILURE.md"

echo "Green. Branch $branch ($commit_sha)."
echo "Pull request: $pr_line"
if [[ -n "$pr_reason" ]]; then
  echo "Pull request note: $pr_reason"
fi
echo "Report: reports/STATUS.md"
