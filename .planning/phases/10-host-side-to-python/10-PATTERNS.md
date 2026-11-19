# Phase 10: Host side to Python - Pattern Map

**Mapped:** 2026-11-19
**Files analyzed:** 40 new or changed (grouped below)
**Analogs found:** 36 / 40 (the other 4 have no Python analog; use RESEARCH.md sketches)

Decisions D-24 to D-28 override RESEARCH.md. Notably D-07: no old-entry detection anywhere except `sbx-migrate-registry` (drop the `old entry` row in `sbx-list`, the refusal in `sbx-add` and the Pitfall 7 / Pattern 2 old-entry text). All analog paths below are git-tracked.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `sbx/names.py` | utility (rules) | transform | `bin/sbx-lib.sh` lines 7-17, 77-124 (port) + `base/selfcheck/check_result.py` (style) | port + style |
| `sbx/registry.py` | model/service | file-I/O | `bin/sbx-lib.sh` `read_registry_entry` (port) + `base/selfcheck/check_result.py` (frozen dataclass) | port + style |
| `sbx/overlap.py` | utility | transform | `bin/sbx-add` `locate_dir`, `dir_within`, `tails_overlap`, `paths_overlap` (port) | exact (port) |
| `sbx/docker.py` | service | request-response | `bin/sbx-lib.sh` `run_compose`, `require_*`, `sandbox_is_running` (port); injected-function style from `base/init/init_runner.py` `_take_lock` | port + role-match |
| `sbx/cli.py` | utility | request-response | `bin/sbx-lib.sh` `sbx_error`, `sbx_usage`; `base/init/init_runner.py` `main` | role-match |
| `sbx/add.py start.py stop.py shell.py list_sandboxes.py rm.py upgrade.py fix_modes.py` | controller (command) | request-response | `bin/sbx-<same>` (port); `base/init/init_runner.py` `main(argument_list) -> int` | port + role-match |
| `sbx/migrate_registry.py` | command | batch / file-I/O | `bin/sbx-lib.sh` `read_registry_entry` line parse (old format reader) | partial |
| `sbx/build.py`, `sbx/clean.py` | command | batch | `build.sh`, `clean.sh` (port) | port |
| `sbx/host_test.py`, `sbx/hosttest_names.py` | command / config | streaming | `host-test.sh` (port); no Python tee analog | partial |
| `bin/sbx-*`, `build.sh`, `clean.sh`, `host-test.sh` (launchers) | launcher | request-response | `base/init/sbx-init` (image launcher, thin) | role-match |
| `tests/unit/sbx/conftest.py`, `test_*.py` | test | in-process | `tests/unit/init/test_init_runner.py`, `tests/unit/selfcheck/conftest.py`, `tests/unit/init/init_helpers.py` | exact |
| `tests/guard/*.py` | test (guard) | file scan | `tests/guard/lib.sh` + `isolation.sh` (port rules) ; pytest style from `tests/unit/selfcheck/test_inventory.py` | port + style |
| `tests/integration/conftest.py`, `agent_specs.py`, `sbx_helpers.py`, `test_<scenario>.py` | test (scenario) | event-driven / request-response | `tests/host/lib-sandbox.sh` (`run_timeout`), `lib-sbx.sh` (`run_sbx`), `h*.sh` (steps) | port; no pytest analog |
| `tests/unit/selfcheck/test_inventory.py` (modify) | test | file-I/O | itself, lines 28-35 | exact |
| `pyproject.toml` (modify) | config | config | itself | exact |
| docs (`tests/README.md`, `GLOSSARY.md`, `tests/host-checklist.md`, `README.md`, `MIGRATION.md`) | doc | n/a | their current text | exact |

## Pattern Assignments

### Python module shape (every file under `sbx/`)

**Analog:** `base/init/init_runner.py`

**Header banner, imports, constants** (lines 1-42): title line between 80-dash rules (82 columns with `# `), 1-2 line why, then stdlib imports, then local imports, then `_UPPER` constants.
```python
# ------------------------------------------------------------------------------
# The sbx-init runner: loads the step files, runs them in order and prints
# ------------------------------------------------------------------------------
# Prints one OK or FAIL line per step, and a fix line under each FAIL. ...
# ------------------------------------------------------------------------------

import fcntl
import signal
import sys
from pathlib import Path
...
_USAGE_TEXT = "Usage: sbx-init (no arguments)"
```

