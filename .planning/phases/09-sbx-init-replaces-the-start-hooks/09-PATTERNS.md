# Phase 9: sbx-init replaces the start hooks: Pattern Map

**Mapped:** 2026-11-16
**Files analyzed:** 27 new or modified (deletions listed in RESEARCH.md "Inventory" are not mapped)
**Analogs found:** 25 / 27

All analog paths below were checked against `git ls-files` (tracked source, no mirrors). Line numbers are from this session's reads. Names added by this phase say best-practices, never bundle (D-29); the analog files keep their old names.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `base/init/sbx-init` | launcher | request-response | `base/selfcheck/sbx-selfcheck` | exact |
| `base/init/init_runner.py` | service (runner) | batch | `base/selfcheck/runner.py` | exact |
| `base/init/init_step.py` (or reuse `Check`) | model | transform | `base/selfcheck/check_result.py` | exact |
| `base/init/state_folders.py` + `steps/010_state_folders.py` | step | file-I/O | `base/selfcheck/checks/030_state_folders.py` | role-match |
| `base/init/state_owner.py` + `steps/800_state_owner.py` | step | file-I/O | `base/selfcheck/checks/040_root_owned_state.py` + `tree_walk.py` | role-match |
| `base/init/gsd_sync.py` | utility | batch (subprocess) | `claude/start.d/05-gsd` (being replaced) | role-match |
| `base/init/best_practices_link.py` | utility | file-I/O | `base/selfcheck/bundle_links.py` + `base/bin/sbx-link-bundle` | role-match |
| `claude/init/050_gsd_sync.py`, `900_best_practices_links.py` | step | file-I/O | `claude/selfcheck/080_bundle_links.py`, `claude/selfcheck/070_gsd_synced.py` | exact |
| `cursor/init/050_gsd_sync.py`, `060_self_update_off.py`, `900_best_practices_links.py` | step | file-I/O | `cursor/selfcheck/080_bundle_links.py`, `cursor/start.d/02-no-self-update` | exact / role-match |
| `base/selfcheck/root_owned_scan.py` (extracted) | utility | file-I/O | `base/selfcheck/checks/040_root_owned_state.py` | exact (move) |
| `base/selfcheck/paths.py`, `bundle_links.py`, `hints.py`, `image_roots.py`, `image_ownership.py` | utility | transform | self (edit) | exact |
| `base/selfcheck/checks/035_init_marker.py` | check | request-response | `base/selfcheck/checks/030_state_folders.py` | exact |
| `claude/selfcheck/*`, `cursor/selfcheck/*` (agent not on PATH, tool PATH) | check | request-response | `claude/selfcheck/080_bundle_links.py` | exact |
| `claude/bin/sbx-claude`, `cursor/bin/sbx-cursor` | wrapper | request-response | `claude/bin/sbx-claude` (self) | exact (rewrite) |
| `base/bin/sbx-bundle-clone`, `base/bin/sbx-gh-login` | wrapper | request-response | self (edit) | exact |
| `base/Dockerfile`, `claude/Dockerfile`, `cursor/Dockerfile` | config | batch | self; init block copies `base/Dockerfile:256-262` self-check block | exact |
| `bin/sbx-lib.sh`, `bin/sbx-upgrade`, `bin/sbx-start`, `bin/sbx-shell` | utility | request-response | self (edit) | exact |
| `tests/selftest/init/conftest.py`, `init_helpers.py` | test | batch | `tests/selftest/selfcheck/conftest.py`, `helpers.py` | exact |
| `tests/selftest/init/test_init_*.py` | test | batch | `tests/selftest/selfcheck/test_root_owned_state.py`, `test_inventory.py`, `test_bundle_links.py` | exact |
| `tests/selftest/selfcheck/test_inventory.py` and friends | test | batch | self (edit) | exact |
| `tests/host/lib-sandbox.sh`, `h16`, `h27`, `h28`, `h34`, new `h35` | test | request-response | existing `tests/host/h34-selfcheck.sh` | role-match |
| `tests/guard/*.sh` | test | batch | self (edit) | exact |
| `pyproject.toml` | config | n/a | self (edit) | exact |

## Pattern Assignments

### `base/init/sbx-init` (launcher)

**Analog:** `base/selfcheck/sbx-selfcheck` (lines 1-34). Copy it, change the title text, add `init` and `selfcheck` to `sys.path`, call `init_runner.main`.

