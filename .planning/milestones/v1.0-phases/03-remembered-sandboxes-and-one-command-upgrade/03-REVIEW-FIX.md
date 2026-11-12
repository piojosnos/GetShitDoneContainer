---
phase: 03-remembered-sandboxes-and-one-command-upgrade
fixed_at: 2026-11-07T00:40:00Z
review_path: .planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 3: Code Review Fix Report

**Fixed at:** 2026-11-07T00:40:00Z
**Source review:** .planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (CR-01, WR-01, WR-02, WR-03; IN-01 to IN-05 were out of scope)
- Fixed: 4
- Skipped: 0

Verification ran in the main checkout on branch `chore/phase-03-run` (no worktree), on Linux with bash 5.3 and no Docker. Nothing here ran under macOS `/bin/bash` 3.2, BSD tools, a case-insensitive disk or real Docker; see "Needs the Mac".

## Fixed Issues

### CR-01: sbx-add accepts a sandbox folder that holds the repo

**Files modified:** `bin/sbx-add`, `tests/selftest/sbx/add.sh`, `SANDBOX.md`
**Commit:** ae1763f
**Applied fix:** New `refuse_repo_overlap` next to `refuse_registry_overlap`, called right after it, same style and wording ("overlaps the repo folder ..."). `repoDir` comes from `sbx_init` (resolved with `pwd -P`). `SANDBOX.md` lists the new refusal and the error text in the troubleshooting table.
**Tests added:** `case_repo_overlap` (6 cases): the repo folder itself, a folder that holds it, a folder inside it, no `state/` made in the repo or its holder, and a folder that only shares a text prefix (`repo-other`) accepted. The case runs the scripts from a copy of `bin/` and the start library under the work folder, so a failing case never makes folders in the real repo. Confirmed to fail against the old `sbx-add` (4 FAIL).

### WR-01: wait_until_ready exits silently under set -e when the container is gone

**Files modified:** `bin/sbx-lib.sh`, `tests/selftest/sbx/lib.sh`, `tests/selftest/sbx/start.sh` (new), `tests/README.md`
**Commit:** 2bb1261
**Applied fix:** `running=$(docker container inspect ...) || running=""`, as the review suggested, plus a comment saying why. A vanished container now reaches the `stopped during its start; docker logs ...` error.
**Tests added:** New group `tests/selftest/sbx/start.sh` and a scripted docker stand-in in `lib.sh` (`make_scripted_docker`, `set_standin_state`, `run_sbx_scripted`). It answers from files in the work folder, logs to its own file, and leaves the refusing stand-in untouched, so "no case reached docker" still holds. Cases: compose succeeds, exec and container inspect fail, expect exit 1 and the stopped message; compose ran. Confirmed to fail against the old library. Status: fixed.

### WR-02: sbx-start silently recreates a running sandbox after an upgrade

**Files modified:** `bin/sbx-start`, `bin/sbx-upgrade`, `bin/sbx-lib.sh`, `tests/selftest/sbx/start.sh`, `tests/host/h28-sbx-add-start-stop.sh`, `SANDBOX.md`
**Commit:** addc6cd
**Applied fix:** Chose the warn option (behaviour otherwise unchanged: it still recreates and starts). `sbx-start` runs `warn_if_older_image` before `up`: only for a running container, it compares `docker container inspect '{{.Image}}'` with `docker image inspect '{{.Id}}' sbx-claude:local` and warns when they differ; a failed inspect skips the warning. The wording comes from a new shared `warn_sessions_close` in `sbx-lib.sh`, which `sbx-upgrade` now also uses. The `sbx-upgrade` line is byte for byte what it was, so H-29's grep still matches. `SANDBOX.md` (Start and Upgrade sections) describes the warning and says it does not wait for an answer.
**Tests added:** In `start.sh`: older image warned, warning printed before the compose call, start still succeeds; current image not warned; stopped container not warned; no container not warned; the shared helper reproduces the old `sbx-upgrade` line exactly. In `h28`: `check_start_running`, a third `sbx-start` on the running sandbox must exit 0, print no "older image" text and keep the same container id (guards against a false positive if the two ids are not comparable on the Mac's Docker).

### WR-03: Overlap checks compare text only

**Files modified:** `bin/sbx-add`, `tests/selftest/sbx/add.sh`, `SANDBOX.md`
**Commit:** 841ba8c
**Applied fix:** `paths_overlap` now compares folders. `locate_folder` walks a path up to its deepest existing folder and resolves it with `cd -P && pwd -P`, leaving a tail for the part that does not exist yet. `paths_overlap` then compares the two bases with `[ a -ef b ]`; if they are the same folder, the tails are compared per segment (new `tails_overlap`, lowercased, because APFS ignores case); if not, `folder_within` walks one base up its parents with `-ef` to see whether it sits inside the other, but only when the other path fully exists. A path that cannot be resolved counts as an overlap (the safe side). Used for the registry, repo and sandbox checks alike. Only bash 3.2 and BSD constructs: `-ef`, `cd -P`, `pwd -P`, `tr '[:upper:]' '[:lower:]'`. The header comment that said symlinks are not followed is replaced; `SANDBOX.md` has one bullet saying the checks compare folders.
**Tests added:** `case_same_folder` plus two symlink cases in `case_repo_overlap`: a symlink to another sandbox's folder, a folder inside such a symlink, a symlink that holds another sandbox's folder, a folder inside a symlink to the registry, the registry given as a symlink, a registry folder that does not exist yet compared without letter case, and a repo symlink (and a folder inside it). A same-folder-in-another-case check runs only when the disk is case-insensitive (`[ "$WORK/SBX ONE" -ef "$WORK/sbx one" ]`); on Linux it prints an INFO line instead. Nine of these fail against the old text comparison. Status: fixed, requires human verification (logic change in a safety check, and its main motivation, APFS and `/tmp` against `/private/tmp`, cannot be exercised on Linux).

## Needs the Mac

- `./host-test.sh`: its `mac_sbx_selftest` step runs the whole sbx self-test under `/bin/bash` 3.2. It is the first run of the new overlap code (`-ef`, `cd -P`, `tr`) under BSD tools, and the only place the case-insensitive APFS case runs (it should print PASS for "the same folder in another letter case is refused", not the INFO line). Also worth a manual `sbx-add x /tmp/somewhere` after registering a sandbox at `/private/tmp/somewhere`.
- H-28: new `check_start_running` proves that `.Image` of a container and `.Id` of `sbx-claude:local` compare equal on the Mac's Docker (a false "older image" warning fails the check). This is the one assumption in WR-02 that Linux could not prove.
- H-29: unchanged in intent; re-run to confirm the `sbx-upgrade` warning still matches after moving to the shared helper.
- Not covered by any automated check: the true-positive path (a running sandbox on an image that was really replaced). Manual: `sbx-upgrade A`, leave B running, run `sbx-start B`, expect the warning and then a recreated container. The self-test proves it only against the stand-in.

## Not changed

- IN-01 to IN-05 were out of scope and are untouched.

---

_Fixed: 2026-11-07T00:40:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