**Injected dependency with a real default** (lines 135-149, copy for the Docker function: parameter defaults to the real callable, no monkey-patching):
```python
def _take_lock(lock_file: Path, flock_function: Callable[[TextIO, int], None] = fcntl.flock) -> TextIO | None:
    handle = open(lock_file, "a+")
    try:
        flock_function(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        ...
```

**Thin `main(argument_list) -> int` with usage check first** (lines 233-237; copy for every command, but print `Usage: sbx-add NAME HOST_PATH [claude|cursor]` via a shared `cli` helper, stderr, return 2, before any registry or Docker access):
```python
def main(argument_list: list[str]) -> int:
    if argument_list:
        print(_USAGE_TEXT, file=sys.stderr)

        return 2
```

**Entry banner** (`base/init/sbx-init` lines 32-37):
```python
# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(run())
```
Each `sbx/<cmd>.py` ends this way with `sys.exit(main(sys.argv[1:]))` so `python -m sbx.<cmd>` works and D-04 entry points only add a table row.

**Typed results, not dicts** (`base/selfcheck/check_result.py` lines 21-46): `@dataclass(frozen=True)` for `Entry(name, path, agent)` and `DockerResult(returncode, stdout)`; builders return the dataclass. Raise one `SbxError` type for refusals; the command wrapper prints `<command>: <text>` to stderr and returns 1.

**Style rules to apply:** blank line before and after each `if`/`for`/`try` (visible throughout `init_runner.py`); full names; `_list`/`_map` suffixes; early return; no docstrings.

---

### `sbx/names.py` (utility, transform)

**Analog (port source):** `bin/sbx-lib.sh`

**Constants** (lines 7-17):
```bash
knownAgentList="claude cursor"
knownImageTagList="local test"
nameRulePattern='^[a-z][a-z0-9-]{0,30}$'
nameRuleText='starts with a lowercase letter, then lowercase letters, digits or hyphens, 31 characters at most'
reservedNameList="state best-practices"
```
Port: `KNOWN_AGENT_LIST`, `KNOWN_IMAGE_TAG_LIST`, `NAME_RULE_PATTERN = re.compile(...)`. Use `re.fullmatch` with `re.ASCII` (the bash comment: the whole name must match, so a multi-line name fails; `$` in Python `re.match` would pass a trailing newline).

**Messages to port byte for byte** (lines 78-124): `'NAME' breaks the sandbox name rule: ... Example: my-project.`, `'NAME' is taken: the sandbox directory uses state/ itself. Pick another name.`, `SBX_IMAGE_TAG must be local or test, not 'x'`, and the stderr notice `using the test images because SBX_IMAGE_TAG=test; unset it to use the local images your sandboxes run` (only for non-local tags; unset or empty means `local`). Pass `environ` in as a parameter (D-20).

---

### `sbx/registry.py` (model, file-I/O)

**Analog (port source):** `bin/sbx-lib.sh` `read_registry_entry` lines 126-176, plus `sbx_init` lines 76-87 for the config dir rule.

**Config dir rule** (lines 69-87): `SBX_CONFIG_DIR` else `$HOME/.config/sbx`; refuse empty `HOME` with `HOME and SBX_CONFIG_DIR are both empty; set SBX_CONFIG_DIR to an absolute path`; refuse a relative value with `SBX_CONFIG_DIR must be an absolute path, not '...'`. Registry dir is `<config>/sandboxes`.

**Refusal messages to keep or adapt to JSON** (lines 132-173): `NAME is not registered; run: sbx-add NAME HOST_PATH`, `cannot read FILE`, `the entry FILE has no absolute path`, `the entry FILE names agent 'x'; the known agents are: claude cursor`. Read as data with `json.loads`, never executed (header of `read_registry_entry`: "never sourced").

**Exclusive create** (RESEARCH.md Code Examples, adopt as written): `open(registry_dir / f"{name}.json", "x")` with `json.dumps({"path": ..., "agent": ...}, indent=2) + "\n"`.

**D-07:** `read_entry` knows only `NAME.json`. No old-entry branch. A missing `NAME.json` is "not registered".

---

### `sbx/overlap.py` (utility, transform) -- HOST-03

**Analog (port source):** `bin/sbx-add` lines 58-165 (`locate_dir`, `dir_within`, `tails_overlap`, `paths_overlap`), with header comments carried over (case-insensitive per-segment tail compare, unresolvable counts as overlap).

**Port target:** the verified prototype in `10-RESEARCH.md` Code Examples (lines 485-520): `os.path.realpath`, walk up to the deepest existing dir, `os.path.samefile`, `casefold()` on tails, `except (OSError, ValueError): return True`. Per D-25 `paths_overlap` resolves both paths itself, and `check_host_path` (the textual refusal of empty, `.`, `..` parts, relative path, line break, trailing slash stripped) stays a separate earlier step, ported from `bin/sbx-add` before line 55.