```python
#!/usr/bin/python3 -I
import sys
from pathlib import Path

def run() -> int:
    sys.dont_write_bytecode = True
    launcher_dir = Path(__file__).resolve().parent
    sys.path.insert(0, str(launcher_dir))
    sys.path.append(str(launcher_dir / "agents"))

    import runner
    return runner.main(sys.argv[1:], runner.SHARED_CHECKS_DIR, runner.AGENT_CHECKS_DIR)

if __name__ == "__main__":
    sys.exit(run())
```

Differences: the init launcher must also put `/usr/local/lib/sbx-selfcheck` on `sys.path` (to reuse `check_result`, `paths`, `users`, `tree_walk`, `bundle_links`, `hints`). Avoid a module named `runner.py` in the init folder; use `init_runner.py` (both would sit on one path).

### `base/init/init_runner.py` (runner)

**Analog:** `base/selfcheck/runner.py`.

**Banner and constants** (lines 1-27): three-line banner, `Path(__file__).resolve().parent / "steps"` for shared steps, `Path("/etc/sbx/init.d")` for agent steps, `_FIX_LINE_INDENT = "      "`, `_USAGE_TEXT`.

**Loader to copy verbatim** (lines 34-44, 54-81): `load_check_module` (`importlib.util.spec_from_file_location`, qualified module name from parent dir and stem), `_is_check_list`, `_module_check_list` (load error becomes a FAIL step through `_load_failure_check`). Rename `CHECK_LIST` to `STEP_LIST`, prefix `sbx_init_step_`.

**Run and print** (lines 120-165):
```python
def _run_check(check: Check) -> CheckResult:
    try:
        result = check.function()
    except Exception as e:
        return failed(f"raised {type(e).__name__}: {e}", "this is a bug ...; " + rebuild_hint())
    if not isinstance(result, CheckResult):
        return failed(...)
    return result

def _outcome_lines(name, result):
    detail = one_line(result.detail)
    if result.passed:
        return [f"PASS: {name}: {detail}"]          # init prints "OK:"
    return [f"FAIL: {name}: {detail}", f"{_FIX_LINE_INDENT}fix: {one_line(result.hint)}"]
```

Init differences (flag as honest asymmetries): print `OK:` not `PASS:`; merge shared and agent step files and sort by file stem (not shared-then-agent) so the ownership step (800) runs after the agent GSD step (050); stop at the first FAIL, except the best-practices step, which reports its clash after linking the rest (D-07); lock (`fcntl.flock` LOCK_EX|LOCK_NB, RESEARCH Pattern 4) before anything, remove marker after taking the lock (D-26), touch marker only when all steps pass, last line "run sbx-selfcheck" (D-10); usage error exit 2, FAIL exit 1. `output.flush()` per line (lines 147-151).

### `base/init/init_step.py` or reuse (result type)

**Analog:** `base/selfcheck/check_result.py` lines 16-56. Reuse `CheckResult`, `Check`, `passed`, `failed` (refuses an empty hint, line 38), `capped_problem_detail`, `one_line`. Step functions return `CheckResult`, steps are `Check(name, function)`. No new type needed.

### `base/init/state_folders.py` and `steps/010_state_folders.py` (step, file-I/O)

**Analog:** `base/selfcheck/checks/030_state_folders.py` (lines 9-40). Same list source; init makes what the check verifies.

```python
_BASE_STATE_DIR_LIST = ["shell", "gh", "git"]
folder_list = _BASE_STATE_DIR_LIST + state_dirs_text.split()
```

Move `_BASE_STATE_DIR_LIST` into `paths.py` as `BASE_STATE_DIR_LIST` (RESEARCH structure) so both import it. Init loop: reject absolute or `..` names, `(state_dir / folder).mkdir(parents=True, exist_ok=True)`, catch `OSError` per name into `problem_list`, then `problem_list_result(...)`. Success detail style: `f"{', '.join(folder_list)} exist under {state_dir}"`.

### `base/init/state_owner.py` and `steps/800_state_owner.py` (step, file-I/O)

