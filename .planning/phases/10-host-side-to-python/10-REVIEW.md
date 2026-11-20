---
phase: 10-host-side-to-python
reviewed: 2026-11-20T00:00:00Z
depth: standard
files_reviewed: 80
files_reviewed_list:
  - bin/sbx-add
  - bin/sbx-fix-modes
  - bin/sbx-list
  - bin/sbx-migrate-registry
  - bin/sbx-rm
  - bin/sbx-shell
  - bin/sbx-start
  - bin/sbx-stop
  - bin/sbx-upgrade
  - build.sh
  - clean.sh
  - compose.yml
  - host-test.sh
  - pyproject.toml
  - sbx/__init__.py
  - sbx/add.py
  - sbx/build.py
  - sbx/clean.py
  - sbx/cli.py
  - sbx/docker.py
  - sbx/fix_modes.py
  - sbx/host_test.py
  - sbx/hosttest_names.py
  - sbx/list_sandboxes.py
  - sbx/migrate_registry.py
  - sbx/names.py
  - sbx/overlap.py
  - sbx/registry.py
  - sbx/rm.py
  - sbx/shell.py
  - sbx/start.py
  - sbx/stop.py
  - sbx/upgrade.py
  - tests/guard/guard_helpers.py
  - tests/guard/test_guard_isolation.py
  - tests/guard/test_guard_launchers.py
  - tests/guard/test_guard_linters.py
  - tests/guard/test_guard_start.py
  - tests/guard/test_guard_supply_chain.py
  - tests/integration/agent_specs.py
  - tests/integration/conftest.py
  - tests/integration/scenario_helpers.py
  - tests/integration/test_failed_upgrade.py
  - tests/integration/test_first_run_and_relink.py
  - tests/integration/test_git_on_host_repo.py
  - tests/integration/test_images_match_versions.py
  - tests/integration/test_init_and_selfcheck.py
  - tests/integration/test_owner_fix.py
  - tests/integration/test_persistence.py
  - tests/integration/test_pin_digests.py
  - tests/integration/test_refusal.py
  - tests/integration/test_sandbox_isolation.py
  - tests/integration/test_sandbox_lifecycle.py
  - tests/integration/test_sandbox_list.py
  - tests/integration/test_sandbox_rm.py
  - tests/integration/test_sandbox_shell.py
  - tests/integration/test_upgrade_running_sandbox.py
  - tests/unit/init/test_init_inventory.py
  - tests/unit/sbx/conftest.py
  - tests/unit/sbx/sbx_helpers.py
  - tests/unit/sbx/test_sbx_add.py
  - tests/unit/sbx/test_sbx_build.py
  - tests/unit/sbx/test_sbx_clean.py
  - tests/unit/sbx/test_sbx_compose.py
  - tests/unit/sbx/test_sbx_fix_modes.py
  - tests/unit/sbx/test_sbx_host_test.py
  - tests/unit/sbx/test_sbx_integration_text_helpers.py
  - tests/unit/sbx/test_sbx_launchers.py
  - tests/unit/sbx/test_sbx_list.py
  - tests/unit/sbx/test_sbx_migrate_registry.py
  - tests/unit/sbx/test_sbx_names.py
  - tests/unit/sbx/test_sbx_overlap.py
  - tests/unit/sbx/test_sbx_registry.py
  - tests/unit/sbx/test_sbx_rm.py
  - tests/unit/sbx/test_sbx_scenario_helpers.py
  - tests/unit/sbx/test_sbx_shell.py
  - tests/unit/sbx/test_sbx_start_stop.py
  - tests/unit/sbx/test_sbx_upgrade.py
  - tests/unit/selfcheck/test_inventory.py
  - versions.env
findings:
  critical: 1
  warning: 5
  info: 4
  total: 10
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-11-20
**Depth:** standard
**Files Reviewed:** 80
**Status:** issues_found

## Summary

