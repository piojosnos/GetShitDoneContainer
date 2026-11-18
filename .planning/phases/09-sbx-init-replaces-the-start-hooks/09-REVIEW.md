---
phase: 09-sbx-init-replaces-the-start-hooks
reviewed: 2026-11-16T00:00:00Z
depth: standard
files_reviewed: 92
files_reviewed_list:
  - MIGRATION.md
  - README.md
  - ZSCALER.md
  - base/Dockerfile
  - base/bin/sbx-bundle-clone
  - base/bin/sbx-gh-login
  - base/init/best_practices_link.py
  - base/init/gsd_sync.py
  - base/init/init_runner.py
  - base/init/sbx-init
  - base/init/steps/010_state_folders.py
  - base/init/steps/800_state_owner.py
  - base/selfcheck/agent_config.py
  - base/selfcheck/bundle_links.py
  - base/selfcheck/checks/030_state_folders.py
  - base/selfcheck/checks/035_init_marker.py
  - base/selfcheck/checks/040_root_owned_state.py
  - base/selfcheck/hints.py
  - base/selfcheck/image_ownership.py
  - base/selfcheck/image_roots.py
  - base/selfcheck/paths.py
  - base/selfcheck/root_owned_scan.py
  - base/selfcheck/tools.py
  - bin/sbx-lib.sh
  - bin/sbx-shell
  - bin/sbx-start
  - bin/sbx-upgrade
  - claude/Dockerfile
  - claude/bin/sbx-claude
  - claude/init/050_gsd_sync.py
  - claude/init/900_best_practices_links.py
  - claude/managed-settings.json
  - claude/selfcheck/010_tool_claude.py
  - claude/selfcheck/090_managed_settings.py
  - compose.yml
  - cursor/Dockerfile
  - cursor/bin/sbx-cursor
  - cursor/init/050_gsd_sync.py
  - cursor/init/060_self_update_off.py
  - cursor/init/900_best_practices_links.py
  - cursor/selfcheck/010_tool_cursor_agent.py
  - cursor/selfcheck/050_self_update_off.py
  - cursor/selfcheck/lib/cursor_shared.py
  - host-test.sh
  - prompts/consolidate-memories.md
  - pyproject.toml
  - tests/README.md
  - tests/guard/isolation.sh
  - tests/guard/lib.sh
  - tests/guard/start.sh
  - tests/guard/supply-chain.sh
  - tests/host-checklist.md
  - tests/host/h10-missing-folder-refused.sh
  - tests/host/h16-live-clone-and-restart.sh
  - tests/host/h23-caches-survive-recreate.sh
  - tests/host/h27-bundle-clone-and-publish.sh
  - tests/host/h28-sbx-add-start-stop.sh
  - tests/host/h29-sbx-upgrade.sh
  - tests/host/h31-sbx-shell.sh
  - tests/host/h34-selfcheck.sh
  - tests/host/h35-init-owner-and-lock.sh
  - tests/host/lib-bundle.sh
  - tests/host/lib-sandbox.sh
  - tests/host/run-all.sh
  - tests/selftest/init/init_helpers.py
  - tests/selftest/init/test_init_best_practices_clone.py
  - tests/selftest/init/test_init_best_practices_link.py
  - tests/selftest/init/test_init_gh_login.py
  - tests/selftest/init/test_init_gsd_sync.py
  - tests/selftest/init/test_init_inventory.py
  - tests/selftest/init/test_init_launcher.py
  - tests/selftest/init/test_init_runner.py
  - tests/selftest/init/test_init_self_update.py
  - tests/selftest/init/test_init_state_folders.py
  - tests/selftest/init/test_init_state_owner.py
  - tests/selftest/init/test_init_wrappers.py
  - tests/selftest/sbx/add.sh
  - tests/selftest/selfcheck/test_agent_config.py
  - tests/selftest/selfcheck/test_bundle_links.py
  - tests/selftest/selfcheck/test_claude_managed_settings.py
  - tests/selftest/selfcheck/test_claude_tool_claude.py
  - tests/selftest/selfcheck/test_cursor_self_update_off.py
  - tests/selftest/selfcheck/test_cursor_tool_cursor_agent.py
  - tests/selftest/selfcheck/test_hints.py
  - tests/selftest/selfcheck/test_image_ownership.py
  - tests/selftest/selfcheck/test_image_roots.py
  - tests/selftest/selfcheck/test_init_marker.py
  - tests/selftest/selfcheck/test_inventory.py
  - tests/selftest/selfcheck/test_root_owned_scan.py
  - tests/selftest/selfcheck/test_root_owned_state.py
  - tests/selftest/selfcheck/test_state_folders.py
  - tests/selftest/selfcheck/test_tools.py