---

### `sbx/docker.py` (service, request-response)

**Analog (port source):** `bin/sbx-lib.sh` lines 211-314.

**Compose call** (line ~218): env set per call, never taken from the caller:
```bash
SBX_NAME="$sandboxName" SBX_DIR="$sandboxDir" SBX_IMAGE_TAG="$imageTag" SBX_AGENT="$entryAgent" docker compose --env-file /dev/null -p "sbx-$sandboxName" -f "$repoDir/compose.yml" "$@" </dev/null
```
Python: a pure `compose_command(entry, name, image_tag, repo_dir, extra_arg_list) -> (arg_list, env_map)` (drop every `COMPOSE_*` key, see `sbx_init` line 89) that unit tests assert on, plus `run_docker(arg_list, env, capture)` as the only subprocess boundary (D-20). `FileNotFoundError` maps to the same refusal as a failed `docker info`: `cannot reach Docker; is Docker running?`.

**Port also:** `require_images` (`... is not built; run: sbx-upgrade NAME (it builds the images and starts the sandbox)`), `sandbox_is_running` (`docker container inspect --format '{{.State.Running}}'`, missing container is false), `runs_older_image` (compare `{{.Image}}` with image `{{.Id}}`, empty id is false), `warn_sessions_close` (`sbx-NAME LEAD will close its open shells and Claude sessions`), `bring_up_sandbox` (dirs check, image check, warning, `up -d --wait`, failure text `docker compose up failed; docker logs sbx-NAME shows why`).

---

### `sbx/start.py`, `stop.py`, `shell.py`, `rm.py`, `upgrade.py`, `list_sandboxes.py`, `fix_modes.py`, `add.py`, `build.py`, `clean.py` (commands)

**Analog:** the same-named bash file; shape from `bin/sbx-stop` lines 1-33.

**Main block order to copy** (`bin/sbx-stop` lines 26-33): usage check first, init (config dir and image tag), name check, read entry, act, then one success line:
```bash
[ "$#" -eq 1 ] || sbx_usage 'NAME'
sbx_init
check_name "$1"
read_registry_entry "$1"
stop_sandbox "$1"
echo "sbx-stop: sbx-$1 is stopped; nothing in $sandboxDir was changed"
```
Python: `main(argument_list, environ=os.environ, docker=run_docker) -> int`; a private function per step; `print` only for the real result lines. Keep refusal order: name, entry, directories, Docker, images (D-20 unit list). Hand-rolled arguments, not argparse (`sbx-upgrade` passes everything after NAME to the build; `sbx-rm` takes `--unregister` and `--yes` in any order, once each). `sbx-shell` ends with an injectable exec. `sbx-list` globs `*.json` only and has no `old entry` row (D-07). `sbx-add` has no old-entry refusal (D-07).

**Delete-data guard (copy intent):** only `rm.py` (and `clean.py` for test runs) may call `shutil.rmtree`, `unlink`, `rmdir`, or Docker verbs `rm`, `down`, `prune`, `kill`, `--volumes`. The guard test scans `sbx/*.py` for them.

---

### `sbx/migrate_registry.py` (command, batch)

**Analog:** `bin/sbx-lib.sh` lines 143-176 (the old reader). Read each old file as text lines `SBX_DIR=` and `SBX_AGENT=`, validate as the new reader does, write `NAME.json` with the exclusive create from `registry.py`, print one line per file, skip when the `.json` exists (rerun is a no-op), leave the old file, exit 1 if any file could not be converted. No old-entry code anywhere else.

---

### Launchers: `bin/sbx-*`, `build.sh`, `clean.sh`, `host-test.sh`

**Analog:** `base/init/sbx-init` (thin, no logic; the logic is in `init_runner.py`). Exact content from RESEARCH.md Pattern 1 (probed):
```sh
#!/bin/sh
exec uv run --directory "$(dirname "$0")/.." --no-project --python 3.12 --quiet python -m sbx.add "$@"
```
`build.sh`, `clean.sh` and `host-test.sh` use `--directory "$(dirname "$0")"`; `host-test.sh` swaps `--no-project` for `--isolated --frozen`. Each needs `chmod +x` and `git update-index --chmod=+x` (MEMORY: sandbox edits drop the exec bit). Two lines exactly (shebang plus one `exec uv run`) so the guard test can assert it. `bin/sbx-lib.sh` is deleted.