The production modules are carefully built: Docker is injected, the Compose environment is rebuilt from the entry (COMPOSE_ keys dropped), the launchers are thin, overlap checks compare directories with `samefile`, and the only delete sites are `rm.py` and `clean.py`. I found no defect in the Compose argument lists, the `sbx-shell` exec and exit-code path, or the name rule.

One real isolation hole: `sbx-fix-modes` runs on the host against a `.git` directory the sandbox can write, and follows symlinks planted inside the project directory (reproduced below). The remaining findings are robustness: the registry write is not atomic, `clean.sh` identifies run directories by name prefix only, `run_command` lets `KeyboardInterrupt` and `OSError` escape as tracebacks, and `sbx-rm --unregister` on a broken entry removes any container named `sbx-NAME` without checking the `sbx.name` label.

pyflakes reports one unused import (`Path` in `sbx/fix_modes.py`). The unit and guard suites pass here (517 passed, 1 skipped); no Docker was available to run the integration suite.

## Critical Issues

### CR-01: sbx-fix-modes follows symlinks from a sandbox-controlled git index and changes modes outside the mount

**File:** `sbx/fix_modes.py:121-135` (`_read_index`), `sbx/fix_modes.py:176-194` (`_fix_modes` loop), `sbx/fix_modes.py:140-150` (`_fix_host_mode`)
**Issue:** The command runs on the host (outside the container) and trusts `git ls-files -s -z` output from `<SBX_DIR>/<name>/.git`, which the agent in the sandbox can write freely. The only guard per path is `os.path.islink(path) or not os.path.isfile(path)`, which checks the final component only. A sandbox can therefore:

1. create a symlink inside the project directory, for example `evil -> /Users/you/.ssh` (a relative link such as `../../..` also works, and nothing is validated),
2. write an index entry `100644 <blob> 0 evil/id_rsa` (git accepts it; `verify_path` forbids `..` and `.git` parts, not symlink-leading paths).

`sbx-fix-modes NAME` then runs `os.chmod("<project>/evil/id_rsa", 0o644)` and, when `xattr` exists, writes `user.containers.override_stat` on the real file. I reproduced the index step on this machine:

```
git init; ln -s ../victim evil
git update-index --add --cacheinfo 100644,$h,evil/key   # accepted
git ls-files -s -z                                       # prints evil/key
git update-index --add --cacheinfo 100644,$h,../victim/key  # rejected: Invalid path
```

This breaks the stated isolation guarantee (the sandbox can only affect its one mount; the host only acts on what the sandbox may touch). The primitive is chmod to 644/755 plus an xattr write on any file the host user owns, for example making a private key group/world readable or a data file executable. No unit test covers a symlinked directory inside the index.

**Fix:** Resolve and contain each path before touching it, and skip anything that escapes the project directory:

```python
project_real = os.path.realpath(project_dir)

for git_mode, relative_path in _read_index(project_dir):
    path = f"{project_dir}/{relative_path}"
    resolved = os.path.realpath(path)

    if os.path.commonpath([project_real, resolved]) != project_real:
        continue
    if resolved != os.path.join(project_real, os.path.normpath(relative_path)):
        continue  # a symlinked directory in the path
    ...
```

Alternatively use `os.open(..., O_NOFOLLOW)` per component with `dir_fd` and `fchmod`. Add a unit test with a tracked-looking entry beneath a symlinked directory pointing outside the repo, asserting the target mode is unchanged. Also consider running git with `-c core.fsmonitor=false -c core.hooksPath=/dev/null` and `GIT_CONFIG_GLOBAL` untouched, since the host runs git against a sandbox-writable `.git/config`.

## Warnings

### WR-01: Registry entry is written non-atomically; a crash or concurrent reader sees a truncated file

