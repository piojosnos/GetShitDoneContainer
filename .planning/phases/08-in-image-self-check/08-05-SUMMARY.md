---
phase: 08-in-image-self-check
plan: 05
subsystem: testing
tags: [python, pytest, selfcheck, elf, openssl, keytool, versions]

requires:
  - phase: 08-03
    provides: the shared checks, pin_value, missing_pin_result, run_command and the hint builders
provides:
  - the shared list completed at 39 checks in its final order (23 new)
  - tool lines, one per tool, with pins, ELF machine and a resolve-outside-/home rule
  - the versions record and tool versions line checks that replace the host version line probe inside the image
  - extra root certificate checks for the system bundle and Java cacerts, found by SHA-256 fingerprint
  - helpers plan 06 reuses (tool_result, expected_base_versions_text, versions_line_result, history_free_environment, first_output_line, version_matches)
affects: [08-06, 08-07]

actuals:
  tokens: 12300
  tasks: 2
  commits: 2
plan_head_before: 2c6582649450a6a2ff313192e677540c063408cf
plan_head_after: 0da18a4f5e68ca2357315675aad7fa60616129eb

tech-stack:
  added: []
  patterns:
    - "Every check is a thin function over a helper that takes its files, environment and pins file as parameters, so pytest runs it on real files, real binaries and stand-in executables in tmp_path"
    - "Where a tool's output must vary, a #!/bin/sh stand-in goes first on the PATH of the environment passed in; subprocess is never mocked"
    - "Certificates and keystores are made at test time by openssl and keytool; nothing is committed"

key-files:
  created:
    - tests/selftest/selfcheck/test_tool_checks.py
    - tests/selftest/selfcheck/test_certs.py
  modified:
    - base/selfcheck/sbx_selfcheck.py
    - base/selfcheck/shared_checks.py
    - tests/selftest/selfcheck/conftest.py
    - tests/selftest/selfcheck/test_sandbox_checks.py

key-decisions:
  - "tool_result takes an optional home_root (default /home) so the under-/home failure is tested with a real stand-in in tmp_path"
  - "The pinned tool lines are separate functions (tool_gh_result and so on) taking the pins file, so a wrong or missing pin is tested without touching /etc/sbx/versions.env"
  - "versions-line-file accepts the base text alone or any prefix ending in ' | ' plus the base text, so agent images add their own fields in front (plan 06 checks the prefix with versions_line_result)"
  - "The list-order test in test_sandbox_checks.py now asserts the 39 names; it is the single place that pins the final order"

patterns-established:
  - "A tool is resolved with the PATH of the process, judged on its real path (links followed), then its ELF machine, then its version line"
  - "Version text matches only when equal to the pin or followed by a space"

requirements-completed: [CHECK-01, CHECK-03, CHECK-04]

