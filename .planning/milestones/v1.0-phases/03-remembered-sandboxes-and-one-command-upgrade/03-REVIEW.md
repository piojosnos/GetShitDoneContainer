---
phase: 03-remembered-sandboxes-and-one-command-upgrade
reviewed: 2026-11-07T00:10:00Z
depth: standard
files_reviewed: 27
files_reviewed_list:
  - SANDBOX.md
  - base/Dockerfile
  - base/sbx-start-lib.sh
  - bin/sbx-add
  - bin/sbx-lib.sh
  - bin/sbx-start
  - bin/sbx-stop
  - bin/sbx-upgrade
  - claude/Dockerfile
  - host-test.sh
  - tests/README.md
  - tests/guard/isolation.sh
  - tests/guard/lib.sh
  - tests/guard/supply-chain.sh
  - tests/host-checklist.md
  - tests/host/h28-sbx-add-start-stop.sh
  - tests/host/h29-sbx-upgrade.sh
  - tests/host/h30-version-line.sh
  - tests/host/lib-sbx.sh
  - tests/host/manual/h29-upgrade-resume.sh
  - tests/host/run-all.sh
  - tests/selftest/guard/sandbox-rules.sh
  - tests/selftest/sbx/add.sh
  - tests/selftest/sbx/entry.sh
  - tests/selftest/sbx/lib.sh
  - tests/selftest/sbx/run-all.sh
  - tests/selftest/sbx/upgrade.sh
findings:
  critical: 1
  warning: 3
  info: 5
  total: 9
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-11-07T00:10:00Z
**Depth:** standard
**Files Reviewed:** 27
**Status:** issues_found

## Summary

The registry reader is sound: values are read as text and never sourced, and the name rule is shared with the container through `base/sbx-start-lib.sh`. The guard and the sbx self-test pass on Linux (the two linter rules fail only because shellcheck and hadolint are not installed here). Docker could not be run, so the host checks H-28 to H-30 were read, not executed.

The main concern is a gap in the isolation model. `sbx-add` protects the registry from a sandbox that can reach it, but not the repo. The repo's own files run on the Mac (`bin/*`, `base/sbx-start-lib.sh` sourced on every `sbx-*` call, `compose.yml`, `build.sh`, `versions.env`), so a sandbox folder that holds the repo gives the agent code execution on the host. I reproduced this with a stand-in `docker`.

There is also a silent `set -e` exit in `wait_until_ready`, which I reproduced (exit 1 with empty stderr), and a destructive `sbx-start` on a running sandbox.

No hardcoded secrets, no unsafe `eval`, no non-ASCII characters, no dash-as-punctuation or planning-ID leaks in the changed lines. The bash 3.2 and BSD constructs I checked (`${!1}`, `[[ =~ ]]` with an unquoted variable, `$'\n'`, `local LC_ALL=C`, noclobber in a subshell) are portable.

## Critical Issues

### CR-01: sbx-add accepts a sandbox folder that holds the repo, which gives the agent code execution on the Mac

**File:** `bin/sbx-add:98-103` (also `bin/sbx-lib.sh:34-36`, `bin/sbx-upgrade:36`)
**Issue:** `refuse_registry_overlap` exists because "a sandbox that reaches the registry could rewrite its own entry". The same reasoning applies to the repo and is not enforced. The host runs these repo files:
- `sbx_init` sources `base/sbx-start-lib.sh` on every `sbx-*` call (`read_start_variable`).
- `sbx-lib.sh` and `bin/sbx-*` run on the Mac.
- `compose.yml` is passed to `docker compose`. An edit could add a Docker socket mount or privileged mode.
- `build.sh` runs in `sbx-upgrade` and sources `versions.env`, which its own header calls "code".

If the registered folder is, holds or sits inside `repoDir`, for example `~/code` with the repo at `~/code/GetShitDoneContainer`, the agent can edit any of those files. The next `sbx-start`, `sbx-stop` or `sbx-upgrade` then runs the agent's code as the Mac user, outside the container. This breaks the project's core constraint that agents never run on the host and see only their own mount.

Reproduced with a stand-in `docker` and `SBX_CONFIG_DIR` outside HOME: `sbx-add repoholder /home/sandbox` (a parent of the repo) exits 0 and writes the entry. In normal use only HOME itself is refused, because the registry sits under it; any other parent of the repo is accepted. The same hole exists for a folder inside `repoDir`.

