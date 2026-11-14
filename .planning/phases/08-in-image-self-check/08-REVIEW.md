---
phase: 08-in-image-self-check
reviewed: 2026-11-14T00:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - README.md
  - base/selfcheck/sbx_selfcheck.py
  - base/selfcheck/shared_checks.py
  - claude/selfcheck/claude.py
  - cursor/selfcheck/cursor.py
  - tests/README.md
  - tests/host-checklist.md
  - tests/host/h34-selfcheck.sh
  - tests/selftest/selfcheck/conftest.py
  - tests/selftest/selfcheck/test_agent_checks.py
  - tests/selftest/selfcheck/test_inventory.py
  - tests/selftest/selfcheck/test_runner.py
  - tests/selftest/selfcheck/test_sandbox_checks.py
  - tests/selftest/selfcheck/test_tool_checks.py
findings:
  critical: 0
  warning: 2
  info: 5
  total: 7
status: issues_found
---

# Phase 8: Code Review Report

**Reviewed:** 2026-11-14
**Depth:** standard (incremental, diff base 643c1a2)
**Files Reviewed:** 14
**Status:** issues_found

## Summary

The gap closure holds up. All 190 selfcheck tests pass (`uv run pytest`). The renames to `_map`/`_set`, the removed comprehensions, the new `tool-bash` and `tool-keytool` checks, the `load-agent-checks` failure, the Mac owner fix hint and the H-34 round trip match the stated intent. The counts agree everywhere (41 shared + 12 Claude = 53, + 10 Cursor = 51 in `README.md`, `h34-selfcheck.sh` and `test_inventory.py`). No non-ASCII characters, planning IDs, dash punctuation or comprehensions were introduced, and `h34-selfcheck.sh` uses only bash 3.2 and BSD-safe constructs (`grep -A 1`, `grep -Ec`, `sed -n 2p`, `[[ ]]`). IN-08 was not re-raised.

Two of the fixes are only partly closed: the unreadable-folder handling still crashes for one shape of unreadable folder, and the "broken or missing checks file" handling still crashes for one shape of broken file. Details below.

## Warnings

### WR-01: scan_owned_state still raises on a folder that lists but cannot be searched

**File:** `base/selfcheck/shared_checks.py:239-242`
**Issue:** The new `except OSError` around `os.scandir` handles a folder that cannot be listed. A folder that can be listed but not searched (mode `r--`, such as a root-owned `0444` folder) passes `scandir`, then `entry.stat(follow_symlinks=False)` raises `PermissionError` for each entry, and only `FileNotFoundError` is caught there. Reproduced: `scan_owned_state` on `st/sub/d/f` with `d` at mode 444 raises `PermissionError: [Errno 13]`. The runner turns it into `FAIL: no-root-owned-state: raised PermissionError ...` with the generic "bug in the self-check or a broken image; sbx-upgrade" hint, which is the same misleading outcome the fix was meant to remove (the right hint is the owner fix). Root-owned state is exactly the case this check exists for.
**Fix:** Treat a failed `stat` like a failed `scandir`: report the folder as unreadable.
```python
            try:
                entry_stat = entry.stat(follow_symlinks=False)
            except FileNotFoundError:
                continue
            except OSError:
                reported_list.append(relative_path.as_posix() + UNREADABLE_SUFFIX)
                continue
```
(Skip the append when `is_tolerated_path(relative_path, tolerated_folder_set)`.) Add a test with a `0o444` folder next to the `0o000` ones. Moving the "unreadable" branch into a small helper also shortens `scan_owned_state`, which is now about 50 lines at four levels of nesting.

### WR-02: a malformed CHECK_LIST still crashes the whole runner

