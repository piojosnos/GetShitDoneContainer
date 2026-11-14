---
phase: 08-in-image-self-check
reviewed: 2026-11-14T00:00:00Z
depth: standard
files_reviewed: 34
files_reviewed_list:
  - .gitignore
  - .hadolint.yaml
  - .python-version
  - MIGRATION.md
  - README.md
  - base/Dockerfile
  - base/selfcheck/sbx-selfcheck
  - base/selfcheck/sbx_selfcheck.py
  - base/selfcheck/shared_checks.py
  - claude/Dockerfile
  - claude/selfcheck/claude.py
  - cursor/Dockerfile
  - cursor/selfcheck/cursor.py
  - host-test.sh
  - pyproject.toml
  - tests/README.md
  - tests/guard/isolation.sh
  - tests/guard/supply-chain.sh
  - tests/host-checklist.md
  - tests/host/h06-git-on-mac-repo.sh
  - tests/host/h12-plain-run-refused.sh
  - tests/host/h25-images-match-versions.sh
  - tests/host/h26-isolation-by-inspect.sh
  - tests/host/h34-selfcheck.sh
  - tests/host/lib-docker.sh
  - tests/host/run-all.sh
  - tests/selftest/selfcheck/conftest.py
  - tests/selftest/selfcheck/test_agent_checks.py
  - tests/selftest/selfcheck/test_certs.py
  - tests/selftest/selfcheck/test_inventory.py
  - tests/selftest/selfcheck/test_runner.py
  - tests/selftest/selfcheck/test_sandbox_checks.py
  - tests/selftest/selfcheck/test_tool_checks.py
findings:
  critical: 0
  warning: 4
  info: 8
  total: 12
status: issues_found
---

# Phase 8: Code Review Report

**Reviewed:** 2026-11-14
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

The self-check runner, the shared checks and the two agent files are in good shape. No secret or login file is ever opened or printed: `login_file_result` only calls `stat`, `cursor_version_result` runs the CLI with a throwaway `HOME` and without `CURSOR_CONFIG_DIR`, the cursor `cli-config.json` read prints only the `channel` value, and every subprocess call takes an argument list (no shell). The launcher runs under `python3 -I`, resolves its own path and imports only from the root-owned library folder. The host scripts use bash 3.2 and BSD safe constructs (`sed 's/..//'`, `tr 'a-f' 'A-F'`, no `mapfile`, no `grep -P`). No ASCII, dash or planning-ID violations were found in the listed source files.

There is no blocker. The four warnings are a hint that cannot work in the sandbox, a check that crashes instead of reporting the thing it exists to find, a path where the self-check goes green with zero agent checks, and two checks that execute a PATH lookup that is not guarded against `/home`.

## Warnings

### WR-01: The `no-root-owned-state` fix line tells the sandbox user to run a `chown` that cannot succeed

**File:** `base/selfcheck/shared_checks.py:258`
**Issue:** The fix is `in this sandbox run: chown -R sandbox:sandbox /home/sandbox/workspace/state`. The sandbox user is uid 1000, has no sudo, drops every capability and runs with `no-new-privileges` (compose.yml, and MIGRATION.md line 137 says outright "the sandbox drops every capability, so even its root cannot change owners"). A non-root user cannot chown a file that root owns, so the command prints `Operation not permitted` for exactly the paths the check reports. The unit test `test_root_owned_state_fails_with_the_total_and_at_most_ten_paths` (`tests/selftest/selfcheck/test_sandbox_checks.py`, the `"chown -R sandbox:sandbox" in result.hint` assertion) locks the wrong hint in.
**Fix:** Point the fix at the Mac, using the throwaway-container pattern MIGRATION.md already documents, for example:
```python
return failed(
    ...,
    mac_hint(
        "give the files back to the sandbox user with a throwaway root container",
        f"docker run --rm --network none -u root --entrypoint chown -v <state folder of {sandbox_name()}>:/state sbx-base:local -R 1000:1000 /state",
    ),
)
```
or, when the root-owned entries sit in a sandbox-owned folder, tell the user to `rm` them (a user may delete a root-owned file in a folder it owns). Update the test assertion to match.

### WR-02: `scan_owned_state` raises on an unreadable folder, so the check reports a crash instead of the root-owned path