---

### `sbx/host_test.py`, `sbx/hosttest_names.py`

**Analog:** `host-test.sh` (261 lines, port the preflight, run directory under `$TMPDIR/sbx-hosttest-<timestamp>`, `--keep`, summary line `N step(s) failed. Log: <path>`). Output pump and uv flags are in RESEARCH.md "Live log" (runs `python -m pytest -v -s -p no:cacheprovider tests/unit/sbx tests/guard tests/integration`, no `-x`, per D-26). No Python analog for the tee; use the 10-line pump from the research. Container names per D-27: `sbx-hosttest-claude`, `sbx-hosttest-cursor`; `clean` names the root certificate directory explicitly (folded todo H-34 c).

---

### `tests/unit/sbx/conftest.py` and `test_*.py` (unit, in-process)

**Analog:** `tests/unit/init/test_init_runner.py` and `tests/unit/selfcheck/conftest.py`.

**Header and imports** (`test_init_runner.py` lines 1-21): banner with what the file covers, stdlib imports, `import pytest`, then local modules imported by plain name (the package dir is on `pythonpath`).

**Fixtures with `tmp_path` and abstract names** (lines 36-51; coding-general rule: numbered names such as `shared1`, `agents1`):
```python
@pytest.fixture
def shared1(tmp_path):
    shared_dir = tmp_path / "shared1"
    shared_dir.mkdir()

    return shared_dir
```
Use the same style for a registry dir fixture and a recorder Docker function (a plain list-appending function passed as the `docker=` parameter; no `patch`, no fake `docker` executable).

**Real process where behavior needs it** (lines 22-27, `HOLDER_TEXT` run by a real second process): for the symlink and `..` overlap cases create real directories and symlinks under `tmp_path`.

**Shared helpers in a uniquely named module** (`tests/unit/init/init_helpers.py` lines 1-17: `REPO_DIR = Path(__file__).resolve().parents[3]`). Name new helpers uniquely (`sbx_helpers.py`); `tests/unit/selfcheck/helpers.py` already exists (RESEARCH Pitfall 1).

**Case lists to carry over:** the old `tests/unit/sbx/*.sh` cases that guard real behavior (name rule, image tag, add refusals, rm option orders, upgrade pass-through, fix-modes with injected `xattr`, list rows from canned `docker ps` text). Cut cases that re-prove the shell.

---

### `tests/guard/*.py`

**Analog (port source):** `tests/guard/lib.sh` and the group files.

**`nowhere_matches` helper** (`lib.sh` lines 28-53): return the list of `path:line:text` hits; fail when the file list is empty ("no file to scan") or unreadable. Python: `nowhere_matches(regex, path_list) -> list[str]`, assert the list is empty.

**Rule shape** (`isolation.sh`, `no_docker_socket_or_privileges`): regex built from a field list, scanned over `compose.yml` and the Dockerfiles; one pytest function per rule, named like the bash function (`test_no_docker_socket_or_privileges`).

**File lists** (`lib.sh` lines 17-23): `SANDBOX_FILES`, `SHELL_FILES`; swap shell files for `sbx/*.py`, `tests/**/*.py`, launchers; `SHELL_FILES` becomes the launchers plus `base/bin/*`, `claude/bin/*`, `cursor/bin/*`. Keep `tests/guard/` out of its own scan lists. New rules: launchers are two lines, `#!/bin/sh`, one `exec uv run` naming an existing module, mode `100755` in `git ls-files -s`; no `.sh` under `tests/` or `bin/` besides launchers; no file named `docker` under `tests/`.

---

### `tests/integration/` (scenario tests, host only)

**No pytest analog exists.** Port from `tests/host/*.sh`; use RESEARCH.md Patterns 4 and 5 and Code Examples for the shapes.

