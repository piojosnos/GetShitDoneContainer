# Host checklist (H-01 to H-33)

The test plan for the sbx sandbox: checks that can only be proven on your Mac, because Docker does not run in the dev sandbox. One script runs all the checks with nobody at the keyboard.

- **IDs:** each check has an ID, H-01 to H-33 (H for host), so results can be reported by ID ("H-10 failed"). The IDs keep their gaps: a check that was dropped leaves its number unused.
- **When:** once after building a new version of the images or `compose.yml`.
- **Setup and daily use:** see [`README.md`](../README.md).
- Commands run from the repo root.

How to run it:

1. Run the automated checks.
2. Clean up.

## Run the automated checks

```bash
bash tests/host/run-all.sh
```

What it does:

- Builds `sbx-base:test`, `sbx-claude:test` and `sbx-cursor:test` (it sets `SBX_IMAGE_TAG=test`); the `:local` images your sandboxes run are never built, run or removed.
- Makes a fresh folder under `$TMPDIR` named `sbx-hosttest-...` and starts a test sandbox named `sbx-hosttest` on it.
- Prints `PASS`, `FAIL` or `NOT RUN` per check, then a summary. Exit status 0 means every check passed.
- Never waits for input and never deletes files.
- Does not check the Compose version. `./host-test.sh` checks it before any step and stops when Compose v2 is missing.
- Leaves the test sandbox running, so you can look around after a failure.
- Ends by printing the cleanup command.

It needs no exported variables and ignores `SBX_NAME` and `SBX_DIR` from your terminal, so your own sandboxes are never touched. It uses the Docker your terminal points at (`DOCKER_HOST` or the current context) and prints which one first.

Optional: `SBXTEST_NO_CACHE=1 bash tests/host/run-all.sh` rebuilds the images without the cache in H-09. It is slow.

What each check proves:

| ID | What it proves | Script (in `tests/host/`) | Run |
|---|---|---|---|
| H-01 | Images build natively (arm64 on Apple silicon) | `h01-native-arch.sh` | automatic |
| H-03 | Name and folder variables are required; `up` refuses an uppercase name before it creates anything; Compose renders the Claude test image `sbx-claude:test` | `h03-variable-interpolation.sh` | automatic |
| H-04 | The user is non-root (uid 1000) | `h04-nonroot-user.sh` | automatic |
| H-05 | Workspace and home layout | `h05-workspace-and-home.sh` | automatic |
| H-06 | Git works and the identity persists | `h06-git-and-identity.sh` | automatic |
| H-08 | Shell history survives a recreate | `h08-history-survives-recreate.sh` | automatic |
| H-09 | Files, a planted memory, a fake credentials file and a fake session file survive a rebuild, no volumes exist | `h09-rebuild-keeps-files-no-volumes.sh` | automatic |
| H-10 | A missing folder is refused | `h10-missing-folder-refused.sh` | automatic |
| H-12 | A plain `docker run` is refused; the pinned Claude is installed | `h12-plain-run-refused-pin-installed.sh` | automatic |
| H-13 | The environment is visible (`DISABLE_UPDATES=1` among the variables) and no Claude copy sits in `~/.local` | `h13-env-and-no-self-update.sh` | automatic |
| H-14 | The wrappers, hooks and managed settings in the image are root-owned, read-only to the sandbox user and unmounted; the image holds no bundle copy; `BUNDLE_REPO_URL` and `SBX_BUNDLE_DIR` match; the clone is the one additional directory | `h14-wrappers-and-settings-in-image.sh` | automatic |
| H-15 | `state/claude` links into the clone; the container reads the clone through `~/.claude/rules` | `h15-bundle-linked-and-visible.sh` | automatic |
| H-16 | The clone is live: an edit on the Mac and a pull inside the sandbox show in the sandbox at once (the Mac never runs git on the clone). A restart relinks the clone, drops a removed skill and stale copies, keeps an uncommitted edit and keeps your own skills, memories, sessions, settings keys and `CLAUDE.md` | `h16-live-clone-and-restart.sh` | automatic |
| H-17 | A start works with networking off, both with a clone linked and with none (it then says to run `sbx-bundle-clone`); a failing hook, a hook file that is not executable and a dangling hook link each stop the start | `h17-start-offline-and-failing-hook.sh` | automatic |
| H-20 | A sandbox folder without the project folder (a mistyped name) is refused, and nothing is created | `h20-mistyped-name-refused.sh` | automatic |
| H-22 | The base image holds git, gh, Node 24, Python 3, uv, Temurin 21 and Maven at their pins as native binaries, plus the common Linux tools; a login shell in the sandbox finds them | `h22-toolchain-in-base.sh` | automatic |
| H-23 | The npm, uv and Maven caches live in the state folder and a file in each survives a recreate | `h23-caches-survive-recreate.sh` | automatic |
| H-25 | The images match versions.env (the record in the Claude image, GSD and ccusage at their pins, nothing under the mount point), and a build without build.sh stops naming the missing pin (the Claude build gets the test base image) | `h25-images-match-versions.sh` | automatic |
| H-26 | The test sandbox has exactly one mount, a bind at /home/sandbox/workspace; it is not privileged, drops every capability, adds none, has no-new-privileges and no unconfined profile, shares no host namespace (network, PID, IPC, UTS, user) and has no device or extra group (read from docker inspect) | `h26-isolation-by-inspect.sh` | automatic |
| H-27 | In a fresh sandbox folder, offline: `sbx-claude` warns when nothing is linked and runs `claude`; `sbx-bundle-clone` links the clone at once and refuses a second run; a branch is pushed to the origin; a failed clone leaves no folder | `h27-bundle-clone-and-publish.sh` | automatic |
| H-28 | sbx-add registers a sandbox on a folder with a space in its path and refuses it twice; sbx-start and sbx-stop work by name with /bin/bash, ignore SBX_DIR, SBX_NAME and COMPOSE_PROJECT_NAME from your terminal, and keep the container and the files; sbx-stop returns in under 10 s; the test sandbox is restored on the run folder | h28-sbx-add-start-stop.sh | automatic |
| H-29 | sbx-upgrade with a bogus build option fails and leaves the sandbox as it was; sbx-upgrade rebuilds, recreates only sbx-hosttest (new container, other sbx containers unchanged), keeps the files in the project folder, state/ and state/claude (including a fake credentials file and a fake session file), keeps one bind mount and no volume, warns that open shells close, and starts a stopped sandbox | h29-sbx-upgrade.sh | automatic |
| H-30 | The tool versions line in the Claude test image (sbx-claude:test) matches versions.env, in the order claude, ccusage, then the base fields from gsd on (jdk from the TEMURIN_IMAGE tag, python from the image); an interactive shell prints it once, bash -c and bash -lc print nothing; sbx-upgrade ends with it (H-29) | h30-version-line.sh | automatic |
| H-31 | sbx-shell on a sandbox with no container starts it and waits for its start hooks, then (with no terminal) Docker refuses the shell; through a terminal it opens bash in /home/sandbox/workspace/hosttest on a running sandbox without recreating it, and on a stopped one after starting it again | `h31-sbx-shell.sh` | automatic |
| H-32 | sbx-list with an empty registry says so and lists the running sbx-hosttest as a labelled container with no entry, with no cc_ container; after sbx-add, sbx-start and sbx-stop the hosttest row reads no container, running and stopped with its folder (a space in its path), each matching docker ps -a; a sandbox on the current image is not marked | `h32-sbx-list.sh` | automatic |
| H-33 | sbx-rm of the running test sandbox without a terminal or --yes is refused and the sandbox, its entry and its files stay; with --yes it warns, takes its container and its network, and keeps its folder (a space in its path), its registry entry, the volumes, the test images and the other sbx containers; it runs again with no container, and with the folder moved away; --unregister deletes only the entry; sbx-add of the same folder and sbx-start bring back a file in state/claude and a line in the bash history | `h33-sbx-rm.sh` | automatic |