**Analog:** `base/selfcheck/checks/040_root_owned_state.py` (extract `scan_owned_state` and `SKIPPED_STATE_DIR_SET` into `root_owned_scan.py`; delete the `_GSD_SYNC_FOLDER_SET`, `_is_tolerated_path` tolerance, D-13) and `base/selfcheck/tree_walk.py` (`walk_tree`, does not follow links). Core shape is in RESEARCH "Ownership step" (lines 482-499): scan with injectable `owner_uid`, `os.lchown(path, 1000, 1000)` per entry, collect `OSError` into a list, `failed(capped_problem_detail(...), fix)` else `passed(f"{n} paths given back to sandbox")`. Use `users.py` for the sandbox uid/gid instead of literals.

Test analog for injection style: `tests/selftest/selfcheck/test_root_owned_state.py:57` uses `os.getuid()` as the stand-in for root.

### `base/init/gsd_sync.py` (utility, subprocess)

**Analog (behaviour to port, then delete):** `claude/start.d/05-gsd` lines 21-60.

```bash
mkdir -p "$configDir" 2>/dev/null   # made first: the installer hangs on a folder it cannot create
logFile=$(mktemp)
timeout 300 gsd-core --claude --global --config-dir "$configDir" </dev/null >"$logFile" 2>&1
# on failure: cat "$logFile" >&2 ; print only on failure
```

Python: `tempfile` output file, `subprocess.run([...], stdin=DEVNULL, stdout=file, stderr=STDOUT, start_new_session=True)`, kill the process group on timeout (RESEARCH Pitfall 9). Argument lists only. Do NOT port `check_synced_version` (lines 53-70): version compare is the self-check's job (D-12; `claude/selfcheck/070_gsd_synced.py` and `agent_config.gsd_synced_result` already do it). For the time limit, `base/selfcheck/commands.py:12,19-31` `run_command` has a hard-coded 60 s; extend with `timeout_seconds` or keep a local runner.

### `base/init/best_practices_link.py` (utility, file-I/O)

**Analogs:** `base/selfcheck/bundle_links.py` (link text constants lines 13-14: `"../../best-practices/rules"`, `"../../../best-practices/skills/{name}"`; skill listing `_bundle_skill_name_list` lines 122-133; `bundle_links_result(config_dir, bundle_dir, links_rules)` signature at line ~201; `.best-practices-skills` logic to drop) and `base/bin/sbx-link-bundle` (behaviour being fixed: `rm -rf` at lines 58, 70, 109).

Make `bundle_skill_name_list` public and shared. Own-link test (RESEARCH "Bundle step core"):
```python
def own_best_practices_link(link: Path, bundle_skills_dir: Path) -> bool:
    if not link.is_symlink():
        return False
    target_text = os.path.normpath(link.parent / link.readlink())
    return target_text.startswith(str(bundle_skills_dir) + "/")
```
Three-way per `skills/NAME` (nothing: link; own link: unlink and relink; anything else: remember and continue). Then `unlink()` own links whose skill the clone dropped. Never `rmtree`. `paths.link_text` and `paths.is_under` (paths.py lines 29-39) are reusable helpers. Missing clone FAILs with fix naming `sbx-gh-login` then `sbx-bundle-clone` (D-24). `rules` follows the same rule (D-23). No-clone check mirrors `bundle_links_result` lines 105-110 (`needed_dir.is_dir()`).

### Agent step files: `claude/init/*.py`, `cursor/init/*.py`

**Analog:** `claude/selfcheck/080_bundle_links.py` (whole file, 20 lines). Copy the layout: banner "The image copies this file to /etc/sbx/init.d/claude/", imports from the shared libs and `claude_shared`, a private `_step_*` function, and a module-level list.

```python
from check_result import Check, CheckResult
from claude_shared import CONFIG_DIR
from paths import BUNDLE_DIR

def _step_claude_best_practices_links() -> CheckResult:
    return best_practices_links_result(CONFIG_DIR, BUNDLE_DIR, True)

STEP_LIST = [Check("claude-best-practices-links", _step_claude_best_practices_links)]
```

Cursor is identical with `cursor_shared.CONFIG_DIR` and `links_rules=False` (symmetry, D-17). Filenames: `050_gsd_sync.py`, `900_best_practices_links.py`; Cursor adds `060_self_update_off.py`. Agent-shared helpers go in the existing `claude/selfcheck/lib/claude_shared.py` (CONFIG_DIR at line 12, `IMAGE_ROOT_LIST` at line 17; add `/opt/sbx/agents`). Order per D-25: 010 folders, 050 GSD, 060 channel, 800 ownership, 900 links.