**File:** `base/selfcheck/sbx_selfcheck.py:603-614`
**Issue:** The gap fix makes a missing or empty checks folder a FAIL, but `module_check_list` still does `list(module.CHECK_LIST)` outside the `try`. A file with `CHECK_LIST = None` (or any non-iterable) raises `TypeError` out of `collect_checks`, so `sbx-selfcheck` dies with a traceback and prints no PASS or FAIL line at all. Reproduced with `run_selfcheck([], dir_with_CHECK_LIST_None, sys.stdout)`: `TypeError: 'NoneType' object is not iterable`. A list holding something that is not a `Check` fails later in `outcome_lines(check.name, ...)`, which also runs outside `run_check`'s `try`. The README now promises "a `load-...` line means a checks file in the image is broken or missing", and this shape of broken file breaks that promise.
**Fix:** Validate in `module_check_list` and turn a bad list into a load failure.
```python
    check_list = getattr(module, "CHECK_LIST", None)

    if not isinstance(check_list, list) or not all(isinstance(check, Check) for check in check_list):
        return [load_failure_check(name, f"{module_path} defines no CHECK_LIST of checks")]
```
(Write the `all(...)` as a `for` loop to follow the no-chain rule.) Keep the separate "defines no CHECK_LIST" message for the missing attribute, and add a test per shape.

## Info

### IN-01: the owner fix hint is also printed for unreadable folders it cannot fix

**File:** `base/selfcheck/shared_checks.py:271-275`, `tests/selftest/selfcheck/test_sandbox_checks.py` (`test_scan_owned_state_reports_an_unreadable_folder_of_another_owner`)
**Issue:** `scan_owned_state` reports any folder it cannot open, whoever owns it. For a folder owned by the sandbox user with mode 000, `chown -R 1000:1000` changes nothing, so the Mac command in the hint does not fix the FAIL, and the detail ("owned by uid 0 or unreadable") does not tell the two cases apart. The test above makes this behaviour deliberate.
**Fix:** Either keep unreadable-but-owned-by-sandbox folders out of the report (the sandbox can `chmod` them itself) or give that case its own hint ("make it readable: chmod u+rwx ..."). If the single hint stays, say "or make readable" in it.

### IN-02: the hint hardcodes the image tag and the container name pattern

**File:** `base/selfcheck/shared_checks.py:49,261`
**Issue:** The hint names `sbx-base:local`. A sandbox started with `SBX_IMAGE_TAG=test` (the H-34 sandbox itself) runs `sbx-base:test`, so the hint the user copies there names an image that may not exist on the Mac, and `sbx-{name}` duplicates the `container_name` in `compose.yml` and `CONTAINER` in `tests/host/lib.sh`. H-34 sidesteps this by not asserting the tag, so a drift in either place is not caught.
**Fix:** Pass the tag into the container (a `SBX_IMAGE_TAG` environment variable set by Compose) and build the image name from it, or add a one-line comment at the constant saying the hint assumes the default tag.

### IN-03: an unreadable settings file is reported as "not valid JSON"

**File:** `claude/selfcheck/claude.py:84-87`, `tests/selftest/selfcheck/test_agent_checks.py` (`test_managed_settings_result_reports_an_unreadable_file_as_not_valid_json`)
**Issue:** `except (OSError, ValueError)` folds a `PermissionError` into "is not valid JSON". The file may be fine and merely unreadable. The same pattern is in `cursor.py:66-69` (unchanged). The new test enshrines the wrong wording.
**Fix:** Catch `ValueError` for "is not valid JSON" and `OSError` for `f"{settings_file} cannot be read: {e}"`, and update the test.

### IN-04: the H-34 "after" run asserts only that one check stopped failing

**File:** `tests/host/h34-selfcheck.sh:267-274`
**Issue:** After the owner fix the script runs `check_selfcheck_status` and greps for a `no-root-owned-state` FAIL. A different FAIL caused by the recursive chown (or a changed line count) passes silently, because `check_selfcheck_output` is not used. The doc and report text say the check "passes after running" the fix, which is true, but the sandbox as a whole is not shown healthy.
**Fix:** Call `check_selfcheck_output "owner fix, after" "$afterFile" "$expectedClaudeCount"` instead of the grep, so the count and every FAIL line with its `fix:` are reported as in the first run.

### IN-05: root_run leaves an unnamed container behind when it times out

**File:** `tests/host/h34-selfcheck.sh:203-204`
**Issue:** `run_timeout 120 docker run --rm ...` kills the docker CLI on timeout, but the container has no name and keeps running with the test sandbox's volumes. The next run's `sbx-rm` or `docker ps` checks can see it, and a stuck root container holds the planted folder.
**Fix:** Give it a name (`--name sbx-hosttest-h34-$logName`) and `docker rm -f` that name in `remove_planted_folder`, or mention the leftover in the H-34 failure notes in `tests/host-checklist.md`.

---

_Reviewed: 2026-11-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