The self-tests never cover this case, so the gap passes unnoticed.

**Fix:**
```bash
# in bin/sbx-add, next to refuse_registry_overlap
refuse_repo_overlap() {
  if paths_overlap "$1" "$repoDir"; then
    sbx_error "'$1' overlaps the repo folder $repoDir; a sandbox there could change the scripts the Mac runs. Pick another folder."
    return 1
  fi
}
# Main: call it after refuse_registry_overlap "$hostPath"
refuse_repo_overlap "$hostPath"
```
Add self-test cases in `tests/selftest/sbx/add.sh` for the repo itself, its parent and a path inside it. Update the "It refuses" list in `SANDBOX.md`. Note that `sbx_init` already sets `repoDir` with `pwd -P`, so the user's text path may need the same resolution before comparing (see WR-03).

## Warnings

### WR-01: wait_until_ready exits silently under set -e when the container is gone

**File:** `bin/sbx-lib.sh:232`
**Issue:** `running=$(docker container inspect ... 2>/dev/null </dev/null)` has no `|| ...` guard. The three callers (`sbx-start`, `sbx-upgrade`) run it as a plain command under `set -eu`, so errexit is active inside the function. If `inspect` fails (container removed between the compose call and the poll, or the daemon restarting), the script exits 1 on that line. The helpful `stopped during its start; docker logs ...` branch is never reached. Reproduced: with a stand-in `docker` that fails `exec` and `container inspect`, `sbx-start demo` printed nothing and exited 1. The common failure the message was written for (a failing start hook) can go the same way if Compose removes the container.

**Fix:**
```bash
running=$(docker container inspect --format '{{.State.Running}}' "sbx-$sandboxName" 2>/dev/null </dev/null) || running=""
```
Add a self-test with a stand-in `docker` that succeeds for `compose` and fails for `exec` and `container inspect`, and expect the `stopped during its start` message. The current stand-in refuses every call, so nothing past the pre-Docker checks is exercised.

### WR-02: sbx-start silently recreates a running sandbox after an upgrade, closing its sessions with no warning

**File:** `bin/sbx-start:15-19` (behaviour documented in `SANDBOX.md`, "Other sandboxes keep their old image until their next `sbx-start`")
**Issue:** `up -d --wait` recreates the container whenever the image behind `sbx-claude:local` changed. After `sbx-upgrade A`, sandbox B is still running on the old image with open shells and Claude sessions. Running `sbx-start B` as an "ensure it is up" habit kills those sessions at once, with no warning. `sbx-upgrade` takes care to print that warning (`warn_if_running`), so the two scripts are inconsistent about the same destructive action. Files are safe (state is on the mount), but in-flight Claude work is lost.

**Fix:** In `sbx-start`, when `sandbox_is_running "$1"`, compare the container's image id with the image and warn or refuse:
```bash
runningImage=$(docker container inspect --format '{{.Image}}' "sbx-$1" </dev/null)
currentImage=$(docker image inspect --format '{{.Id}}' "$claudeImage" </dev/null)
if [ "$runningImage" != "$currentImage" ]; then
  echo "sbx-start: sbx-$1 runs on an older image; recreating it will close its open shells and Claude sessions"
fi
```
Alternatively use `up -d --no-recreate` for a running container and point at `sbx-upgrade` for the move to new images. Update `SANDBOX.md` to match.

### WR-03: Overlap checks compare text only, which macOS case-insensitivity and symlinks defeat

**File:** `bin/sbx-add:63-80` (used by `refuse_registry_overlap` and `refuse_sandbox_overlap`)
**Issue:** The checks protect two things: the registry stays out of every mount, and two sandboxes never share a `state/` (logins, history). The comparison is plain text, and the header says "a symlink is not followed". On the user's only host (macOS, default case-insensitive APFS) these are all the same folder yet pass:
- `/Users/me/Proj` vs `/Users/me/proj`
- `/Users/me/.Config/sbx` vs `/Users/me/.config/sbx`
- `/tmp/x` vs `/private/tmp/x`
- a path through a symlink, or an `SBX_CONFIG_DIR` with `..` in it

