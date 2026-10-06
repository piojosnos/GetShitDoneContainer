# Host checklist (H-00..H-19)

The test plan for the sbx sandbox: checks that can only be proven on your Mac, because Docker does not run in the dev sandbox. One script runs almost all of them; four short helpers cover the steps that need you.

- **IDs:** each check has an ID, H-00 to H-19 (H for host), so results can be reported by ID ("H-10 failed").
- **When:** once after building a new version of the images or `compose.yml`.
- **Setup and daily use:** see [`SANDBOX.md`](../SANDBOX.md).
- Commands run from the repo root.

How to run it:

1. Run the automated checks.
2. Do the manual pass.
3. Clean up.

## Run the automated checks

```bash
bash tests/host/run-all.sh
```

What it does:

- Builds `sbx-base:local` and `sbx-claude:local`, the real image tags.
- Makes a fresh folder under `$TMPDIR` named `sbx-hosttest-...` and starts a test sandbox named `sbx-hosttest` on it.
- Prints `PASS`, `FAIL` or `NOT RUN` per check, then a summary. Exit status 0 means every check passed.
- Never waits for input and never deletes files.
- Leaves the test sandbox running for the manual pass.
- Ends by printing the next commands.

It needs no exported variables and ignores `SBX_NAME` and `SBX_DIR` from your terminal, so your own sandboxes are never touched.

Optional: `SBXTEST_NO_CACHE=1 bash tests/host/run-all.sh` rebuilds the images without the cache in H-09. It is slow.

What each check proves:

| ID | What it proves | Script (in `tests/host/`) | Run |
|---|---|---|---|
| H-00 | Compose v2 or newer is installed | `h00-compose-v2.sh` | automatic |
| H-01 | Images build natively (arm64 on Apple silicon) | `h01-native-arch.sh` | automatic |
| H-02 | The Claude image sits on the base image | `h02-claude-on-base.sh` | automatic |
| H-03 | Name and folder variables are required | `h03-variable-interpolation.sh` | automatic |
| H-04 | The user is non-root (uid 1000) | `h04-nonroot-user.sh` | automatic |
| H-05 | Workspace and home layout | `h05-workspace-and-home.sh` | automatic |
| H-06 | Git works and the identity persists | `h06-git-and-identity.sh` | automatic |
| H-07 | Claude login lands in the state folder | `manual/h07-login.sh` | manual only |
| H-08 | Shell history survives a recreate | `h08-history-survives-recreate.sh` | automatic |
| H-09 | Files and a planted memory survive a rebuild, no volumes exist; the login and the session survive too | `h09-rebuild-keeps-files-no-volumes.sh`, `manual/h09-rebuild-resume.sh` | automatic part, manual part |
| H-10 | A missing folder is refused | `h10-missing-folder-refused.sh` | automatic |
| H-11 | Stopping is quick and keeps everything | `h11-stop-is-quick-and-safe.sh` | automatic |
| H-12 | A plain `docker run` is refused; the pinned Claude is installed | `h12-plain-run-refused-pin-installed.sh` | automatic |
| H-13 | Environment is visible and self-update is off; `claude doctor` agrees | `h13-env-and-no-self-update.sh`, `manual/h13-doctor.sh` | automatic part, manual part |
| H-14 | The image holds the bundle, equal to the repo; owners, modes and no mount are right; the managed settings parse | `h14-bundle-in-image.sh` | automatic |
| H-15 | Rules and skills are synced and equal to the repo; Claude lists the always-on rules and the skills, not the path-scoped rules | `h15-bundle-synced-and-visible.sh` | automatic |
| H-16 | A restart refreshes the bundle and keeps user skills, GSD skills, memories and `CLAUDE.md` | `h16-sync-refreshes-and-spares.sh` | automatic |
| H-17 | A start works with networking off; a failing hook, a hook file that is not executable and a dangling hook link each stop the start | `h17-start-offline-and-failing-hook.sh` | automatic |
| H-18 | In the real image, a path-scoped rule loads only after Claude reads a matching file, and the managed deny refuses edits to synced files under `bypassPermissions`; no login or network needed | `h18-scope-and-deny.sh` | automatic |
| H-19 | Skills in Claude, a rule followed, a language rule on demand, a refused edit, the managed settings source | `manual/h19-bundle-behaviour.sh` | manual only |
| Coexistence | Old-layout containers and files are untouched | `coexistence.sh` | automatic |

