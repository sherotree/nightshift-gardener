# Dependency Gardener runbook

The coding agent inside the sandbox follows this file. `scripts/garden.sh` is the gate. The agent does not get a second, looser path.

## Goal

On `playground/`, bump outdated **exact** direct dependencies to the newest release with the **same major** version. Run install, build, and test. Open a **draft** pull request only when that gate is green. A red gate leaves `reports/FAILURE.md` and does not open a pull request.

## Steps

1. Confirm the checkout is the scaffold branch (`main` after this repo is merged) and the worktree is clean, apart from untracked `reports/`.
2. Run:

   ```bash
   bash scripts/garden.sh
   ```

3. Wait for it to exit. Do not start a second bump while it is running.
4. If the exit code is `0`, read `reports/STATUS.md`.
   - `Result: green` means the branch `garden/deps-*` exists and the gate passed.
   - `Pull request:` is a URL when `gh` could open a draft.
   - A note instead of a URL means the commit is local and no pull request was opened. Do not open one yourself in that case. The status file already has the command for a human.
   - `Result: idle` means nothing was outdated. Do not open a pull request.
5. If the exit code is not `0`, read `reports/FAILURE.md` and stop. Do not push and do not create a pull request.

## Policy encoded in the script

- Only `dependencies` and `devDependencies` in `playground/package.json`.
- Only exact `x.y.z` pins. Ranges are skipped.
- Same major only. `4.3.4` may move to `4.4.3`. It may not move to `5.0.0`.
- Prereleases are ignored.
- The script commits `playground/package.json` and `playground/package-lock.json` on a new branch after the gate passes.
- `npm ci --ignore-scripts`, `npm test`, and `npm run build` must all succeed.
- On failure the script deletes the garden branch and restores the pins.
- Push is refused when the `origin` URL has embedded credentials.

## Auth

GitHub and model credentials stay on the host, stored with `sbx secret set` before the sandbox is created. Do not ask for a token and do not write one into the repo.

## Done

One of `reports/STATUS.md` or `reports/FAILURE.md` exists, and the agent process exits.