I confirmed that `/t/SB/x` and `/t/sb` register side by side (on Linux they differ, so this only shows the check is case-sensitive text). The result is two sandboxes on one folder, or a sandbox that holds the registry, which is the exact failure the checks claim to prevent. The documented limit covers symlinks; the case-insensitive filesystem is not mentioned.

**Fix:** Compare by identity, not text. After resolving, test with `-ef` against the deepest existing ancestor, or create the folder and then compare `cd -P ... && pwd -P` results lowercased with `tr '[:upper:]' '[:lower:]'`. If folder creation must stay after the checks, walk up from the candidate to the first existing ancestor and use `[ "$ancestor" -ef "$other" ]` for each registered folder, the registry folder and the repo folder. At minimum, document the case-insensitive limitation next to the symlink one.

## Info

### IN-01: The "never delete" guard is a grep with easy gaps

**File:** `tests/guard/isolation.sh:38-40`
**Issue:** `\b(rm|rmdir|prune|kill|down)\b|--volumes` covers the obvious spellings and is the only enforcement of "host scripts must never delete sandbox data". It misses `docker volume` and `docker system` subcommands other than `prune`, `up --remove-orphans`, `up -V` / `--renew-anon-volumes`, `find ... -delete`, `unlink`, `mv` over a file, a `>` truncation, and any command built in a variable. It also matches comments and message strings, so a future comment containing "slow down" or "kill" fails the rule. The self-test only plants `rm -rf` and `down -v`.
**Fix:** Add the missing tokens to the regex and plant one case for each in `tests/selftest/guard/sandbox-rules.sh`. State in the rule's comment that it is a tripwire, not a proof.

### IN-02: sbx-stop reports "is stopped" for a sandbox that was never created

**File:** `bin/sbx-stop:33`
**Issue:** `docker compose stop` exits 0 when no container exists, so `sbx-stop` of a registered but never started sandbox prints `sbx-NAME is stopped; nothing in DIR was changed`. H-28 (`check_stop_before_start`) pins exit 0 but not the wording. The line is also printed even though the registered folder was never checked, so it vouches for a folder it did not look at.
**Fix:** Test `docker container inspect "sbx-$1"` first and print `sbx-NAME has no container; nothing to stop`, or drop the folder claim.

### IN-03: One stray file in the registry folder blocks every sbx-add

**File:** `bin/sbx-add:115-127`
**Issue:** `refuse_sandbox_overlap` feeds every regular, non-dot file in `registryDir` through `read_registry_entry`. An editor backup (`demo~`), a note, or `demo.bak` fails with `has no absolute SBX_DIR`, and no new sandbox can be added until it is removed. Reproduced with an empty `demo~`: `sbx-add other ...` exited 1. The selftest "a broken entry stops sbx-add" treats this as intended for a real broken entry, but it does not separate a broken entry from a file that was never an entry.
**Fix:** Skip files whose name fails `check_name` (they cannot be entries), keep the hard stop for names that follow the rule, and mention the skipped name on stderr.

### IN-04: Readiness probe `pgrep -x sleep` can pass early and is reused by the tests that verify it

**File:** `bin/sbx-lib.sh:222-229`; `tests/host/h28-sbx-add-start-stop.sh:116`; `tests/host/h29-sbx-upgrade.sh:182`
**Issue:** Any process named `sleep` in the container counts as "hooks done". `claude/bin/sbx-claude:23` runs `sleep 5`, and any future hook that sleeps would do the same. H-28 and H-29 then assert readiness with the same probe, so they cannot catch a false positive. The code comment already names the healthcheck as the replacement.
**Fix:** Plan the healthcheck, or have the entrypoint touch a marker file (for example `/run/sbx-ready`) right before `exec "$@"`, and test that with `docker exec ... test -e`.

### IN-05: mac_sbx_selftest leaves its temp folder on interrupt and does not check the link

**File:** `host-test.sh:157-175`
**Issue:** `rm -rf "$standinDir"` runs only on the normal path, so an interrupted run leaves `sbx-bash.XXXXXX` in `$TMPDIR`. `ln -s /bin/bash "$standinDir/bash"` is unchecked, so a failed link makes the suite run under a different bash than the one it reports.
**Fix:** `ln -s /bin/bash "$standinDir/bash" || return 1`, and register `trap 'rm -rf "$standinDir"' RETURN` (or an EXIT trap in `main`) right after `mktemp`.

---

_Reviewed: 2026-11-07T00:10:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
