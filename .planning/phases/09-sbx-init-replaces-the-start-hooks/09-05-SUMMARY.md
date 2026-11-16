---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 05
subsystem: infra
status: complete
tags: [python, selfcheck, sbx-init, path, agents]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: paths.INIT_MARKER_FILE, paths.AGENT_BIN_DIR and hints.init_hint (plan 01)
provides:
  - base/selfcheck/checks/035_init_marker.py with init_marker_result and the init-marker check
  - base/selfcheck/tools.py agent_path_environment and off_path_result
  - claude-off-path and cursor-off-path checks; tool-claude and tool-cursor-agent search the agents folder first
  - check counts shared 42, Claude 13, Cursor 11; H-34 expects 55 and 53
affects: [09-11, 09-13]

actuals:
  tokens: 9000
  tasks: 3
  commits: 3
plan_head_before: 5f4014f5eb0088e272fe8ef2789061bcf3c2896c
plan_head_after: b031d384e7fdba40949c033c34bb77cde52b192a

tech-stack:
  added: []
  patterns:
    - "a check that runs an agent puts the agents folder first on PATH; a check that hunts a stray copy takes it out first"
    - "Claude and Cursor tool files share one shape: version result, off-path result, two check entries"

key-files:
  created:
    - base/selfcheck/checks/035_init_marker.py
    - tests/selftest/selfcheck/test_init_marker.py
  modified:
    - base/selfcheck/tools.py
    - claude/selfcheck/010_tool_claude.py
    - cursor/selfcheck/010_tool_cursor_agent.py
    - tests/selftest/selfcheck/test_tools.py
    - tests/selftest/selfcheck/test_claude_tool_claude.py
    - tests/selftest/selfcheck/test_cursor_tool_cursor_agent.py
    - tests/selftest/selfcheck/test_inventory.py
    - tests/host/h34-selfcheck.sh

key-decisions:
  - "off_path_result removes the agents folder from PATH before it searches, so the check is right even when run from inside an agent session whose PATH the wrapper extended"
  - "The init-marker check only reports the marker; the self-check never runs sbx-init"

patterns-established:
  - "Counts move task by task (54/52, 55/52, 55/53) so the inventory cross-check with H-34 stays green after every commit"

requirements-completed: [INIT-04]

coverage:
  - id: D1
    description: "init-marker passes for a marker file and FAILs with init_hint() for a missing marker or a folder at its path"
    requirement: INIT-04
    status: covered
    evidence: "uv run pytest tests/selftest/selfcheck/test_init_marker.py: 4 pass"
  - id: D2
    description: "claude-off-path and cursor-off-path FAIL for a copy in another PATH folder and pass when the agent is only in the agents folder, also with that folder first on PATH"
    requirement: INIT-04
    status: covered
    evidence: "test_tools.py, test_claude_tool_claude.py and test_cursor_tool_cursor_agent.py off-path tests"
  - id: D3
    description: "tool-claude and tool-cursor-agent find a stand-in only in the agents folder and keep the throwaway HOME for Cursor"
    requirement: INIT-04
    status: covered
    evidence: "claude_version_result and cursor_version_result tests with a temp agents folder"
  - id: D4
    description: "Counts agree: shared 42, Claude 13, Cursor 11, H-34 55 and 53"
    requirement: INIT-04
    status: covered
    evidence: "uv run pytest tests/selftest/selfcheck tests/selftest/init: 385 pass; bash tests/guard/run-all.sh ends with All rules hold."
---

# Phase 9 Plan 05: Self-check for init and the agents' PATH Summary

**The self-check reports whether sbx-init passed in this container and whether claude or cursor-agent sits on a plain PATH, and the agent tool checks now find the agents in their own folder the way the wrappers do.**

## Performance

- **Tasks:** 3 of 3
- **Files:** 2 created, 8 modified

## Accomplishments

- `init-marker` (file `035_init_marker.py`, right after `state-writable`) passes for `/home/sandbox/.sbx-init-done` as a file and FAILs with `init_hint()` otherwise, including a folder at that path.
- `agent_path_environment` returns a copy of the environment with the agents folder first on PATH; `off_path_result` searches a PATH with that folder removed and FAILs naming the found path, with a hint that holds the rebuild command.
- Claude and Cursor tool checks run the agent through the agents folder and still check the pinned version, the native machine and the "not under /home" rule; each image gets an off-path check (`claude-off-path`, `cursor-off-path`).
- The inventory test and H-34 agree: 42 shared, 13 Claude, 11 Cursor; 55 and 53 in total.

## Task Commits

1. **Task 1: init-marker check, counts 54 and 52 (tracer)**: `68d265e`
2. **Task 2: agent PATH helpers and the Claude checks**: `f814794`
3. **Task 3: Cursor checks mirror Claude's**: `b031d38`

The tracer feedback gate was met by the task's own verification: the whole selfcheck suite passed (279 tests) before Task 2 began.

## Deviations from Plan

None. The plan executed as written. The tests for Tasks 2 and 3 were written together with the code in one pass, not as a separate red commit; the plan asks for one commit per task.

## Known Stubs

None.

## Threat Flags

None. `off_path_result` covers T-09-13 (a `claude` placed ahead of the wrapper); `tool_result` still FAILs for a binary under /home. The marker check reports only (T-09-14, accepted).

## Issues Encountered

None. Docker is not available here, so H-34 itself was not run; it parses (`bash -n`) and its counts match the inventory test. The check files are not wired into an image build change by this plan.

## Self-Check: PASSED

- base/selfcheck/checks/035_init_marker.py and tests/selftest/selfcheck/test_init_marker.py exist
- commits 68d265e, f814794 and b031d38 exist
- `uv run pytest tests/selftest/selfcheck tests/selftest/init`: 385 passed; `bash tests/guard/run-all.sh` ends with `All rules hold.`