### `cursor/init/060_self_update_off.py` (step, file-I/O)

**Analog (behaviour to port):** `cursor/start.d/02-no-self-update` lines 36-58: make config folder, `channel = "static"`, keep other keys, new file when missing or empty, invalid JSON fails and leaves the file untouched. Python with `json.load`/`json.dump` and temp file plus `os.replace`; refuse non-object JSON. Verification stays in `cursor/selfcheck/050_self_update_off.py`.

### `claude/bin/sbx-claude`, `cursor/bin/sbx-cursor` (wrapper)

**Analog:** existing `claude/bin/sbx-claude` (banner, `set -eu`, `Main / Entry Point` banner, `exec claude "$@"`). Drop the warning block and `sleep 5` (lines 12-24). New body is in RESEARCH "Wrapper" (lines 505-524): `marker=${SBX_INIT_MARKER:-/home/sandbox/.sbx-init-done}`, `agentBinDir=${SBX_AGENT_BIN_DIR:-/opt/sbx/agents/bin}`, refuse with stderr message naming `sbx-init` and `exit 1`, else `PATH=$agentBinDir:$PATH; export PATH; exec claude "$@"`. Keep it thin shell (project rule); a pytest test pins the marker literal against `paths.INIT_MARKER_FILE`.

### `base/selfcheck/checks/035_init_marker.py` and agent "not on PATH" checks

**Analog:** `base/selfcheck/checks/030_state_folders.py` (header lines 1-14, `*_result(...)` pure function plus a `CHECK_LIST` entry reading constants from `paths`). Pattern: pure `init_marker_result(marker_file: Path) -> CheckResult` with injected path, fix text from a new `init_hint()` in `hints.py` ("run sbx-init in the sandbox shell"; it is not a Mac command). Agent checks follow `claude/selfcheck/080_bundle_links.py`. Update hints that say "the start makes/syncs ..." (030 line ~34, `agent_config.gsd_synced_result`, cursor `050`, `bundle_links.py:104` naming `/etc/sbx/start.d/10-best-practices`) to `init_hint()`.

### Dockerfiles

**Analog for the init install block:** `base/Dockerfile:256-262` (self-check: `mkdir -p`, `COPY --chmod=755` launcher, `--chmod=644` modules, `ln -s` into `/usr/local/bin`, `python3 -m py_compile` of every file so a syntax error stops the build). Replace lines 188-191, 199, 291 (entrypoint COPY, `/etc/sbx/start.d`, `ENTRYPOINT`); keep `CMD ["bash"]`. Agent images: `claude/Dockerfile:47-58` and `cursor/Dockerfile:37-49` currently COPY `start.d`; change to COPY of `init/` into `/etc/sbx/init.d/<agent>/`, mirroring how `selfcheck/` is copied to `/etc/sbx/selfcheck.d/<agent>/`. Link relocation: `claude/Dockerfile:20-23` (add `mkdir -p /opt/sbx/agents/bin && ln -s "$(readlink -f /usr/local/bin/claude)" ... && rm /usr/local/bin/claude`, not `--prefix`), `cursor/Dockerfile:27-31` (retarget the `ln -s`), smoke tests at `claude/Dockerfile:91` and `cursor/Dockerfile:97` use the full path plus `! command -v`.

### `bin/sbx-lib.sh` (host lib)

**Edit points:** lines 31-54 (`read_start_variable`, `load_name_rule` source `base/sbx-start-lib.sh`), 118, 313-343 (`wait_until_ready`), 346-367 (`bring_up_sandbox`). Move the three name-rule values inline verbatim before deleting the start library (RESEARCH Pitfall 1): pattern `'^[a-z][a-z0-9-]{0,30}$'`, the rule text, reserved list `"state best-practices"`. Verify with `bash tests/selftest/sbx/run-all.sh`; `tests/selftest/sbx/add.sh:218` stops copying the start library.

### `tests/selftest/init/*` (pytest)

**Analogs:** `tests/selftest/selfcheck/conftest.py` (header comment lines 1-6, fixtures `repo_dir`, `restorable_mode`, `from helpers import ...`), `helpers.py`, `test_root_owned_state.py` (header, `load_shared_check("040_root_owned_state")`, `tmp_path` tree fixture with abstract names `state1`, `outside1`, `file1`; real files and links, no mocks), `test_inventory.py` (name-order and count pinning), `test_bundle_links.py` (link fixtures).

