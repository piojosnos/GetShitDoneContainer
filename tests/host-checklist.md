# Host checklist (H-03 to H-35)

The test plan for the sbx sandbox: checks that can only be proven on the host, because Docker does not run in the dev sandbox. One script runs all the checks with nobody at the keyboard.

- **IDs:** each check has an ID, H-03 to H-35 (H for host), so results can be reported by ID ("H-10 failed"). The IDs keep their gaps: a check that was dropped leaves its number unused.
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
- Makes a throwaway root certificate once, keeps it in `$TMPDIR/sbx-hosttest-root-ca/` (its private key is deleted at once) and reuses it, so the build cache holds; builds it into the test images through `SBX_CA_CERT`, after your own root when you set one.
- Makes a fresh directory under `$TMPDIR` named `sbx-hosttest-...` and starts a test sandbox named `sbx-hosttest` on it.
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
| H-03 | Name and directory variables are required; `up` refuses an uppercase name before it creates anything; Compose renders the Claude test image `sbx-claude:test` | `h03-variable-interpolation.sh` | automatic |
| H-06 | Git works in the container on a repository made on the host (no dubious ownership) | `h06-git-on-host-repo.sh` | automatic |
| H-08 | Shell history survives a recreate | `h08-history-survives-recreate.sh` | automatic |
| H-09 | Files, a planted memory, a fake credentials file and a fake session file survive a rebuild, no volumes exist | `h09-rebuild-keeps-files-no-volumes.sh` | automatic |
| H-10 | A missing directory is refused | `h10-missing-dir-refused.sh` | automatic |
| H-16 | The clone is live: an edit on the host and a pull inside the sandbox show in the sandbox at once (the host never runs git on the clone). `sbx-init` relinks it: it links a new skill, removes the link of a dropped skill and keeps an uncommitted edit. A directory of yours named like a clone skill and a real `rules` directory are kept and reported as a FAIL, and your own skills, memories, sessions, settings keys and `CLAUDE.md` are spared | `h16-live-clone-and-restart.sh` | automatic |
| H-23 | The npm, uv and Maven caches live in the state directory and a file in each survives a recreate | `h23-caches-survive-recreate.sh` | automatic |
| H-25 | The `versions.env` record in the Claude test image equals the repo's, and a build without build.sh stops naming the missing pin (the Claude build gets the test base image) | `h25-images-match-versions.sh` | automatic |
| H-26 | The test sandbox has exactly one mount, a bind at /home/sandbox/workspace; it is not privileged, drops every capability, adds none, has no-new-privileges and no unconfined profile, shares no host namespace (network, PID, IPC, UTS, user) and has no device or extra group (read from docker inspect) | `h26-isolation-by-inspect.sh` | automatic |
| H-27 | In a fresh sandbox directory, offline: `sbx-claude` refuses before `sbx-init`; `sbx-init` with no clone FAILs at the best-practices step; `sbx-best-practices-clone` clones and runs `sbx-init`; GSD is synced at the pin; a branch is pushed to the origin; the agent then starts; a failed clone leaves no directory; a login shell started through `sbx-claude` finds `claude` in the agents directory and a plain login shell does not | `h27-best-practices-clone-and-publish.sh` | automatic |
| H-28 | sbx-add registers a sandbox on a directory with a space in its path and refuses it twice; sbx-start and sbx-stop work by name with /bin/bash, ignore SBX_DIR, SBX_NAME and COMPOSE_PROJECT_NAME from your terminal, and keep the container and the files; sbx-stop returns in under 10 s; the test sandbox is restored on the run directory | h28-sbx-add-start-stop.sh | automatic |
| H-29 | sbx-upgrade with a bogus build option fails and leaves the sandbox as it was; sbx-upgrade rebuilds, recreates only sbx-hosttest (new container, other sbx containers unchanged), keeps the files in the project directory, state/ and state/claude (including a fake credentials file and a fake session file), keeps one bind mount and no volume, warns that open shells close, and starts a stopped sandbox | h29-sbx-upgrade.sh | automatic |
| H-31 | sbx-shell on a sandbox with no container starts it, then (with no terminal) Docker refuses the shell; through a terminal it opens bash in /home/sandbox/workspace/hosttest on a running sandbox without recreating it, and on a stopped one after starting it again | `h31-sbx-shell.sh` | automatic |
| H-32 | sbx-list with an empty registry says so and lists the running sbx-hosttest as a labelled container with no entry, with no cc_ container; after sbx-add, sbx-start and sbx-stop the hosttest row reads no container, running and stopped with its directory (a space in its path), each matching docker ps -a; a sandbox on the current image is not marked | `h32-sbx-list.sh` | automatic |
| H-33 | sbx-rm of the running test sandbox without a terminal or --yes is refused and the sandbox, its entry and its files stay; with --yes it warns, takes its container and its network, and keeps its directory (a space in its path), its registry entry, the volumes, the test images and the other sbx containers; it runs again with no container, and with the directory moved away; --unregister deletes only the entry; sbx-add of the same directory and sbx-start bring back a file in state/claude and a line in the bash history | `h33-sbx-rm.sh` | automatic |
| H-34 | `sbx-init` passes first in the Claude test sandbox and in a Cursor test sandbox that H-34 starts with sbx-add and sbx-start and removes with sbx-rm; then `sbx-selfcheck` passes in each: no FAIL line, and as many check lines as the constant for that agent at the top of the script. The two `extra-ca-` checks compare, inside the image, the fingerprint of the throwaway root that `build.sh` recorded in `/etc/sbx/extra-ca-fingerprints` with the system bundle and Java `cacerts`, and H-34 fails when either prints `no extra root certificate requested`, because the test images always carry the root. It plants a git identity and a fake login file first. In the Cursor test sandbox it also checks that a login shell started through `sbx-cursor` finds `cursor-agent` in the agents directory and a plain login shell does not | `h34-selfcheck.sh` | automatic |
| H-35 | `sbx-init` gives a root-owned file in `state/claude` back to `sandbox`, and a second run is refused while one holds the lock | `h35-init-owner-and-lock.sh` | automatic |