- `step()` helper: RESEARCH.md lines 558-565 (`add_note(f"STEP FAILED: {name}")`), verified against pytest 9.2.0.
- Timeout helper: port `run_timeout` from `tests/host/lib-sandbox.sh` lines 82-120 to the `Popen(start_new_session=True)` plus `os.killpg` sketch in RESEARCH.md lines 538-553.
- Run the real commands against a test registry: port the environment from `tests/host/lib-sbx.sh` line 57 (`SBX_DIR=/nonexistent-ambient SBX_NAME=ambient COMPOSE_PROJECT_NAME=sbx-ambient` ambient values, `SBX_CONFIG_DIR`, `SBX_IMAGE_TAG=test`, `SBX_CA_CERT`).
- `agent_specs.py`: frozen `AgentSpec` rows (state dir, login file, wrapper, binary, selfcheck count 55/53, init step count 4/5, links rules yes/no). No Docker import, so `tests/unit/selfcheck/test_inventory.py` can import it.
- Banner above every scenario and the shared fixture (D-14), schematic line like `plant login, history, caches -> sbx-upgrade -> each file still there`. Header style from `tests/unit/init/test_init_runner.py` lines 1-6.
- Scenario list and old-check sources: D-16 and D-28 tables. `tests/host/support/best-practices/` moves with `git mv` to `tests/integration/support/best-practices/`.
- Name rule: scenario files `test_<scenario>.py`, unique basenames, no `H-nn`, no phase or decision IDs in code.

---

### `tests/unit/selfcheck/test_inventory.py` (modify)

**Current code to change** (lines 28-35): `expected_count` reads `tests/host/h34-selfcheck.sh` by text. Replace the file read with an import from `tests/integration/agent_specs.py` (add `tests/integration` to `pythonpath`). The `*_CHECK_COUNT` constants at lines 24-26 stay.

### `pyproject.toml` (modify)

**Current** (lines 12-15):
```toml
[tool.pytest.ini_options]
testpaths = ["tests/unit/selfcheck", "tests/unit/init"]
pythonpath = ["base/selfcheck", "base/init", "claude/selfcheck/lib", "cursor/selfcheck/lib"]
addopts = "-p no:cacheprovider"
```
Add `tests/unit/sbx` and `tests/guard` to `testpaths` (not `tests/integration`), and `"."` and `"tests/integration"` to `pythonpath`. `dependencies = []` and the pytest pin stay. Update the header comment so it says `./host-test.sh` runs the host suites and a bare `uv run pytest` on the host is forbidden (D-03).

## Shared Patterns

### Error and exit codes
**Source:** `bin/sbx-lib.sh` lines 17-32 (`sbx_error`, `sbx_usage`) and `base/init/init_runner.py` lines 233-247.
Errors on stderr as `<command>: <text>`; usage as one `Usage: <command> ARGS` line, exit 2; failure exit 1; success 0. Raise `SbxError` in helpers; the one `cli.run` wrapper prints and returns.

### Injected boundaries
**Source:** `base/init/init_runner.py` `_take_lock` (lines 135-149) and `base/selfcheck/check_result.py` frozen dataclasses.
Environment map, home or config root, Docker function and the final exec are parameters with real defaults. No monkey-patching, no `unittest.mock.patch` of our own code, no fake docker.

### Banners and comments
**Source:** `base/init/init_runner.py` section banners (lines 21-23, 44-49, 100-102) and `~/.claude/rules/python.md`.
80-dash rule lines, title, optional two-line why; no function banners; no docstrings; ASCII only; no dashes as punctuation; no planning IDs (D-xx, H-nn, HOST-nn, phase numbers) in committed code.

### Style
**Source:** `base/init/init_runner.py` throughout.
Imperative loops, blank line around control flow, early return, `Path` for files, type hints on public functions, `_private` helpers.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `tests/integration/*` pytest scenarios and fixtures | test | scenario / session fixtures | Only bash checks exist (`tests/host/h*.sh`); use RESEARCH.md Patterns 4 and 5 |
| `sbx/host_test.py` output pump | command | streaming | No Python tee exists; RESEARCH.md "Live log" |
| `sbx/docker.py` timeout helper (`run_timeout`) | utility | process control | Only `tests/host/lib-sandbox.sh` bash version; RESEARCH.md sketch |
| `sbx-shell` pty-driven test | test | TTY | Bash version uses BSD `script` (`tests/host/h31-sbx-shell.sh`); RESEARCH.md "Don't Hand-Roll" |

## Metadata

**Analog search scope:** `base/init`, `base/selfcheck`, `tests/unit/{init,selfcheck,sbx}`, `tests/guard`, `tests/host`, `bin`, top-level scripts, `pyproject.toml`
**Files read:** `init_runner.py`, `sbx-init`, `check_result.py`, `pyproject.toml`, `bin/sbx-lib.sh`, `bin/sbx-stop`, `bin/sbx-add` (overlap section), `tests/guard/lib.sh`, `tests/guard/isolation.sh` (head), `tests/unit/init/test_init_runner.py` (head), `tests/unit/init/init_helpers.py` (head), `tests/unit/selfcheck/conftest.py` (head), `test_inventory.py` (head)
**Pattern extraction date:** 2026-11-19
