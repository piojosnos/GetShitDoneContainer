---
phase: 06-test-diet
plan: 02
subsystem: testing
status: complete
tags: [bash, guard, selftest, host-tests]

requires: ["06-01"]
provides:
  - "guard rule managed_settings_deny_skill_edits (isolation.sh)"
  - "guard rule claude_image_has_one_from_line (supply-chain.sh)"
  - "guard of 17 rules; entrypoint self-test of 43 cases"
affects: [06-04, 06-06, host-test.sh]

actuals:
  tokens: 11700
  tasks: 3
  commits: 3
plan_head_before: ce9c38b37a2727145c36dea4392c3d3913a47f21
plan_head_after: 7ea426e5c49efe284006bef5e611f5cbb9f17f30

tech-stack:
  added: []
  patterns:
    - "Guard rules are plain greps over source files; each new rule is proven able to fail once, on a scratch copy of the tree"

key-files:
  created: []
  modified:
    - tests/guard/isolation.sh
    - tests/guard/supply-chain.sh
    - tests/guard/start.sh
    - tests/selftest/entrypoint/start-folders.sh
    - host-test.sh
    - tests/README.md
  deleted:
    - tests/selftest/guard/helpers.sh
    - tests/selftest/guard/lib.sh
    - tests/selftest/guard/linters.sh
    - tests/selftest/guard/run-all.sh
    - tests/selftest/guard/sandbox-rules.sh
    - tests/selftest/entrypoint/start-library.sh

key-decisions:
  - "The deny rule lives in isolation.sh and the one-FROM rule in supply-chain.sh beside dockerfile_args_have_no_defaults; both are plain greps"
  - "host_scripts_keep_sandbox_data keeps the sbx-rm-is-missing check and the ban in every other bin/ script; only the sbx-rm source-line pin is gone"
  - "The sandbox name rule stays covered by the sbx-add self-test (32 characters, line break, non-ASCII); no case was added"

requirements-completed: [DIET-04, DIET-05]

coverage:
  - id: D1
    description: "managed_settings_deny_skill_edits and claude_image_has_one_from_line pass on the tree and print FAIL on a mutated scratch copy"
    requirement: DIET-04
    verification:
      - kind: other
        ref: "scratch-copy negative control from the task 1 verify block (output below); bash tests/guard/run-all.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Three start rules and the sbx-rm pin are gone; the ban on rm, rmdir, prune, kill, down and --volumes in other bin/ scripts still fails on a planted rm"
    requirement: DIET-04
    verification:
      - kind: other
        ref: "bash tests/guard/run-all.sh prints 17 PASS lines; scratch copy with an rm line in bin/sbx-list prints FAIL: host_scripts_keep_sandbox_data"
        status: pass
    human_judgment: false
  - id: D3
    description: "tests/selftest/guard/ is deleted and host-test.sh runs the guard and the entrypoint self-test only inside sbx-hosttest"
    requirement: DIET-04
    verification:
      - kind: other
        ref: "test ! -e tests/selftest/guard; grep for selftest/guard in host-test.sh, tests/README.md and tests/guard is empty; bash -n host-test.sh"
        status: pass
    human_judgment: false
  - id: D4
    description: "start-library.sh and the name-rule cases are gone; 43 entrypoint cases pass; the sbx-add name cases still pass"
    requirement: DIET-05
    verification:
      - kind: other
        ref: "bash tests/selftest/entrypoint/run-all.sh (43 PASS, All cases pass.); bash tests/selftest/sbx/add.sh name cases"
        status: pass
    human_judgment: false
  - id: D5
    description: "host-test.sh step 'guard and entrypoint self-test in sbx-hosttest' runs on the Mac"
    verification: []
    human_judgment: true
    rationale: "Needs the Mac and Docker Desktop; Docker is not available in the dev sandbox. Proven in the final plan's Mac run"
---

# Phase 6 Plan 2: Guard Trim and Entrypoint Self-Test Trim Summary

**The guard now reads the managed Edit deny entries and the one-FROM Claude image, loses three start rules, the sbx-rm source-line pin and its own self-test, and the entrypoint self-test loses start-library and the name-rule cases.**

## Performance