## Reading a failure

- **FAIL line:** shows the check ID and what went wrong, with detail lines under it.
- **NOT RUN:** an earlier step failed: the setup, or an earlier link of the chain H-08, H-16, H-23, H-09, H-28, H-29, H-31, H-32, H-33, H-20, H-10. Fix that one first.
- **Build failure:** the output names the log path, inside the run folder's `logs/`.
- **H-28, H-29, H-31, H-32 or H-33 failure:** their logs are `h28-*`, `h29-*`, `h31-*`, `h32-*` and `h33-*` in the run folder's `logs/`.
  - Each runs on its own folder with a space in its path and its own registry inside the run folder.
  - Each restores the test sandbox on the run folder at the end.
- **H-31 says BSD `script` on this Mac did not give sbx-shell a terminal:** paste the FAIL line and the log it names.
- **H-27 failure:** H-27 runs offline in its own folder under the run folder, and its logs are next to its `run.log` there.
- **"Mounts denied" during setup:** Docker Desktop does not share `$TMPDIR`. Add it in Settings, Resources, File sharing.
- **H-10 says Docker created the missing folder:** Compose ignored `create_host_path: false`. That is a real finding, not a script bug.
  - Do not change `compose.yml`.
  - See the env_file follow-up in [`README.md`, Troubleshooting](../README.md#troubleshooting-and-known-limits). It needs your approval.
- **H-20 says the sandbox started, or a folder appeared:** the start folder in `compose.yml` or the project-folder check in `base/sbx-start-lib.sh` changed. Do not create the folder by hand.
- **H-03 says an uppercase `SBX_NAME` was not refused:** `docker compose up` got past the `name-check` service in `compose.yml`. Paste the FAIL line; the refusal before anything is created needs another design, and README.md must not promise it until then.
- **Rebuilding retags the images:** your running sandboxes keep their old image until their next `docker compose up`. That is safe: all their data is in their folder.

## Clean up

Run the cleanup command that `run-all.sh` printed. It stops `sbx-hosttest` and deletes the run folder.

- Do it when you are done.
- The images stay.

## Record your results

Paste the `run-all.sh` summary.

- `docker compose version` output:
- Docker Desktop version:
- H-10 observation (what `up` printed, whether the folder existed afterwards):
- H-03 observation (what the uppercase `up` printed):

Any failure becomes input for gap-closure planning.
