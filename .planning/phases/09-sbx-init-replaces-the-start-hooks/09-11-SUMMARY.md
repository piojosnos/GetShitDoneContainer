---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 11
subsystem: testing
tags: [host-tests, bash, sbx-init, flock, ownership]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: sbx-init, the sbx-claude wrapper refusal, sbx-bundle-clone running init (plan 06), compose_up running init (plan 10)
provides:
  - H-27 rewritten as the first-run walk on the real Claude image
  - H-16 rewritten for relinking by sbx-init and the clash rule
  - check_bundle_links without the list file
  - H-35, a new sandbox check for the ownership fix and the run lock
  - run-all.sh listing 17 host checks
affects: [09-12, 09-13]

status: complete
actuals:
  tokens: 7400
  tasks: 3
  commits: 3
plan_head_before: 3d218af14b017ce23dfa87429028a52fe488d929
plan_head_after: da9297eebb3ec9aefcc80b01ca74e1be9e355160

tech-stack:
  added: []
  patterns:
    - "a lock holder started with docker exec -d and stopped with pkill -f, polled with flock -n"
    - "clash checks move user-like data aside into the run folder, never delete it"

key-files:
  created:
    - tests/host/h35-init-owner-and-lock.sh
  modified:
    - tests/host/h27-bundle-clone-and-publish.sh
    - tests/host/h16-live-clone-and-restart.sh
    - tests/host/lib-bundle.sh
    - tests/host/run-all.sh

key-decisions:
  - "The clash assertion in H-16 matches the FAIL line on state/claude/rules and skills/sbx-fixture-one, the full paths init prints, so a bare 'rules' cannot match by accident"

requirements-completed: [INIT-01, INIT-02, INIT-04, INIT-05, INIT-06]

duration: 12min
completed: 2026-11-16
---

# Phase 9 Plan 11: Host checks for init on the real images Summary

**H-27 walks the first run (refused, init without a clone, clone runs init, agent starts, offline GSD sync), H-16 proves the clash rule and relinking, and the new H-35 proves the ownership fix and the run lock on Docker Desktop.**

## Accomplishments

- H-27 (tracer): one offline `docker run` now runs `before`, `plainpath`, `noclone`, `clone`, `read`, `again`, `push`, `after` and `missing`. Eleven check functions assert the refusal text, claude off the plain PATH, the three OK lines and the links FAIL with its fix line, the 4-step closing line, the clone refusal naming `sbx-init`, the pinned `--version` after init, and `state/claude/gsd-core/VERSION` equal to the `GSD_CORE_VERSION` pin with no `npx` or `@latest` in the init output.
- H-16 keeps the live-edit and pull checks. `plant_files` no longer plants a list file entry, a stale rules folder or a stale bundle skill. New `check_clash_kept_and_reported` plants a real `skills/sbx-fixture-one` and a real `rules` folder and requires exit 1, a `claude-best-practices-links` FAIL naming both, both files intact and no marker. `restore_after_clash` moves them aside and requires a passing rerun and valid links.
- `check_bundle_links` drops the list file comparison and instead reports any link into the clone for a skill the clone no longer has.
- H-35 plants a root-owned file through a throwaway root container, holds the lock with a python `flock` holder, asserts the refused run (`FAIL: lock: another sbx-init is running`, `stopped at lock`, marker and owner unchanged), always releases the lock, then asserts init gives the file back to uid 1000 and leaves nothing root-owned outside the skipped caches.
- `run-all.sh` runs H-35 after H-34; 17 host checks are listed and all files exist.

## Task Commits

1. Task 1 (tracer): `82b85b4`
2. Task 2: `6561b53`
3. Task 3: `da9297e`

## Deviations from Plan

- `check_stale_files_gone` in H-16 became `check_dropped_skill_gone`, since the stale copies it also checked are no longer planted. No behavior was dropped that the plan kept.
- The tracer gate could not run end to end (no Docker here); its automated verify (`bash -n`, grep assertions, guard) passed, and plan 09-13 runs the check on the Mac.

## Verification

`bash -n` passes on all five files; `bash tests/guard/run-all.sh` ends with `All rules hold.`; H-35 is git mode 100644; no `rm -r` appears in H-16 or H-35. The host checks run on the Mac in plan 09-13.

## Known Stubs

None.

## Threat Flags

None. The root container in H-35 is `--rm`, `--network none`, uses `$BASE_IMAGE` and `--volumes-from` the test container only, and changes one file it makes.

## Self-Check: PASSED

The five files exist and commits `82b85b4`, `6561b53` and `da9297e` exist.