## Manual pass

Run after `run-all.sh`, in this order. Each needs a real terminal and uses the same test sandbox.

```bash
bash tests/host/manual/h07-login.sh
bash tests/host/manual/h09-rebuild-resume.sh
bash tests/host/manual/h13-doctor.sh
bash tests/host/manual/h19-bundle-behaviour.sh
```

| Helper | You do | It checks |
|---|---|---|
| `h07-login.sh` | Log in with a claude.ai account, then `/exit` | `.claude.json`, `.credentials.json` and `projects/` are in the run folder's `state/claude`; `claude auth status` shows `"loggedIn": true`; there is no `~/.claude.json` in the container home |
| `h09-rebuild-resume.sh` | Confirm the earlier session resumes in `claude --continue`, then `/exit` | Rebuilds the images, recreates the sandbox, `claude auth status` is still logged in |
| `h13-doctor.sh` | Confirm `claude doctor` shows auto-updates disabled | Nothing more; the wording is for you to judge |
| `h19-bundle-behaviour.sh` | Follow five steps in Claude: the skills are listed, an always-on rule is followed, a language rule loads on a matching file, an edit of a synced rule is refused, `/status` shows the managed settings | The copy of `communication.md` in the run folder still equals the repo file |

- Add `--no-cache` to `h09-rebuild-resume.sh` for a clean rebuild: `bash tests/host/manual/h09-rebuild-resume.sh --no-cache`. It is slow.
- Each helper prints `PASS` or `FAIL` lines and exits 0 only when every line is `PASS`.
- A helper run without a terminal, or when the test sandbox is not running, stops before it does anything.

## Reading a failure

- **FAIL line:** shows the check ID and what went wrong, with detail lines under it.
- **NOT RUN:** an earlier step failed: the setup, or an earlier link of the chain H-08, H-16, H-11, H-09, H-10. Fix that one first.
- **Build failure:** the output names the log path, inside the run folder's `logs/`.
- **"Mounts denied" during setup:** Docker Desktop does not share `$TMPDIR`. Add it in Settings, Resources, File sharing.
- **H-10 says Docker created the missing folder:** Compose ignored `create_host_path: false`. That is a real finding, not a script bug.
  - Do not change `compose.yml`.
  - See the env_file follow-up in [`SANDBOX.md`, Troubleshooting](../SANDBOX.md#troubleshooting-and-known-limits). It needs your approval.
- **H-15 fails after a Claude Code pin change:** the format of `/context` may have changed. Compare with what `manual/h19-bundle-behaviour.sh` shows before suspecting the bundle.
- **H-15 and a login:** H-15 runs Claude without a login, so `state/claude/.claude.json` exists before `h07-login.sh` runs. The login proof in `h07-login.sh` is `.credentials.json` and `claude auth status`.
- **H-18 fails after a Claude Code pin change:** H-18 follows the wire format of the pinned Claude through a small fake API.
  - Run `bash tests/bundle-selftest.sh` in the dev sandbox first. If it fails too, the fake API needs updating, not the image.
  - If only H-18 fails, `manual/h19-bundle-behaviour.sh` still covers both behaviours by hand.
  - To drop H-18, delete its script, its entry in `run-all.sh` and its cases in `host-selftest.sh`. No other check depends on it.
- **After the managed settings landed:** run `manual/h13-doctor.sh` once to see that `claude doctor` still reports updates disabled.
- **Coexistence fails:** if you started or stopped a `cc_` container during the run, run it again.
- **Rebuilding retags the images:** your running sandboxes keep their old image until their next `docker compose up`. That is safe: all their data is in their folder.

## Clean up

Run the cleanup command that `run-all.sh` printed. It stops `sbx-hosttest` and deletes the run folder.

- Do it after the manual pass, because the folder then holds a real Claude login.
- The images stay.

## Record your results

Paste the `run-all.sh` summary and the helper lines.

- `docker compose version` output:
- Docker Desktop version:
- H-10 observation (what `up` printed, whether the folder existed afterwards):

Any failure becomes input for gap-closure planning.