findings:
  critical: 0
  warning: 3
  info: 5
  total: 8
status: issues_found
---

# Phase 9: Code Review Report

**Reviewed:** 2026-11-16
**Depth:** standard
**Files Reviewed:** 92
**Status:** issues_found

## Summary

Reviewed the sbx-init runner, its shared and agent steps, the selfcheck changes, the two wrappers, both Dockerfiles, compose, host scripts, guard rules, host checks and the init/selfcheck pytest suites. `uv run pytest` passes (422 tests).

No grep hit remains for any of the 19 deleted files outside planning docs and the stale `.claude/CLAUDE.md` (out of scope by instruction). The only `.best-practices-skills` mentions left are the migration note and two tests that assert the stale file is left alone.

Symlink handling holds up. The link step recognises its own links lexically and only calls `Path.unlink` on them, so it never deletes a user folder or follows a link out of the clone. The ownership walk uses `lstat` and `os.lchown` and never follows links. The state-folder name check rejects absolute and `..` names. The lock fd is not inherited by the installer (Python opens it close-on-exec). The marker is removed under the lock before any step runs and is written only after every step passed.

Three real defects remain: an orphaned GSD installer after Ctrl-C or a closed terminal, a likely loss of the agents folder on PATH inside the agent's own shell tool, and a dead-end fix hint when the clone folder exists but is incomplete.

## Warnings

### WR-01: Ctrl-C or a closed terminal leaves the GSD installer running after the lock is released

**File:** `base/init/gsd_sync.py:87-123` (with `base/init/init_runner.py:263-266`)
**Issue:** The installer is started with `start_new_session=True`, so it is in its own session and does not receive the terminal's SIGINT or SIGHUP. `_wait_or_stop` catches only `subprocess.TimeoutExpired`. On Ctrl-C, `KeyboardInterrupt` (not an `Exception`, so `_run_step` does not catch it either) unwinds through `run_init`'s `finally`, which closes the lock handle. The installer keeps writing into `state/<agent>` and `skills/` while the lock is free. A rerun of `sbx-init` then takes the lock and runs a second installer concurrently with the orphan, which is the exact race D-09 says the lock prevents ("also on a crash or Ctrl-C"). The temp log file is also leaked. Closing the terminal (`docker exec` disconnect) behaves the same way.
**Fix:** Kill the installer's group on any interruption, then re-raise:
```python
def _wait_or_stop(process: subprocess.Popen, time_limit_seconds: int) -> bool:
    try:
        process.wait(timeout=time_limit_seconds)
    except subprocess.TimeoutExpired:
        _kill_group(process)

        return True
    except BaseException:
        _kill_group(process)

        raise

    return False
```
Add a pytest case that sends the parent SIGINT while a stand-in installer sleeps, then asserts the stand-in is gone. Also remove the log file on that path.

### WR-02: The agents folder on PATH probably does not reach the agent's own Bash tool (unverified)

**File:** `claude/bin/sbx-claude:25-28`, `cursor/bin/sbx-cursor:25-28`, README.md:193
**Issue:** D-20 relies on the wrapper's PATH prefix reaching everything the agent starts, including `/gsd-review`, which finds the CLIs with `command -v claude` / `command -v cursor-agent`. The project already records that "a login shell may reset PATH" (`base/Dockerfile:97`, which is why the JDK tools are linked into `/usr/local/bin`). On Ubuntu, `/etc/profile` sets PATH unconditionally for a non-root login shell. Claude Code runs its Bash tool through a login shell with a shell snapshot, so the tool's PATH is probably the reset one without `/opt/sbx/agents/bin`. In that case the claim in README.md:193 is false and `/gsd-review` reports no `claude`. No unit test or host check exercises a login shell. The wrapper tests only check the wrapper's own `PATH`, and H-27 only checks `command -v claude` in a plain shell.
**Fix:** Verify on the Mac with `sbx-claude` then `! bash -lc 'command -v claude'`, or add a host check that runs `bash -lc 'command -v claude'` after the wrapper sets PATH. If the login shell resets it, set a marker variable in the wrapper (for example `SBX_AGENT_SESSION=1`) and have the image's `/etc/profile.d/` or `.bashrc` re-add the agents folder only when that variable is set. That keeps a plain shell off the PATH and the agent's child shells on it.