## Reading a failure

- **FAIL line:** shows the check ID and what went wrong, with detail lines under it.
- **NOT RUN:** an earlier step failed: the setup, or an earlier link of the chain H-08, H-16, H-23, H-09, H-28, H-29, H-31, H-32, H-33, H-10. Fix that one first.
- **Build failure:** the output names the log path, inside the run directory's `logs/`.
- **H-28, H-29, H-31, H-32 or H-33 failure:** their logs are `h28-*`, `h29-*`, `h31-*`, `h32-*` and `h33-*` in the run directory's `logs/`.
  - Each runs on its own directory with a space in its path and its own registry inside the run directory.
  - Each restores the test sandbox on the run directory at the end.
- **H-34 failure:** the detail lists every FAIL line of `sbx-selfcheck` with its `fix:` line, and a message that an `extra-ca-` check says no root was requested (the build lost the certificate and its fingerprint); the full outputs are `h34-claude.out` and `h34-cursor.out` in the run directory's `logs/`. A login-shell message points at `h34-cursor-session-login.out` or `h34-cursor-plain-login.out` in the same directory. A count message means a check was added or removed: update `expectedClaudeCount` or `expectedCursorCount` in `h34-selfcheck.sh` with the check lists. If it says `sbx-hosttest-cursor` is still there, remove it with `docker rm -f sbx-hosttest-cursor`.
- **H-31 says BSD `script` on this macOS host did not give sbx-shell a terminal:** paste the FAIL line and the log it names.
- **H-27 failure:** H-27 runs offline in its own directory under the run directory, and its logs are next to its `run.log` there. A login-shell message points at `sessionlogin.out` and `plainlogin.out`: the first holds what a login shell inside the `sbx-claude` session found, the second what a plain login shell found.
- **H-35 says the planted file did not become root-owned:** Docker Desktop's file sharing changed how it keeps owners. If the owner stays root after `sbx-init`, the sandbox user cannot change owners on this host; `no-root-owned-state` in `sbx-selfcheck` shows the paths.
- **"Mounts denied" during setup:** Docker Desktop does not share `$TMPDIR`. Add it in Settings, Resources, File sharing.
- **H-10 says Docker created the missing directory:** Compose ignored `create_host_path: false`. That is a real finding, not a script bug.
  - Do not change `compose.yml`.
  - See the env_file follow-up in [`README.md`, Troubleshooting](../README.md#troubleshooting-and-known-limits). It needs your approval.
- **H-03 says an uppercase `SBX_NAME` was not refused:** `docker compose up` got past the `name-check` service in `compose.yml`. Paste the FAIL line; the refusal before anything is created needs another design, and README.md must not promise it until then.
- **Rebuilding retags the images:** your running sandboxes keep their old image until their next `docker compose up`. That is safe: all their data is in their directory.

## Clean up

Run the cleanup command that `run-all.sh` printed. It stops `sbx-hosttest` and deletes the run directory.

- Do it when you are done.
- The images stay.
- The test root certificate in `$TMPDIR/sbx-hosttest-root-ca/` stays, so the next run reuses it; `./clean.sh --yes` removes it with the run directories.

## Record your results

Paste the `run-all.sh` summary.

- `docker compose version` output:
- Docker Desktop version:
- H-10 observation (what `up` printed, whether the directory existed afterwards):
- H-03 observation (what the uppercase `up` printed):

Any failure becomes input for gap-closure planning.
