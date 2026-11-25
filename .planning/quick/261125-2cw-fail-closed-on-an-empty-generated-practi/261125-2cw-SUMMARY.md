---
phase: quick-261125-2cw
plan: 01
subsystem: best-practices-links
tags: [init, selfcheck, fail-closed, best-practices]
requires: []
provides:
  - clone_failure fails closed on an empty generated rules or skills directory
affects: [sbx-init, sbx-selfcheck]
tech-stack:
  added: []
  patterns: [fail closed before any link is placed or removed]
key-files:
  created: []
  modified:
    - base/selfcheck/best_practices_links.py
    - tests/unit/init/test_init_best_practices_linker.py
    - tests/unit/selfcheck/test_best_practices_links.py
    - README.md
decisions:
  - "Empty skills = no non-hidden subdirectory; empty rules = no non-hidden regular file"
  - "Empty detail reads 'has no rule in generated/AGENT/rules/' / 'has no skill in generated/AGENT/skills/'; missing-directory text unchanged; hint unchanged"
  - "Fix lives in clone_failure only; the linker is untouched"
metrics:
  duration: ~10m
  completed: 2026-11-25
status: complete
actuals:
  tasks: 2
  commits: 1
plan_head_before: 21981fb43eb3e249195529e0ad152b77a7112fbc
plan_head_after: ed8bb84d61b5a6f28c0170d114a77f4115a059cc
---

# Quick 261125-2cw: Fail closed on an empty generated practices directory

An empty `generated/AGENT/rules/` or `skills/` in the best-practices clone now fails `sbx-init` and `sbx-selfcheck` as an incomplete clone, and init no longer removes the own skill links in that case.

## Commits

| Branch | SHA | Subject |
| ------ | --- | ------- |
| feat/agents-link-generated-practices | ed8bb84 | fix: fail closed on an empty generated practices directory |
| feat/agents-link-generated-practices-code | 0d178bf | same commit, cherry-picked (no conflict) |

Code trees of the two branches are equal (`git diff` outside `.planning` and `.claude` is empty). Neither branch is on origin; nothing was pushed.

## What changed

- `clone_failure` (`base/selfcheck/best_practices_links.py`): after the unchanged missing-directory loop, fails when `_best_practices_rule_name_list` is empty (`CLONE exists but has no rule in generated/AGENT/rules/`), then when `best_practices_skill_name_list` is empty (`... no skill in generated/AGENT/skills/`).
- `_incomplete_clone_result` now takes a `lacking_text` string; hint byte for byte unchanged.
- New private `_best_practices_rule_name_list`: sorted non-hidden regular files of the generated rules directory.
- Tests: fixtures now hold one rule file; one parametrized case each (rules, skills) in the init and selfcheck suites.
- README troubleshooting row names both details.

## Red bite (before the fix)

Run of the two test files with the new tests and fixture edits, no production change: exactly the 4 new cases failed; the 994 other tests passed (994 passed, 1 skipped, 4 failed in the four suites).

| Case id | Failing assertion |
| ------- | ----------------- |
| test_init_best_practices_linker.py::test_a_clone_with_an_empty_generated_dir_fails_as_incomplete_and_keeps_the_links[rules-rule] | line 290 `assert not result.passed` |
| same test `[skills-skill]` | line 290 `assert not result.passed` |
| test_best_practices_links.py::test_the_links_result_names_the_empty_generated_dir_of_a_clone[rules-rule] | line 167 `assert not result.passed` |
| same test `[skills-skill]` | line 168 detail equality (got the stale-link sentence `... links into the clone, which has no skill skill-a`) |

After the fix: `uv run pytest tests/unit/init tests/unit/selfcheck tests/unit/sbx tests/guard -q` gives 998 passed, 1 skipped.

## Deviations from Plan

None; the plan was executed as written.

## Known Stubs

None.

## Threat Flags

None.

## Host-side check (for the user, not blocking)

`./host-test.sh` on the Mac; the integration fixture has a rule file and two skills per agent, so the first-run and relink scenarios should pass unchanged.

## Self-Check: PASSED

- Commit ed8bb84 on the working branch holds exactly the four code files; no attribution lines; no IDs or non-ASCII in them.
- Code branch tip has the same subject and files; worktree list shows only the repo root; working branch still checked out.