**File:** `base/selfcheck/shared_checks.py:211-237`
**Issue:** The walk appends a root-owned directory to `reported_list` and then pushes it onto `pending_dir_list`. When that directory is mode 700 and owned by root (the very condition the check exists to find), the next `os.scandir(current_dir)` raises `PermissionError`. `run_check` turns that into `FAIL: no-root-owned-state: raised PermissionError: ...`, and the reported list is lost, so the user never learns which path is wrong. Reproduced: a `0o000` folder under a state tree makes `scan_owned_state` raise `PermissionError`. A folder deleted between listing and descending raises `FileNotFoundError` the same way, although `entry.stat` already guards that case.
**Fix:** Catch `OSError` around the `scandir`, record the folder as unreadable in `reported_list` (it is a finding either way) and continue:
```python
try:
    with os.scandir(current_dir) as entry_iterator:
        entry_list = list(entry_iterator)
except FileNotFoundError:
    continue
except PermissionError:
    reported_list.append(current_dir.relative_to(state_dir).as_posix() + " (unreadable)")
    continue
```
Add a test that plants an unreadable folder (the `restorable_mode` fixture already exists).

### WR-03: A missing or empty agent checks folder gives a green result with no agent checks

**File:** `base/selfcheck/sbx_selfcheck.py:615-621` (and `tests/selftest/selfcheck/test_runner.py:140-152`, which asserts this behaviour)
**Issue:** `collect_checks` globs `*.py` in `/etc/sbx/selfcheck.d`. If the folder is missing, empty, or the agent file was not copied, only the 39 shared checks run and the result is `39 checks, 0 failed`, exit 0. The shared `wrappers-root-owned` check requires the folder to exist, but nothing requires a file in it, and the file that would check `/etc/sbx/selfcheck.d/claude.py` is the one that is absent. A user running `sbx-selfcheck` in such a sandbox is told everything is fine while the login, GSD sync, managed settings and agent CLI version were never checked. Only the Mac-side count in H-34 would notice, and it runs on test images only.
**Fix:** Make the absence a failing check, so it also fails the exit status:
```python
module_path_list = sorted(checks_dir.glob("*.py"))

if not module_path_list:
    check_list.append(load_failure_check("load-agent-checks", f"no checks file in {checks_dir}"))
```
and change the runner test to expect the FAIL line and exit 1.

### WR-04: `bash` and `keytool` are executed through PATH without the "not under /home" guard

**File:** `base/selfcheck/shared_checks.py:498` (`bash -i`), `:513` (`bash -c`, `bash -lc`), `:628` (`keytool -list`)
**Issue:** The project rule is that nothing in the sandbox may run from `/home`, and `tool_result` enforces it for every tool it checks. `run_command` hands a bare name to `subprocess.run`, which resolves it through the `PATH` of the environment passed in (`os.get_exec_path(env)`). There is no `tool-bash` or `tool-keytool` check, so a `~/.local/bin/bash` or `~/.local/bin/keytool` placed ahead of the image's on PATH is what the versions-line and certificate checks run, and they can pass or fail on behalf of a binary that is not the image's. `git` is covered by the `tool-git` check, so only these two escape.
**Fix:** Run them through `tool_result`-style resolution, or pin the absolute paths (`/usr/bin/bash`, `$JAVA_HOME/bin/keytool`). The smaller change is two extra checks (`tool-bash`, `tool-keytool`) built on `tool_result("bash")` and `tool_result("keytool")`, plus bumping the three count constants (inventory test and `h34-selfcheck.sh`).

## Info

### IN-01: `owned_by_uid_paths` is dead code in the image

**File:** `base/selfcheck/shared_checks.py:240-246`
**Issue:** The function is a one-line wrapper around `scan_owned_state(...)[0]`. Nothing in `base/`, `claude/` or `cursor/` calls it; only `test_sandbox_checks.py` does. It widens the public surface for the benefit of tests alone.
**Fix:** Delete it and have the tests call `scan_owned_state(...)[0]`.

### IN-02: Blank lines missing before control flow

**File:** `base/selfcheck/sbx_selfcheck.py:653`, `tests/selftest/selfcheck/test_inventory.py:75`, `tests/selftest/selfcheck/test_runner.py:277`, `tests/selftest/selfcheck/test_agent_checks.py:478`
**Issue:** In each place an `if` or `for` follows a statement with no blank line (`result = run_check(check)` then `if not result.passed:` in the runner; an `assert` then `for` in the three tests). This breaks the blank-lines-around-control-flow rule.
**Fix:** Add a blank line before each of those four lines.