**File:** `sbx/registry.py:107-118` (`write_entry`)
**Issue:** The entry is created with `open(file, "x")` and then written in place. Two consequences: (a) a concurrent `sbx-list` or a concurrent `sbx-add` (whose `_refuse_sandbox_overlap` calls `read_entry` on every entry and aborts on a parse error, `sbx/add.py:68-76`) can read an empty or half-written file and report "broken entry" or refuse with a misleading error; (b) a failure mid-write (disk full, kill) leaves a truncated `NAME.json` that blocks `sbx-add` for that name ("already registered") until the user runs `sbx-rm NAME --unregister`. Also, an `OSError` of `FileExistsError` (lost race) is reported as "could not write ...; nothing was registered", which is true but hides why.
**Fix:** Write the JSON to a temp file in the same directory, `os.link(tmp, file)` (fails with `FileExistsError` if the name exists, keeping the exclusive-create guarantee), then unlink the temp file. Catch `FileExistsError` separately and say the name is already registered. Related: `sbx/add.py:123-124` creates `<path>/<name>` and `<path>/state` before `write_entry`, so a failed write leaves directories behind despite the module header "Nothing is made until every check has passed"; two concurrent `sbx-add` calls for different names on one path both pass the overlap check and share `state/`.

### WR-02: clean.sh deletes run directories by name prefix alone