- **Duration:** about 15 min (start 2026-11-13T08:02Z, end 08:17Z)
- **Tasks:** 3
- **Files:** 6 modified, 6 deleted

## Accomplishments

- Added `managed_settings_deny_skill_edits` (both exact Edit deny entries must be present) and `claude_image_has_one_from_line` (one FROM line, exactly `FROM ${BASE_IMAGE}`); both fail on a mutated copy.
- Dropped `no_installs_at_container_start`, `compose_starts_in_the_workspace` and `agent_image_keeps_base_state_folders`; the two hook rules stay.
- Dropped the exact-line pin on `bin/sbx-rm`; the ban on rm, rmdir, prune, kill, down and `--volumes` in every other `bin/` script stays and fails on a planted rm.
- Deleted `tests/selftest/guard/` and its `host-test.sh` entry; the step is now `guard and entrypoint self-test in sbx-hosttest`.
- Deleted `start-library.sh` and the name-rule cases of `start-folders.sh`; `tests/README.md` matches (17 rules, no guard self-test section, no name rule in the entrypoint section).

## Task Commits

1. **Task 1: managed deny and one-FROM guard rules (tracer)** - `2b1f0d0` (test)
2. **Task 2: drop three start rules, the sbx-rm pin and the guard self-test** - `e94c69c` (test)
3. **Task 3: drop start-library and the name-rule cases** - `7ea426e` (test)

## Negative control (task 1, scratch copy without `.git` and `.planning`)

Mutation: the `skills/**` deny line removed from `claude/managed-settings.json`, `FROM debian` appended to `claude/Dockerfile`.

```
isolation.sh:    claude/managed-settings.json has no deny entry Edit(//home/sandbox/workspace/state/claude/skills/**)
                 FAIL: managed_settings_deny_skill_edits
supply-chain.sh: claude_image_has_one_from_line detail:
                 claude/Dockerfile must have exactly one FROM line, FROM ${BASE_IMAGE} (found 2 FROM lines)
                 FAIL: claude_image_has_one_from_line
```

Kept-ban control (task 2): an `rm -rf "$HOME/x"` line appended to `bin/sbx-list` in a scratch copy printed `bin/sbx-list:176:rm -rf "$HOME/x"` and `FAIL: host_scripts_keep_sandbox_data`.

## Verification

| Command | Result |
|---|---|
| `bash tests/guard/run-all.sh` | pass, 17 PASS, ends `All rules hold.` (20 after task 1, before task 2 trimmed it) |
| `bash tests/selftest/entrypoint/run-all.sh` | pass, 43 PASS, ends `All cases pass.`; `start-folders.sh` prints 3 PASS |
| `bash tests/selftest/sbx/run-all.sh` | pass, ends `All cases pass.` |
| `bash tests/selftest/sbx/add.sh` name cases (32 characters, line break, non-ASCII) | pass |
| `bash -n` on the edited scripts and `host-test.sh` | pass |
| `test ! -e tests/selftest/guard` and no `selftest/guard` in `host-test.sh`, `tests/README.md`, `tests/guard` | pass |
| all task acceptance criteria | pass |

Mac-only (not runnable here): `./host-test.sh` must show the step `guard and entrypoint self-test in sbx-hosttest` OK, with the guard at 17 rules and the entrypoint self-test at 43 cases, inside `sbx-hosttest`.

## Deviations from Plan

None - plan executed exactly as written.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. T-06-03, T-06-06 and T-06-07 are mitigated by the two new rules and the recorded negative control; T-06-04 and T-06-05 are accepted as planned.

## Notes for the review

- The new guard rules check the source files, not the built image. H-14 reads the parsed deny list in the image; the one-FROM rule has no image-side check after this phase (the flagged assumption in the plan).
- `tests/guard/lib.sh` still has a comment saying SHELL_FILES uses globs because "the self-test copy has no .git"; the guard self-test is gone, so the comment is slightly stale. Left as is (out of scope).

## Self-Check: PASSED

- Commits `2b1f0d0`, `e94c69c`, `7ea426e` exist on `chore/phase-06-test-diet`.
- `tests/selftest/guard/` and `tests/selftest/entrypoint/start-library.sh` are absent; the edited files exist.
