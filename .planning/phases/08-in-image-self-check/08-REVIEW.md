---
phase: 08-in-image-self-check
reviewed: 2026-11-14T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - base/selfcheck/sbx_selfcheck.py
  - base/selfcheck/shared_checks.py
  - tests/selftest/selfcheck/test_runner.py
  - tests/selftest/selfcheck/test_sandbox_checks.py
findings:
  critical: 0
  warning: 1
  info: 1
  total: 2
status: issues_found
---

# Phase 8: Code Review Report

**Reviewed:** 2026-11-14
**Depth:** standard (incremental, diff base e46940d)
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Both earlier warnings are closed for the shapes they named. `uv run pytest selfcheck` passes (198 tests).

- **Earlier WR-01 (closed).** `scan_owned_state` no longer raises on a folder that lists but cannot be searched. The `entry.stat` failure now marks the folder `(unreadable)`, replaces the folder's own "owned" line, honors the tolerated sync folders, and reaches the owner-fix hint. The three new tests cover the plain, tolerated and end-to-end cases, and they are skipped when run as root, which is correct. The mark logic moved into `mark_unreadable_folder`, so `scan_owned_state` is shorter and has one fewer duplicated block.
- **Earlier WR-02 (closed for its shape).** A `CHECK_LIST` that is `None`, a number, text, a list of text, or a list with one text item is now one `load-<file>` FAIL with the rebuild hint. The real agent files import `Check` through the `sbx_selfcheck` module (the `sbx-selfcheck` launcher imports it rather than running it as `__main__`), so the new `isinstance(item, Check)` test does not reject the image's own checks.

One adjacent shape of the same "a broken checks file crashes the runner" problem is still open (WR-03). No planning IDs, non-ASCII characters, dash punctuation, comprehensions, brace-less bodies or missing blank lines around control flow were introduced. Earlier IN-01 to IN-05 and IN-08 were not re-raised.

## Warnings

### WR-03: a check that returns something other than a CheckResult still crashes the runner

**File:** `base/selfcheck/sbx_selfcheck.py:650-657, 677-684`
**Issue:** `is_check_list` proves each item is a `Check`, but `Check` is a plain frozen dataclass, so `Check.function` can return anything. `run_check` only guards the call itself. The result is used in `run_selfcheck` outside any `try` (`result.passed`, then `outcome_lines`, which reads `result.detail` and `result.hint`). A check function that returns `None` (a forgotten `return`, the commonest slip when adding a check) raises `AttributeError: 'NoneType' object has no attribute 'passed'` out of `run_selfcheck`. Reproduced with an agent file `CHECK_LIST = [Check("x", f)]` where `f` returns `None`: the runner dies with a traceback and prints no PASS or FAIL line at all, the exact outcome the previous fix set out to remove. A bool or a tuple return behaves the same. The README promise that every broken checks file shows up as a `FAIL` line therefore still has a hole, and it is easy to hit because agent files are hand-written and will keep growing.
**Fix:** Validate the result inside `run_check`, so a bad return is one FAIL for that check, in the same place the exceptions are already turned into FAIL lines.
```python
def run_check(check: Check) -> CheckResult:
    try:
        result = check.function()
    except Exception as e:
        return failed(
            f"raised {type(e).__name__}: {e}",
            "this is a bug in the self-check or a broken image; " + rebuild_hint(),
        )

    if not isinstance(result, CheckResult):
        return failed(
            f"returned {type(result).__name__} instead of a CheckResult",
            "this is a bug in the self-check or a broken image; " + rebuild_hint(),
        )

    return result
```
Add a runner test with a check that returns `None`, expecting one `FAIL: name: returned NoneType instead of a CheckResult` line plus its `fix:` line and a summary line.

## Info

### IN-09: one failing entry marks the whole folder and drops its siblings

**File:** `base/selfcheck/shared_checks.py:241-247`
**Issue:** The new `except OSError` around `entry.stat` calls `mark_unreadable_folder` for `current_dir` and then `break`s. For the intended case (a `r--` folder, where every `lstat` fails) that is right. For any other `OSError` on a single entry (for example a too-long name or a transient I/O error), the folder is reported as unreadable and the entries after the failing one are never inspected, so a root-owned sibling is silently left out of the report. Entries before the failing one have already been reported and their subfolders queued, so the output for that folder is also inconsistent. `current_dir.relative_to(state_dir)` is also computed twice in the function (lines 232 and 246).
**Fix:** Low priority. Compute `relative_dir = current_dir.relative_to(state_dir)` once after the `scandir` try block, and either narrow the catch to `PermissionError` (the case being handled; other errors then surface through the runner's `raised ...` FAIL line) or keep `OSError` and `continue` instead of `break` so siblings are still scanned. If the `break` stays, a one-line comment saying why the rest of the folder is skipped would help.

---

_Reviewed: 2026-11-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
