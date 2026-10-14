# Dependency Gardener

Night Shift entry for the [$250 Agent Challenge](https://github.com/ajeetraina/250-dollar-agent-challenge).

An unattended pass over `playground/`: find exact npm pins that are behind, bump them on a separate branch, run install + build + test, and open a **draft** pull request only when that gate is green. A red gate writes `reports/FAILURE.md` and does not open a pull request.

Author: **Sherotree**. Contact: support@sherotree.com.

## Night Shift

The job is started with `sbx` and then left alone. `scripts/nightshift.sh` creates a named sandbox in detached mode, starts the gardener inside it, and returns. The sandbox keeps running after that terminal closes.

On a laptop, local `sbx` keeps running while the machine is awake. Sleep pauses a local microVM. The optional cloud path (`--cloud`) is the one that continues after the lid is closed, and it spends from the Docker sandbox credit. A local run leaves that credit untouched.

`sbx stop` pauses the sandbox. The disk is kept, and the job waits until you start it again. Leave the sandbox running until `reports/STATUS.md` or `reports/FAILURE.md` exists.

## Architecture

```
scripts/nightshift.sh
  sbx run -d --name nightshift-gardener
  sbx exec  ->  scripts/run-unattended.sh
                  setsid scripts/run-job.sh
                    agent:  claude/codex reads agent/PROMPT.md
                    script: scripts/garden.sh
                              same-major bumps in playground/
                              npm ci && npm test && npm run build
                              green -> commit on garden/deps-*
                                       gh pr create --draft
                              red   -> reports/FAILURE.md, branch removed
```

Local sandboxes mount this repo at the same path, so `reports/` and the git branch show up on the host while the terminal is gone. Cloud sandboxes have no host mount. With `--cloud`, the script clones `https://github.com/sherotree/nightshift-gardener.git` inside the guest.

Two launch modes share that gate:

| Command | What runs inside the sandbox |
|---|---|
| `bash scripts/nightshift.sh` | Coding agent, prompt in `agent/PROMPT.md`, runbook in `agent/RUNBOOK.md` |
| `bash scripts/nightshift.sh --script` | `scripts/garden.sh` directly, no model call |

The agent is told to run `scripts/garden.sh`. Opening the pull request stays inside that script, after the gate passes.

Bump policy:

- Direct `dependencies` and `devDependencies` only
- Exact `x.y.z` pins only
- Newest release with the same major (`7.5.4` can become `7.8.5`; `8.0.0` is refused)
- Prereleases are ignored

## Prerequisites

- Docker Sandboxes CLI (`sbx`), and a Docker account
- Node.js 18 or newer on the host, if you want to run the playground outside `sbx`
- For the agent path: a model credential stored on the **host**, not in this repo
- For the draft PR: `gh` authenticated on the host, then handed to the sandbox as a secret

Install `sbx`:

```bash
# macOS
brew install docker/tap/sbx

# Windows
winget install -h Docker.sbx

# Linux (Ubuntu 22.04+, KVM)
# https://docs.docker.com/ai/sandboxes/
```

Sign in and pick the **Balanced** network policy when asked. The guest needs `registry.npmjs.org` and, to open a PR, `github.com`.

```bash
sbx login
```

Store credentials on the host. These commands read from your keychain or prompt. Nothing from them belongs in the repo, the video, or a screenshot.

```bash
# Agent path. Use the one you launch.
sbx secret set anthropic          # Claude
sbx secret set openai             # Codex

# Draft PRs. The token stays on the host.
sbx secret set github --command 'gh auth token'
```

Secrets are applied when the sandbox is **created**. If you set one later, remove the sandbox and start again (`bash scripts/nightshift.sh --fresh`).

Use an HTTPS git remote with no token in the URL. `scripts/garden.sh` refuses to push when `origin` contains embedded credentials.

## Playground

`playground/` is a small Node app (`playground-clock`) with three direct pins that are behind on purpose:

| Package | Pinned | Same-major updates exist |
|---|---|---|
| `debug` | 4.3.4 | yes |
| `ms` | 2.1.2 | yes |
| `semver` | 7.5.4 | yes |

`npm test` and `npm run build` pass on these old pins. The gardener's job is the bump, and the tests still have to pass after it. `main` (this scaffold) stays on the old pins. The draft PR is where the bump lives, so the demo can be repeated.

Reset the pins from the committed baseline:

```bash
bash scripts/seed-outdated.sh
```

Before this branch is merged, `main` may not contain the playground yet. The seed script then resets from the branch you have checked out.

## Reproduce

Clone and confirm the outdated app is already green:

```bash
git clone https://github.com/sherotree/nightshift-gardener.git
cd nightshift-gardener
bash scripts/seed-outdated.sh
cd playground
npm ci --ignore-scripts --no-audit --no-fund
npm test
npm run build
cd ..
```

See the bump plan without writing files:

```bash
bash scripts/garden.sh --dry-run
```

### Detach demo (no model)

This is the path to record if you want the gate without a model bill. The sandbox still has to stay up after the command returns.

```bash
bash scripts/nightshift.sh --script
```

The script prints the sandbox id and exits. Close that terminal.

### Detach demo (agent)

Default agent is Claude. Codex: `--agent codex`.

```bash
bash scripts/nightshift.sh
# or
bash scripts/nightshift.sh --agent codex
```

The first `sbx run` pulls an image. Later launches are quicker.

### Come back

From a new terminal, in this repo:

```bash
bash scripts/detach-demo.sh status
bash scripts/detach-demo.sh logs
```

On the local path the log is also on the host: `tail -f reports/nightshift.log`.

Reattach an agent session only if you want to watch it. The job does not need the attach:

```bash
sbx run --name nightshift-gardener
```

Pause and resume (work does **not** continue while paused):

```bash
bash scripts/detach-demo.sh stop
sbx run --name nightshift-gardener
```

Remove it when you are done:

```bash
sbx rm nightshift-gardener
```

### Cloud (optional credit)

Same scripts. The guest clones the public repo, so this matches a pushed branch (after merge, that is `main`).

```bash
SBX_CLOUD=1 bash scripts/nightshift.sh --script
SBX_CLOUD=1 bash scripts/detach-demo.sh status
```

Or `bash scripts/nightshift.sh --cloud`. Stop a cloud sandbox when you are finished so it does not sit and bill. A spend screenshot is only for this path. Pure local runs have nothing to screenshot.

## How judges check that it finished unattended

1. `bash scripts/nightshift.sh` (or `--script`) returns, and the terminal that launched it is closed.
2. `sbx ls` shows `nightshift-gardener` still running, with no attached session required.
3. After the job, one of these exists:
   - `reports/STATUS.md` with `Result: green`, a `garden/deps-*` branch, and either a draft PR URL or a note that auth was missing
   - `reports/FAILURE.md` with `Pull request: not opened`
4. A green run's diff is only `playground/package.json` and `playground/package-lock.json` on that branch. `main` is unchanged.
5. A red run does not leave a `garden/deps-*` branch and does not add a pull request. Check with `git branch` and `gh pr list`.
6. `reports/nightshift.log` should show the job starting after `nightshift.sh` had already returned.

`Result: idle` means the pins were already current. Run `bash scripts/seed-outdated.sh` from the scaffold branch and try again. A green run leaves the checkout on `garden/deps-*`. To repeat the demo:

```bash
git checkout main
bash scripts/seed-outdated.sh
```

If this scaffold is not on `main` yet, check out the scaffold branch instead of `main`.

## Layout

| Path | Role |
|---|---|
| `playground/` | App, outdated pins, lockfile, test, build |
| `agent/PROMPT.md` | Prompt passed to the coding agent |
| `agent/RUNBOOK.md` | Steps and the bump policy |
| `scripts/nightshift.sh` | Detached `sbx` launch |
| `scripts/detach-demo.sh` | Status, logs, reconnect hint, pause |
| `scripts/seed-outdated.sh` | Put the outdated pins back |
| `scripts/garden.sh` | Detect, bump, gate, draft PR |
| `scripts/check-green.sh` | `npm ci`, test, build |
| `reports/` | Run output. Gitignored except `.gitkeep` |

## Submission checklist

Track brief and form: [SUBMISSION.md](https://github.com/ajeetraina/250-dollar-agent-challenge/blob/main/SUBMISSION.md). Form: https://forms.gle/TFrsnDkbnZrrfoUW8. Deadline on that page: Sat, Oct 31, 2026, 11:59 PM IST.

- [x] Track: **Night Shift**
- [x] Team: Sherotree
- [x] Build log: this README
- [ ] 2-minute demo video (public or unlisted). Record after a real detach/reconnect. Not in this repo.
- [x] Spend screenshot: **N/A for a pure local run.** Add one only if you used `--cloud`.
- [x] No secrets in the repo
- [ ] Submit the form before the deadline

Copy for the form:

```markdown
### Project name
Dependency Gardener

### Track
Night Shift

### Team
Sherotree

### One-line pitch
After sbx detach, bump outdated npm pins in a playground app, test them, and open a draft PR only if the gate is green.

### Build log (link)
https://github.com/sherotree/nightshift-gardener#dependency-gardener

### Demo video (link)
TBD

### Spend screenshot
N/A for local sbx. Cloud credit is optional.

### Cloud or local?
Local sbx. Cloud is optional via scripts/nightshift.sh --cloud.

### How to run it
See README "Reproduce".

### What are you proud of?
The sandbox can be left detached, and a red install/build/test cannot open a pull request.

### Competing for a special award?
Best Build Log
```
