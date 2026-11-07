---
phase: 03-remembered-sandboxes-and-one-command-upgrade
plan: 03
subsystem: infra
tags: [dockerfile, bash, tool-versions, sbx-upgrade, host-tests, docs]

requires:
  - phase: 03-remembered-sandboxes-and-one-command-upgrade
    provides: bin/sbx-upgrade, H-29 and the sbx self-test from plans 01 and 02
provides:
  - /etc/sbx/tool-versions in both images (seven fields, written at build time)
  - a bash.bashrc line so only interactive shells print it
  - sbx-upgrade ending with the line read from the recreated container
  - host check H-30 and the H-29 last-line check
  - SANDBOX.md script flow and the test docs for the sbx self-test, 19 guard rules and H-00 to H-30
affects: [03-04 gate and Mac run]

actuals:
  tokens: 9200
  tasks: 3
  commits: 3
plan_head_before: a05a5876f3c1cff6c5dd879fa1aa553ccfcf165a
plan_head_after: 9abf603e91c8a938d9228bbe18b006bcffa8c79c

tech-stack:
  added: []
  patterns:
    - "the versions line is a file written at build time from the ARGs the smoke tests prove, with a shape grep that stops the build on an empty field"
    - "the shell hook is one cat line at the end of /etc/bash.bashrc, behind Ubuntu's PS1 guard"

key-files:
  created:
    - tests/host/h30-version-line.sh
  modified:
    - base/Dockerfile
    - claude/Dockerfile
    - bin/sbx-upgrade
    - tests/host/h29-sbx-upgrade.sh
    - tests/host/run-all.sh
    - tests/host-checklist.md
    - SANDBOX.md
    - tests/README.md
    - host-test.sh

key-decisions:
  - "The script table row in tests/README.md uses backticks like its neighbours, so the plan's literal grep for that row does not match"
  - "The H-30 banner title is shortened to 80 columns"

requirements-completed: [SCR-07, SCR-01, SCR-02, SCR-03]

coverage:
  - id: D1
    description: "Both images carry one seven-field versions line written at build time, checked by a shape grep; interactive shells print it via /etc/bash.bashrc"
    requirement: "SCR-07"
    verification:
      - kind: other
        ref: "placement and format checks on base/Dockerfile and claude/Dockerfile, rehearsal guard (hadolint_passes)"
        status: pass
    human_judgment: true
    rationale: "The image build and which shells print the line only show on the Mac; H-30 proves it in plan 04"
  - id: D2
    description: "sbx-upgrade ends with the file read by docker exec from the recreated container, after the 'runs on the new images' line"
    requirement: "SCR-07"
    verification:
      - kind: integration
        ref: "tracer command (stand-in docker; last two stdout lines and the last docker call checked)"
        status: pass
    human_judgment: false
  - id: D3
    description: "H-30 and the H-29 last-line check are written, linted and in the runner and checklist"
    requirement: "SCR-07"
    verification:
      - kind: other
        ref: "bash -n, shellcheck, rehearsal guard 'All rules hold.'"
        status: pass
    human_judgment: true
    rationale: "They need the Mac's Docker; they run in plan 04"
  - id: D4
    description: "SANDBOX.md teaches register, start, stop and upgrade by name; the test docs list the sbx self-test, 19 guard rules and H-00 to H-30"
    requirement: "SCR-01"
    verification:
      - kind: other
        ref: "plan verify commands for Task 3 (text checks, no non-ASCII, no spaced double hyphen, README.md untouched)"
        status: pass
    human_judgment: true
    rationale: "Doc voice and clarity need a reader"

duration: 7min
completed: 2026-11-06
status: complete
---

# Phase 3 Plan 03: The Tool Versions Line and the Script Docs Summary

**Both images write `/etc/sbx/tool-versions` at build time (seven fields, shape-checked), interactive shells print it through `/etc/bash.bashrc`, `sbx-upgrade` ends with it, H-30 and H-29 prove it on the Mac, and SANDBOX.md now teaches the `sbx-*` flow.**

## Performance

- **Duration:** about 7 min
- **Started:** 2026-11-06T20:20:23Z
- **Completed:** 2026-11-06T20:27:04Z
- **Tasks:** 3 (Task 1 tracer, Tasks 2 and 3 auto)
- **Files modified:** 10 (1 created, 9 modified)

## Accomplishments

- `base/Dockerfile` writes `node | jdk | mvn | python` from `NODE_VERSION`, `MAVEN_VERSION`, one `java -version` and one `python3 --version`, stops the build on an odd field, and appends `cat /etc/sbx/tool-versions` to `/etc/bash.bashrc`.
- `claude/Dockerfile` prepends `claude | gsd | ccusage` from the three pins and checks the seven-field shape; the pin record COPY stays last.
- `bin/sbx-upgrade` has `print_tool_versions NAME` as its last call.
- `tests/host/h30-version-line.sh` (H-30) compares the image line with `versions.env` and checks that `bash -i` prints it once while `bash -c` and `bash -lc` print nothing; H-29 now asserts its last line is the versions line.
- SANDBOX.md: new "Scripts", "Register a sandbox", "Upgrade" and "What the scripts run"; test docs and `host-test.sh` match.