### WR-03: The "no clone" fix is a dead end when the clone folder exists but is incomplete

**File:** `base/init/best_practices_link.py:28-34` (with `base/bin/sbx-bundle-clone:16-20`)
**Issue:** The "no clone" branch tests only `rules/` (Claude) or `skills/` (Cursor) with `is_dir()`. If `$SBX_BUNDLE_DIR` exists but lacks that folder (a Cursor sandbox whose repo has `rules/` and no `skills/`, a half-restored folder, an empty folder), the step prints `no best-practices clone at ...` with the fix "run sbx-gh-login, then sbx-bundle-clone". `sbx-bundle-clone` refuses an existing folder (`[ -e "$SBX_BUNDLE_DIR" ]`, exit 1), so the user cannot follow the fix. Because no marker is written, both wrappers refuse until the folder is moved by hand, and nothing says so.
**Fix:** Split the two cases:
```python
if not bundle_dir.exists():
    return failed(f"no best-practices clone at {bundle_dir}", "run sbx-gh-login, then sbx-bundle-clone; ...")

if not needed_dir.is_dir():
    return failed(
        f"{bundle_dir} exists but has no {needed_dir.name}/ folder",
        f"check that {bundle_dir} is a clone of the best-practices repo; move it aside and run sbx-bundle-clone, or run git -C {bundle_dir} pull",
    )
```
Mirror the same split in `bundle_links_result` in the selfcheck.

## Info

### IN-01: Problems hide a clash in the same run

**File:** `base/init/best_practices_link.py:144-151`
**Issue:** `_result` returns on `problem_list` before it looks at `clash_list`. If one skill hits an I/O error and another is a clash, the FAIL names only the I/O error and the fix says "make the config folder writable"; the clash is reported only on the next run. The user needs two reruns for what one could show.
**Fix:** Report both in one FAIL, joining the I/O problems and the clash sentences. Use the clash fix text when a clash exists.

### IN-02: `_take_lock` leaks the handle when `flock` fails with something other than EWOULDBLOCK

**File:** `base/init/init_runner.py:203-213`
**Issue:** Only `BlockingIOError` closes `handle`. Another `OSError` from `fcntl.flock` (for example ENOLCK on an unusual filesystem) propagates with the file still open. `run_init` then reports "cannot open <lock>", which is also the wrong wording for a failed lock. The process exits soon after, so the effect is small.
**Fix:** Close the handle in a `finally`-style branch and word the message "cannot lock".

### IN-03: Hard-coded `/home/sandbox` in hint text

**File:** `base/init/init_runner.py:219`, `base/init/init_runner.py:253`
**Issue:** Both hints say `check that /home/sandbox is writable` as a literal, while `paths.HOME_DIR` exists. If the home path moves, the hints go stale.
**Fix:** Build the text from `paths.HOME_DIR`.

### IN-04: Shipped wrappers carry test-only environment overrides that bypass the gate

**File:** `claude/bin/sbx-claude:12-13`, `cursor/bin/sbx-cursor:12-13`
**Issue:** `SBX_INIT_MARKER` and `SBX_AGENT_BIN_DIR` exist for the pytest suite, but any user shell can set them (`SBX_INIT_MARKER=/dev/null sbx-claude`) and skip the refusal. The header says this is not a security boundary, which matches D-20, but README.md:193 and the Phase intent ("the user cannot run an agent in a sandbox that was not initialised") read as stronger than that.
**Fix:** Either keep the knobs and say in README.md that the refusal is a nudge, or drop the overrides and let the tests run the wrapper from a copy with the two defaults rewritten.

### IN-05: `_place_link` returns a bool no caller reads

**File:** `base/init/best_practices_link.py:61-86`
**Issue:** The `-> bool` result (True on success, False on clash or error) is ignored at both call sites (lines 48 and 100). The clash and problem lists carry the information.
**Fix:** Return `None`, or have the callers use the result and drop one of the two lists.

---

_Reviewed: 2026-11-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