### IN-03: Comprehensions and generator expressions in the tests

**File:** `tests/selftest/selfcheck/test_agent_checks.py:72,370,486`, `tests/selftest/selfcheck/test_sandbox_checks.py:577`, `tests/selftest/selfcheck/test_tool_checks.py:284,508`, `tests/selftest/selfcheck/test_sandbox_checks.py` (the `any(...)` generator in the link-not-followed test)
**Issue:** The source files use plain loops throughout, but the tests use list comprehensions and generator expressions (`[check.name for check in ...]`, `[name + "\n" for name in ...]`, `sorted(path.name for path in ...)`). The coding rule asks for imperative loops.
**Fix:** Add one `check_name_list(check_list)` helper in `conftest.py` that loops, and use it in all the name comparisons; replace the other few with small loops.

### IN-04: Dict-typed locals without a `Map` suffix, and an inconsistent exception name

**File:** `base/selfcheck/shared_checks.py:343,575`, `base/selfcheck/sbx_selfcheck.py:571-578,606,627`, `claude/selfcheck/claude.py:84-90`, `cursor/selfcheck/cursor.py:66`
**Issue:** `mount_point_collection` (a set, but named "collection"), `history_free` (a dict), `settings`, `permissions`, `config` (dicts) and the `environment` parameters carry no shape suffix. The runner catches exceptions as `error` in two places while the rest of the code uses the sanctioned `e`.
**Fix:** Rename to `mount_point_set`-style names (`mount_point_found_set`), `history_free_environment_map`, `settings_map`, `permissions_map`, `config_map`, and use `e` for caught exceptions.

### IN-05: Public functions without type hints

**File:** `base/selfcheck/sbx_selfcheck.py:581` (`load_check_module` has no return type), `claude/selfcheck/claude.py:63` (`sorted_text_list(value)` has an untyped parameter)
**Issue:** The Python rule asks for hints on public signatures.
**Fix:** `-> ModuleType` with `from types import ModuleType`, and `value: object`.

### IN-06: `managed_settings_result` reports a missing or unreadable file as "does not parse as JSON"

**File:** `claude/selfcheck/claude.py:83-86`
**Issue:** `except (OSError, ValueError)` collapses a missing file, a permission error and bad JSON into one message. `cursor.py` already separates `FileNotFoundError` from the other two cases.
**Fix:** Handle `FileNotFoundError` first with `f"{settings_file} is missing"`, symmetric with `self_update_result`.

### IN-07: A test name and a constant hard-code the check counts

**File:** `tests/selftest/selfcheck/test_inventory.py:30`
**Issue:** `test_the_lists_hold_39_shared_12_claude_and_10_cursor_checks` repeats the numbers in `SHARED_CHECK_COUNT`, `CLAUDE_CHECK_COUNT` and `CURSOR_CHECK_COUNT`; the name goes stale the first time a check is added.
**Fix:** Rename to `test_the_lists_hold_the_declared_check_counts`.

### IN-08: Host scripts: leftover state and a predictable shared folder

**File:** `tests/host/h34-selfcheck.sh:175-184`, `tests/host/run-all.sh:213-239`, `clean.sh:138`
**Issue:** (a) `check_claude_sandbox` plants a git identity and a fake `.credentials.json` in the shared Claude test sandbox and leaves them there for the chain checks that run after H-34, so later checks start from non-clean state. (b) `make_test_root_cert` reuses an existing `root-ca.pem` in `$TMPDIR/sbx-hosttest-root-ca` without checking who owns the folder. On macOS `TMPDIR` is per-user, so this is harmless there, but with `TMPDIR` unset on a shared Linux `/tmp` another user could pre-create the folder with their own certificate and have the test images trust it. (c) `clean.sh` removes the certificate folder only because its `sbx-hosttest-*` glob happens to match it, and its output then lists it under "Host-test run folders".
**Fix:** (a) Remove the planted files at the end of `check_claude_sandbox`, or note in the header that later checks tolerate them. (b) Test `[ -O "$certDir" ]` before reuse and regenerate when it fails. (c) Name the folder outside the `sbx-hosttest-*` pattern and add an explicit line for it in `clean.sh`, so the README's claim does not depend on a glob.

---

_Reviewed: 2026-11-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