**File:** `sbx/clean.py:62-72` (`run_dir_list`), `sbx/clean.py:263-282` (`_remove_dir_list`)
**Issue:** With `--yes`, every plain directory under the temp base whose name starts with `sbx-hosttest-` is `shutil.rmtree`d. Nothing checks that it is a host-test run directory (no marker file, no cross-check against the registry), and nothing checks that a host-test run is not in progress right now (a concurrent `./host-test.sh` loses its run directory and its sandboxes' mounts). A user who registers a sandbox under `$TMPDIR/sbx-hosttest-mine` gets its project and `state/` (agent login) deleted, and `rm.py`'s promise "nothing in the sandbox directory is deleted" is bypassed by this sibling command. This is the single largest data-loss path in the phase.
**Fix:** Have the integration `run_dir` fixture write a marker (for example `.sbx-hosttest-run`) and delete only directories that hold it; also skip any directory that equals or contains a path in a readable registry entry (`registry.list_entry_names` plus `read_entry`), and skip a directory whose marker names a live PID or has a recent mtime. Add a unit test where a registry entry points at `sbx-hosttest-x/`.

### WR-03: Run-directory verdict matches the marker anywhere in the mount source

**File:** `sbx/clean.py:100-110` (`_run_dir_name_in_source`), `sbx/hosttest_names.py:57-64` (`is_run_dir_mount`)
**Issue:** `mount_source.find(f"{temp_base}/sbx-hosttest-")` is a substring search, not a prefix test. With the default base `/tmp`, a user sandbox mounted at `/Users/you/tmp/sbx-hosttest-foo` (the substring `/tmp/sbx-hosttest-` appears) gets the verdict "remove" when its container is named `sbx-hosttest-*`, and the same helper in the fixtures treats it as a test container to `docker rm -f`. The comment says the substring search is for a Docker Desktop prefix such as `/private` or `/host_mnt`; that needs only a prefix-allow-list, not "anywhere". The logic is also written twice (clean.py and hosttest_names.py) and can drift.
**Fix:** Strip a known set of prefixes (`/host_mnt`, `/private`) and then use `startswith(marker)`; call one shared function from both `clean.py` and `is_run_dir_mount`.

### WR-04: run_command lets KeyboardInterrupt and OSError escape as tracebacks

**File:** `sbx/cli.py:46-60` (`run_command`); examples at `sbx/registry.py:143` (`registry.iterdir()`), `sbx/build.py:239` (`TemporaryDirectory(dir=TMPDIR)`), `sbx/docker.py:55` (`subprocess.run`)
**Issue:** Only `UsageError` and `SbxError` are handled. Ctrl-C during `sbx-upgrade` (a long `docker build`) or `sbx-start` (`compose up --wait`) prints a Python traceback instead of a one-line refusal; an unreadable registry directory (`PermissionError` from `iterdir()` in `sbx-list`/`sbx-add`) and a `TMPDIR` that does not exist with `SBX_CA_CERT` set (`FileNotFoundError` in `build.py`) do the same. This contradicts the project error convention (exit 0/1/2, one `<command>: <text>` line on stderr). `host_test.py` has the same gap outside `run_and_log`: an interrupt during `_write_context` is uncaught.
**Fix:** In `run_command` add `except KeyboardInterrupt: print_notice(command_name, "interrupted"); return 130` and `except OSError as e: print_notice(command_name, str(e)); return 1`.

### WR-05: sbx-rm --unregister on a broken entry removes any container named sbx-NAME

**File:** `sbx/rm.py:149-170` (`_remove_broken_sandbox`)
**Issue:** The healthy path goes through Compose and so only touches the project's own container. The broken-entry path runs `docker container inspect/stop/rm sbx-NAME` by name only. A container named `sbx-NAME` that is not a sandbox (no `sbx.name` label; for example an unrelated container the user named that way, or one left by the old layout) is stopped and removed, and then the entry is deleted. Every other host query (`container_state_map`) already filters on the `sbx.name` label, so this path is the odd one out. Also, `sandbox_is_running` returning False because `docker inspect` failed for a reason other than "not running" lets the healthy path skip the confirmation (`_confirm_if_running`).
**Fix:** Inspect with `--format '{{index .Config.Labels "sbx.name"}}'` and require it to equal `NAME` before stop/rm; otherwise refuse with a message naming the container and leave the entry alone.

## Info

### IN-01: Unused import and unused parameter

**File:** `sbx/fix_modes.py:24` (`from pathlib import Path`), `sbx/migrate_registry.py:154-155` (`docker` parameter of `main`, and the `run_docker`/`Docker` imports it needs)
**Issue:** `Path` is never used (pyflakes). `migrate_registry.main` accepts and ignores `docker`; the module never runs Docker.
**Fix:** Delete the import; drop the parameter and the two imports (check `test_sbx_launchers.py`/`test_sbx_migrate_registry.py` for callers that pass it).

### IN-02: sbx-upgrade reports failure after a successful upgrade; sbx-stop says "is stopped" for a missing container

**File:** `sbx/upgrade.py:66-70` and `sbx/upgrade.py:104`, `sbx/stop.py:42-47`
**Issue:** If `docker exec ... cat /etc/sbx/tool-versions` fails after the recreate succeeded, `sbx-upgrade` exits 1 with "could not read", although the images were built and the sandbox recreated; a script treating exit 1 as "upgrade failed" will retry a finished upgrade. `sbx-stop` prints "sbx-NAME is stopped" even when Compose found no container to stop (stop exits 0 with none), which reads as a confirmation that it existed.
**Fix:** Print the tool-versions failure as a notice and exit 0 (or a distinct warning); for `sbx-stop` use the already-available `container_state_map` or a `container inspect` to say "has no container" when absent, without adding directory checks.

### IN-03: Convention drift in tests and comments

**File:** `tests/unit/sbx/test_sbx_add.py:94`, `tests/unit/sbx/test_sbx_overlap.py:40`, `tests/unit/sbx/test_sbx_registry.py:17`, `tests/unit/sbx/test_sbx_names.py:21`
**Issue:** The project rule is ASCII only in source files; these tests contain a literal `cafe` with an accented e. The intent (non-ASCII path and name coverage) is legitimate.
**Fix:** Write the character as an escape (`"café"`) so the source stays ASCII and the test still exercises the same bytes.

### IN-04: clean.sh --yes prunes all unused images and the whole build cache, beyond sbx

**File:** `sbx/clean.py:292-299` (`_remove_unused_images`)
**Issue:** `docker builder prune -a -f` and `docker image prune -a -f` remove every unused image and cache entry on the Docker host, including those of unrelated projects. The dry run states this and the module header says "Other containers, their images and all volumes are kept", which is true only for images some container (even stopped) uses. A user reading the header expects only sbx leftovers to go.
**Fix:** Reword the header to "images no container uses, of any project", or restrict to sbx images with `docker image prune -a -f --filter label=...` / explicit `docker rmi` of `sbx-*:test` tags.

---

_Reviewed: 2026-11-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