Rules: unique module basenames (`init_helpers.py`, `test_init_runner.py`, never a second `helpers.py` or `test_bundle_links.py`); agent step files loaded by path like `runner.load_check_module`; a Python stub `gsd-core` on a temp PATH (the old `tests/selftest/entrypoint/support/fake-gsd` goes with its suite); inject `chown_function` and `owner_uid` as the root-owned test does; stand-in wrapper env via `SBX_INIT_MARKER` and `SBX_AGENT_BIN_DIR`. Update `pyproject.toml` `pythonpath` (add `base/init`) and `testpaths` (add `tests/selftest/init`). Update counts in `test_inventory.py:20-22` (shared 42, Claude 13, Cursor 11) and `tests/host/h34-selfcheck.sh:27-28`.

### Host checks and guard rules

**Analog:** `tests/host/h34-selfcheck.sh` (expected-count constants at lines 27-28, cross-checked by the inventory test) for H-34/H-35 shape; `tests/host/lib-sandbox.sh:141-205` `compose_up` (replace `wait_for_start_hooks` with `docker exec sbx-hosttest sbx-init`, output into `compose-up.log`). Guard edits: `tests/guard/lib.sh:21-26` (`ENTRY`, `HOOK_DIRS`, `SANDBOX_FILES`, `SHELL_FILES`), `supply-chain.sh:19,44`, `start.sh` (keep `compose_image_follows_agent_and_tag`, rename file), `isolation.sh:59`. Edit globs in the same commit that deletes files (Pitfall 4). Full edit and fate tables: RESEARCH.md "Inventory" and "Host check fates".

## Shared Patterns

### Result type and one-line output
**Source:** `base/selfcheck/check_result.py:33-56`
**Apply to:** every init step, runner, new self-check checks. `failed()` requires a fix hint; `one_line()` before printing; multi-item problems through `capped_problem_detail`.

### Module and file banners
**Source:** `base/selfcheck/runner.py:1-6, 18-20, 30-32` and the python rule: 82-col rule lines, title, "The image puts this file in ..." line, section banners, `Main / Entry Point` banner only where there is an entry block. Full names, `_list`/`_set`/`_map` suffixes, braces-style blank lines around control flow, early returns, no bare `except`, `pathlib`.

### Agent-file layout (base never names an agent)
**Source:** `claude/selfcheck/080_bundle_links.py` plus `claude/selfcheck/lib/claude_shared.py`. Agent images drop numbered files in a fixed folder; shared constants live in `paths.py`; agent constants in `*_shared.py`.

### Link and path helpers
**Source:** `base/selfcheck/paths.py:29-39` (`path_is_present`, `is_under`, `link_text`). Add `INIT_MARKER_FILE`, `INIT_LOCK_FILE`, `AGENT_BIN_DIR`, `BASE_STATE_DIR_LIST` here (lines 9-16 hold the existing constants).

### Shell style (wrappers, host scripts, Dockerfile RUN)
**Source:** `claude/bin/sbx-claude`; BSD/bash 3.2 portable (no `sed -i`, `readlink -f` on the Mac, `mapfile`); errors to stderr, exit 1 failure and 2 usage; scripts committed from the sandbox need the exec bit set in git.

### Error and fix messages
Init's FAIL fixes name the next command (`sbx-init`, `sbx-gh-login`, `sbx-bundle-clone`), say best-practices not bundle in new text (D-29), and never use dashes as punctuation. No phase or decision IDs in code or tests.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `fcntl.flock` run lock in `init_runner.py` | utility | event-driven | No locking exists in the repo; use RESEARCH "Lock" snippet (probed) |
| Marker write and removal | utility | file-I/O | Nothing records state in the container layer today; follow RESEARCH Pattern 4 |
| `tests/host/h35-*.sh` (root-owned plant then `sbx-init`) | test | request-response | New check; use `h34-selfcheck.sh` and `lib-sandbox.sh` structure, behaviour depends on Docker Desktop ownership (RESEARCH A1) |

## Metadata

**Analog search scope:** `base/`, `claude/`, `cursor/`, `bin/`, `tests/selftest/`, `tests/host/`, `tests/guard/`
**Files scanned:** about 150 tracked files listed; 14 read in full or in part this session, others carried from RESEARCH.md reads
**Pattern extraction date:** 2026-11-16