coverage:
  - id: D1
    description: "architecture and one tool line per tool resolve the command outside /home, check the ELF machine and compare gh, node, uv, java, maven, gsd and python with their pins"
    requirement: CHECK-01
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_tool_checks.py (version_matches precision, is_under, image_tag, jdk_version, elf_machine, tool_result with stand-ins, real python3 and git, missing pins)"
        status: pass
      - kind: integration
        ref: "python3 base/selfcheck/sbx-selfcheck in the dev sandbox: every tool line passes with its pin"
        status: pass
    human_judgment: false
  - id: D2
    description: "versions-record, versions-line-file, versions-line-interactive and versions-line-quiet check the record and the tool versions line; bash -i runs with HISTFILE=/dev/null"
    requirement: CHECK-01
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_tool_checks.py (expected_base_versions_text, versions_line_result, stand-in bash, real bash leaves a history file untouched, record is parsed and never run)"
        status: pass
    human_judgment: true
    rationale: "The dev sandbox runs an older image whose tool-versions line carries ccusage between gsd and node, so versions-line-file passes for real only in a rebuilt image on the Mac (plan 07)"
  - id: D3
    description: "extra-ca-system-bundle and extra-ca-java-cacerts find every installed extra root certificate by fingerprint, and in cacerts by alias, and pass with no extra certificate"
    requirement: CHECK-03
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_certs.py (certificates made by openssl, keystores made by keytool, fingerprints equal to openssl's, alias and fingerprint mismatches, keytool failure, no extra certificate runs nothing)"
        status: pass
    human_judgment: true
    rationale: "The dev sandbox has no extra root certificate; the real system bundle and cacerts with the Mac's test root are proven by H-34 on the Mac (plan 07)"

duration: 20 min
completed: 2026-11-14
status: complete
---

# Phase 8 Plan 05: Architecture, tool lines, versions line and extra root certificates Summary

**The shared self-check list is complete at 39 checks: the architecture, one line per tool that resolves it into the image, checks its ELF machine and compares it with its pin, the versions record and tool versions line (replacing H-30 inside the image, with `bash -i` run on `HISTFILE=/dev/null`), and both extra root certificate checks, which find every installed certificate by SHA-256 fingerprint in the system bundle and, with its alias, in Java cacerts.**

## Performance

- **Duration:** about 20 min
- **Completed:** 2026-11-14T18:46:00Z
- **Tasks:** 2
- **Files:** 6 (2 created, 4 modified)

## Accomplishments

- Library (`base/selfcheck/sbx_selfcheck.py`): `ELF_MACHINE_BY_UNAME_MAP`, `HOME_ROOT`, `TOOL_VERSIONS_FILE`, `is_under`, `elf_machine`, `version_matches`, `image_tag`, `jdk_version`, `first_output_line`, `tool_result`, `expected_base_versions_text`, `versions_line_result`, `history_free_environment`. None names an agent; plan 06 builds its lines on them.
- Task 1 checks: `architecture`, `tool-git`, `tool-gh`, `tool-node`, `tool-python`, `tool-uv`, `tool-java`, `tool-maven`, `tool-gsd`, `tool-jq`, `tool-rg`, `tool-unzip`, `tool-zip`, `tool-ssh`, `tool-make`, `tool-gcc`, `tzdata`. A copy under /home, a wrong ELF machine, a longer version (`uv 0.12.210` for `uv 0.12.21`) and a missing pin each fail with a named cause and a fix.
- Task 2 checks: `versions-record`, `versions-line-file`, `versions-line-interactive`, `versions-line-quiet`, `extra-ca-system-bundle`, `extra-ca-java-cacerts`. Both certificate PASS lines print `ALIAS FINGERPRINT` pairs (upper-case hex, no colons) for H-34.
- Probe-to-check map as in the plan: H-01, H-22, H-25 (GSD) and H-30 in-container assertions each have a check; the daemon comparison and the throwaway-container runs are dropped.
- Tests: `test_tool_checks.py` (54 tests) and `test_certs.py` (16 tests) on real binaries, real bash, openssl and keytool; `uv run pytest tests/selftest/selfcheck`: 141 passed.

## Task Commits

1. **Task 1: the architecture and one line per tool** - `d3af014`
2. **Task 2: the versions record, the versions line and the extra root certificates** - `0da18a4`

## Verification

- `uv run pytest tests/selftest/selfcheck -q`: 141 passed.
- All Task 1 and Task 2 `<verify>` commands exit 0: the shared list is the 33, then the 39 unique names, in order; no base file names an agent; no `shell=True`, `eval(` or `exec(`; `"HISTFILE"` is set in the library; the launcher prints 39 check lines with a summary counting 39, both certificate lines pass with `no extra root certificate installed`, `versions-line-quiet` passes, every FAIL has one fix line.
- Acceptance: 27 then 54 `def test_` in `test_tool_checks.py`, 16 in `test_certs.py`; 15 `tool_result(` calls in the shared file; `sbx-extra-ca-*.crt` and `/etc/ssl/certs/ca-certificates.crt` present; `git ls-files` lists 0 `.pem`, `.crt` or `.key` files.
- `bash tests/guard/run-all.sh`: "All rules hold."
- Dev sandbox launcher run: 39 checks, 4 failed, none a gate. `git-identity` (no identity set here), `versions-line-file` (the older image's line has ccusage between gsd and node), `wrappers-root-owned` and `image-paths-protected` (the older image lacks the self-check files). All four run for real only in a rebuilt image on the Mac (plan 07).

## Deviations from Plan

### Auto-fixed Issues

None.

### Design notes within the plan's latitude

- `tool_result` gained a `home_root` keyword (default `HOME_ROOT`) and the pinned tool lines are named functions taking the pins file (`tool_gh_result(versions_file)` and so on), so tests exercise the under-/home and wrong-pin paths against real stand-ins without changing `/etc/sbx`.
- `versions-line-file` needed an "ends with the base text" rule that `versions_line_result` (exact prefix plus base) does not give, so `versions_line_file_result` sits in the shared file; plan 06's agent lines call `versions_line_result` with their prefix.
- The tests were written before the code in each task but the RED run was not watched separately (the whole new test file imports names that did not exist yet, so every test failed at the start of each task by construction).
- `test_the_shared_list_holds_the_sixteen_checks_in_the_final_order` (plan 03) became `test_the_shared_list_holds_the_checks_in_the_final_order`, asserting 33 names after task 1 and 39 after task 2.

## Known Stubs

None.

## Threat Flags

None. The mitigations T-08-15 to T-08-18 are implemented as planned: a copy under /home fails its line, versions match only on equality or the expected text plus a space, certificates are found by fingerprint (and alias in cacerts) never by count, `bash -i` runs on `HISTFILE=/dev/null` with closed stdin and the 60 s limit, and `/etc/sbx/versions.env` and version output are parsed as text only (a test proves a `$(touch ...)` value is never run).

## Next Phase Readiness

Plan 06 adds the agent checks on `tool_result`, `versions_line_result`, `first_output_line` and `history_free_environment`. Plan 07's Mac gate confirms the certificate checks against the real test root (H-34) and the four dev-sandbox-only failures above against a rebuilt image.

## Self-Check: PASSED

- Files created and modified exist: `base/selfcheck/sbx_selfcheck.py`, `base/selfcheck/shared_checks.py`, `tests/selftest/selfcheck/conftest.py`, `tests/selftest/selfcheck/test_tool_checks.py`, `tests/selftest/selfcheck/test_certs.py`.
- Commits `d3af014` and `0da18a4` exist on `feat/phase-08-in-image-self-check`; `git rev-list --count` from the recorded base is 2.
