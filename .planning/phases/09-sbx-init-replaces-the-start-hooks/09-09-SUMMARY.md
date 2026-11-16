---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 09
subsystem: infra
tags: [guard, bash, python, sbx-init, managed-settings]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: sbx-init, images without an entrypoint, host scripts that no longer read the start library (plans 06, 07, 08)
provides:
  - the old start path deleted (entrypoint, start library, five start hooks, bash linker, entrypoint self-test)
  - guard rules container_runs_no_entrypoint and agents_stay_off_the_path
  - a supply chain scan that covers the sbx-init code
  - one managed-settings deny entry (state/claude/skills/**)
  - host-test.sh step "guard in sbx-hosttest"
affects: [09-11, 09-12, 09-13]

status: complete
actuals:
  tokens: 12000
  tasks: 2
  commits: 2
plan_head_before: 7afaeecdca96d1fa3d5e256e486562ee70d892cf
plan_head_after: 27a9fd30ed9dcd88a2ebac4703ce28c66e04f295

tech-stack:
  added: []
  patterns:
    - "A guard rule that bans a thing (entrypoint, PATH link) names each regression with its own reason line"

key-files:
  created: []
  modified:
    - tests/guard/lib.sh
    - tests/guard/start.sh
    - tests/guard/supply-chain.sh
    - tests/guard/isolation.sh
    - host-test.sh
    - claude/managed-settings.json
    - claude/selfcheck/090_managed_settings.py
    - tests/selftest/selfcheck/test_claude_managed_settings.py

key-decisions:
  - "The two remaining tests that name deleted things on purpose (absence asserts in test_init_inventory.py, the legacy list file test and the wrapper text test) stay; they prove the new shape"

requirements-completed: [INIT-03]

duration: 15min
completed: 2026-11-16
---

# Phase 9 Plan 09: Delete the old start path Summary

**The entrypoint, start hooks, bash linker and entrypoint self-test are deleted, and two new guard rules (no entrypoint, agents off the PATH) keep the guard at 20 rules.**

## Accomplishments

- Deleted `base/sbx-entrypoint`, `base/sbx-start-lib.sh`, the five hooks in `claude/start.d` and `cursor/start.d`, the eight files of `tests/selftest/entrypoint/` (fake GSD included) and `base/bin/sbx-link-bundle`.
- `tests/guard/lib.sh`: `ENTRY` and `HOOK_DIRS` gone; `SANDBOX_FILES` and `SHELL_FILES` name no deleted path.
- `tests/guard/start.sh`: the two hook rules replaced by `container_runs_no_entrypoint` (no `ENTRYPOINT` line, no `entrypoint:` key, compose keeps `init: true` and `sleep infinity`) and `agents_stay_off_the_path` (smoke tests prove each agent is off the PATH, no `ln -s` into `/usr/local/bin`).
- `tests/guard/supply-chain.sh`: the compromised-package scan covers `base/init`, `claude/init`, `cursor/init` and `tests/selftest/init`; the dead `support/*` glob is gone.
- Managed settings deny only `Edit` on `state/claude/skills/**`, in the JSON, the self-check, the guard rule and the pytest file.
- `host-test.sh` runs only the guard in a step named "guard in sbx-hosttest".

## Task Commits

1. Task 1 (tracer): `b7010ad` feat(09-09): delete the entrypoint, start hooks and entrypoint self-test
2. Task 2: `27a9fd3` feat(09-09): drop the bash linker and the list file deny

## Verification

- `bash tests/guard/run-all.sh`: exactly 20 PASS lines, ends `All rules hold.`
- Negative checks (edits reverted): an `ENTRYPOINT` line in `base/Dockerfile` fails `container_runs_no_entrypoint`; an `ln -s ... /usr/local/bin/claude` line in either agent Dockerfile, or a missing `! command -v cursor-agent`, fails `agents_stay_off_the_path`.
- `uv run pytest -q`: 422 passed. `bash tests/selftest/sbx/run-all.sh`: `All cases pass.`
- Tracer gate: the slice (guard run) was re-run end to end after the commit and passed before the second task.

## Deviations from Plan

### Auto-fixed Issues

None in the code.

### Plan verify notes

**1. Verify `git grep` is broader than the intent.** The plan's `! git grep -nE 'sbx-entrypoint|...|start\.d|...' -- ... tests/selftest` and `! git grep -nE 'sbx-link-bundle|best-practices-skills' -- ... tests/selftest` still print hits in tests that assert the absence of the old things on purpose:
- `tests/selftest/init/test_init_inventory.py` lines 134 and 142 (`"sbx-entrypoint" not in text`, `"start.d" not in text`)
- `tests/selftest/init/test_init_best_practices_link.py` lines 212 to 217 (a list file left by an older image is left alone)
- `tests/selftest/init/test_init_wrappers.py` line 134 (a wrapper text must not mention the list file)

I kept them: they prove the new shape, and removing them would drop coverage. No product file names a deleted path.

## Known Stubs

None.

## Stale references left for later plans

- `.claude/CLAUDE.md` (lines about `sbx-entrypoint`, start hooks, `start.d`, the Architecture table) still describe the old path. Not edited here; it goes in a separate PR.
- `README.md`, `tests/README.md` and `tests/host-checklist.md` name the old files (plan 09-12).
- `tests/host/h17-start-offline-and-failing-hook.sh` still names the start path (plan 09-11).

## Threat Flags

None. T-09-23 (supply chain scan covers init code), T-09-24 (skills deny entry unchanged and still checked) and T-09-25 (two new guard rules) are mitigated as planned.

## Self-Check: PASSED

- Deleted paths absent: base/sbx-entrypoint, base/sbx-start-lib.sh, claude/start.d, cursor/start.d, tests/selftest/entrypoint, base/bin/sbx-link-bundle
- Commits b7010ad and 27a9fd3 present