## Task Commits

1. **Task 1: Tracer, versions in the images and at the end of sbx-upgrade** - `f4a8b6a` (feat)
2. **Task 2: H-30 and the H-29 last-line check** - `d6af561` (test)
3. **Task 3: SANDBOX.md and the test docs** - `9abf603` (docs)

**Plan metadata:** not committed. The plan says to leave this SUMMARY and every other `.planning/` file uncommitted for the orchestrator.

## Evidence

- **Tracer, last two output lines (stand-in docker):**
  - `sbx-upgrade: sbx-demo runs on the new images`
  - `claude 9.9.1 | gsd 9.9.2 | ccusage 9.9.3 | node 9.9.4 | jdk 9.9.5 | mvn 9.9.6 | python 9.9.7`
  - The last Docker call recorded was `docker exec sbx-demo cat /etc/sbx/tool-versions`.
- **New RUN line numbers:** `base/Dockerfile:157` (after `ARG MAVEN_VERSION` and the start hooks folder, before `USER sandbox`); `claude/Dockerfile:82` (after `ARG CCUSAGE_VERSION`, before `USER sandbox`; the pin record COPY is still the last line).
- **Rehearsal guard tail:** `PASS: every_dockerfile_arg_is_pinned` then `All rules hold.`; `PASS: hadolint_passes` present. sbx self-test ends `All cases pass.`
- **shellcheck (warning level)** clean for `bin/sbx-upgrade`, `h30`, `h29`, `run-all.sh`; no non-ASCII; comments at most 80 columns.
- **SANDBOX.md sections added:** "Scripts", "Register a sandbox" (replaces "Create a sandbox folder", the "What lives where" table and "gh and git identity" stay), "Upgrade" (replaces "Rebuild without losing login"), "What the scripts run" (under "Start, enter, stop"). **Removed:** "Create a sandbox folder", "Rebuild without losing login", the paste-by-hand check block under "Before every start". Also changed: "Start, enter, stop", "Bump a version or add a tool", "Verify a new build", the Troubleshooting rows.
- **Not verified here:** the image builds and the real shells (no Docker here); H-30 and the H-29 change run in plan 04.

## Decisions Made

- Doc table rows use backticks like their neighbours.
- The attended helper `h29-upgrade-resume.sh` now has backticks in the helper table, like the other helpers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] H-30 banner title over 80 columns**
- **Found during:** Task 2
- **Issue:** the plan's title line is 85 columns; its own check requires comments at most 80.
- **Fix:** `# H-30: the versions line matches versions.env; only interactive shells print it` (80 columns).
- **Files modified:** tests/host/h30-version-line.sh
- **Committed in:** d6af561

**2. [Rule 1 - Bug] The plan's grep for the tests/README.md suite row has no backticks**
- **Found during:** Task 3
- **Issue:** `command grep -q '^| tests/selftest/sbx/ |' tests/README.md` expects the row without backticks, while every neighbour row writes the path in backticks, and the docs rule is to match the neighbours.
- **Fix:** the row is written with backticks. Everything else in the second Task 3 verify command passes; the same clause with backticks (`'^| `tests/selftest/sbx/` |'`) passes. Plan 04 or a reviewer re-running the literal command will see that one clause fail.
- **Files modified:** tests/README.md
- **Committed in:** 9abf603

**3. [Rule 2 - Missing critical] Helper table row for `h29-upgrade-resume.sh` had no backticks**
- **Found during:** Task 3
- **Issue:** the row from plan 02 broke the table's style.
- **Fix:** added backticks.
- **Files modified:** tests/host-checklist.md
- **Committed in:** 9abf603

---

**Total deviations:** 3 auto-fixed (1 Rule 1, 1 Rule 2, 1 Rule 3)
**Impact on plan:** none on behavior. One literal verify clause fails by design (deviation 2).

## Edge Coverage Note

The plan's flagged assumption stands: `sbx-base:local` alone prints only four fields, and a sandbox still on an old image prints that image's line until its next `sbx-start`.

## Issues Encountered

None beyond the deviations above.

## Known Stubs

None.

## Threat Flags

None. The Dockerfile changes run only printf, sed, grep, cat, mv and chmod; no package is installed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 04 runs H-28, H-29, H-30 and the attended helper on the Mac and runs the self-test under `/bin/bash` 3.2.
- Not yet proven: that the images build with the new RUN lines, that `bash -i` prints the line once, and that `docker exec ... bash -c` stays quiet.

## Self-Check: PASSED

- `tests/host/h30-version-line.sh` found on disk; commits `f4a8b6a`, `d6af561`, `9abf603` found in `git log`; `git rev-list --count a05a587..HEAD` is 3.
- Re-ran at the end: tracer, placement and hadolint check, host script lint, rehearsal guard (`All rules hold.`), sbx self-test (`All cases pass.`).

---
*Phase: 03-remembered-sandboxes-and-one-command-upgrade*
*Completed: 2026-11-06*
