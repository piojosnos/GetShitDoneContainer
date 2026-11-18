---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 04
subsystem: infra
status: complete
tags: [python, sbx-init, selfcheck, best-practices, symlinks]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: the sbx-init runner, step file contract and init_hint (plan 01)
provides:
  - base/init/best_practices_link.py with link_best_practices, a three-way link rule with no recursive delete
  - claude and cursor init steps 900_best_practices_links.py (Cursor links skills only)
  - bundle_links.py public RULES_LINK_TEXT, SKILL_LINK_TEXT_TEMPLATE, best_practices_skill_name_list, is_best_practices_link
  - a bundle links check that no longer reads the list file
affects: [09-11, 09-13]

actuals:
  tokens: 8500
  tasks: 3
  commits: 3
plan_head_before: f1273415c6442e2563682ea6e3226c85e6dc8847
plan_head_after: ab0e448b1fa1dfb5677b84d0a1f537f109235d1d

tech-stack:
  added: []
  patterns:
    - "init's own links are recognised only by where they point (lexical target under the clone's folder), never by a list file"
    - "init and the self-check share one link test and one skill listing"

key-files:
  created:
    - base/init/best_practices_link.py
    - claude/init/900_best_practices_links.py
    - cursor/init/900_best_practices_links.py
    - tests/selftest/init/test_init_best_practices_link.py
  modified:
    - base/selfcheck/bundle_links.py
    - tests/selftest/selfcheck/test_bundle_links.py

key-decisions:
  - "A clash (folder, file, copy, foreign link) is left as it is and FAILs the step after every other skill is linked, naming each path with 'rename or move PATH, then run sbx-init again'"
  - "The only removal in the linker is Path.unlink on an entry is_best_practices_link accepts"
  - "The check's 'does not reach' problem is raised for a link with the right text whose target is not the clone's skill folder"

patterns-established:
  - "A user skill, a GSD skill, a copy and a link into skills-old are all outside the own-link test and are never touched"

requirements-completed: [INIT-05]

coverage:
  - id: D1
    description: "The Claude step links rules and every clone skill with the relative texts; Cursor links skills only"
    requirement: INIT-05
    status: covered
    evidence: "uv run pytest tests/selftest/init/test_init_best_practices_link.py: 22 pass"
  - id: D2
    description: "A user's folder, copy, foreign link or GSD skill is never changed; the step FAILs naming it with the rename or move fix"
    requirement: INIT-05
    status: covered
    evidence: "clash tests compare bytes before and after; grep for rmtree, rm -rf and shutil in base/init finds nothing"
  - id: D3
    description: "The self-check verifies links reach the clone and that no stale own link is left, without the list file"
    requirement: INIT-05
    status: covered
    evidence: "uv run pytest tests/selftest/selfcheck tests/selftest/init: 366 pass"
---

# Phase 9 Plan 04: Best-practices links step Summary

**Init links the best-practices clone into each agent's config folder by recognising its own links by where they point, so a user skill with a clone skill's name is never deleted again; the self-check proves the links reach the clone without the list file.**

## Performance

- **Tasks:** 3 of 3
- **Files:** 4 created, 2 modified

## Accomplishments

- `link_best_practices(config_dir, bundle_dir, links_rules)` places each link by a three-way rule: nothing there (not even a dangling link) gets the link; an own link (target under the clone's folder) is replaced; anything else is left, remembered and FAILs the step at the end with the path and the fix.
- Own links the clone no longer backs are removed with `Path.unlink`; the module has no recursive delete.
- No clone FAILs with `run sbx-gh-login, then sbx-bundle-clone; ...` and makes no link. A clone with rules and no skills folder links rules and zero skills.
- `bundle_links.py` exposes the link texts, the skill listing and `is_best_practices_link`; the check dropped `.best-practices-skills`, added the "does not reach" and the stale own link problems, and its fixes now say `init_hint()` or the clone commands.
- Claude and Cursor step files differ only in agent name, the rules flag and comments.

## Task Commits

1. **Task 1: Claude step and shared own-link test (tracer)**: `9248b2f`
2. **Task 2: Cursor step, clash, stale link and missing clone tests**: `2dcb328`
3. **Task 3: check verifies reach and stale links without the list file**: `ab0e448`

The tracer feedback gate was met by the task's own verification (the init test file passed, then the full suite at 345 passed).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Task 1 kept the list file constant until Task 3**
- **Found during:** Task 1
- **Issue:** the old check still read `.best-practices-skills`; removing the constant in Task 1 would have broken the check and its tests until Task 3.
- **Fix:** the private constant stayed in Task 1 and was deleted in Task 3, so every commit passes the full suite.
- **Commit:** 9248b2f, ab0e448

**2. [Plan wording] "Clone folder is a file" test case**
- **Found during:** Task 3
- **Issue:** a clone skill that is a file is not in the skill listing (folders only), so a link to it is reported as a stale own link, not as "does not reach".
- **Fix:** the "does not reach" test uses a link with the right text whose resolved path misses the clone (the clone sits under another parent), which is the situation the problem exists for.
- **Files modified:** tests/selftest/selfcheck/test_bundle_links.py
- **Commit:** ab0e448

Task 2's tests mostly passed against Task 1's code (the rule was complete there); the red case was the missing Cursor step file.

## Known Stubs

None.

## Threat Flags

None. The linker removes only an entry the own-link test accepts (T-09-10); link names come from `iterdir()` folder names with dot names skipped and a fixed text template (T-09-11).

## Issues Encountered

None. The new step files are not copied into the image yet; the Dockerfile and launcher wiring belong to later plans of this phase. Docker is not available here.

## Self-Check: PASSED

- base/init/best_practices_link.py, claude/init/900_best_practices_links.py, cursor/init/900_best_practices_links.py, tests/selftest/init/test_init_best_practices_link.py exist
- commits 9248b2f, 2dcb328 and ab0e448 exist
- `uv run pytest tests/selftest/selfcheck tests/selftest/init`: 366 passed; `bash tests/guard/run-all.sh` ends with `All rules hold.`
