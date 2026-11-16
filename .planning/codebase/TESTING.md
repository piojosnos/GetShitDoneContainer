---
last_mapped_commit: 031448ea8249fe34f6bd172818ba1c2807eaed35
last_mapped_at: 2026-11-16
---
# Testing Patterns

**Analysis Date:** 2026-11-16

## Test Framework

**Test suites:**
- Guard rules: bash scripts checking files statically
- Self-test entrypoint: bash scripts testing start hooks and initialization
- Self-test sbx: bash scripts testing host scripts without Docker
- Self-test selfcheck: pytest tests of the image self-check modules
- Host tests: bash scripts running on Mac with Docker, testing real images and behavior

**Runner (shell tests):**
- Guard: `bash tests/guard/run-all.sh` (exit 0 = all rules hold)
- Self-test entrypoint: `bash tests/selftest/entrypoint/run-all.sh` (exit 0 = all pass)
- Self-test sbx: `bash tests/selftest/sbx/run-all.sh` (exit 0 = all pass)
- Host tests: `bash tests/host/run-all.sh` (exit 0 = all pass)
- Full host suite with image build: `./host-test.sh` (on Mac with Docker)

**Runner (Python tests):**
- `uv run pytest tests/selftest/selfcheck` (exit 0 = all pass)
- Config: `pyproject.toml` with pythonpath to selfcheck modules

## Test File Organization

**Location (shell):**
- Guard rules: `tests/guard/*.sh` (one group per rule topic)
- Self-test entrypoint: `tests/selftest/entrypoint/*.sh`
- Self-test sbx: `tests/selftest/sbx/*.sh`
- Host tests: `tests/host/h*.sh` (H-03 to H-34 with number prefix)
- Shared helpers: `tests/host/lib.sh`, `tests/host/lib-*.sh`, `tests/selftest/lib-*.sh`

**Location (Python):**
- Tests: `tests/selftest/selfcheck/test_*.py`
- Fixtures and helpers: `tests/selftest/selfcheck/conftest.py`
- Helpers module: `tests/selftest/selfcheck/helpers.py` (not part of pytest discovery)

**Naming (shell):**
- Programs: `*.sh` (runnable with `bash`)
- Libraries: `lib*.sh` (sourced, not run directly)
- Groups in guard: `supply-chain.sh`, `start.sh`, `isolation.sh`, etc. (one `.sh` file per group topic)
- Groups in selftest suites: named by feature tested (`image-tag.sh`, `entry.sh`, `rm.sh`)
- Host tests: prefixed with `h` and padded number (`h09-rebuild-keeps-files-no-volumes.sh`, `h16-live-clone-and-restart.sh`)

**Naming (Python):**
- Test modules: `test_<topic>.py` (e.g. `test_tools_plain.py`, `test_state_folders.py`)
- Check modules being tested: agent names match test prefix (e.g. `test_claude_env.py` tests `claude/selfcheck/030_env.py`)

## Test Structure

**Guard test suite (static checks):**

```bash
#!/usr/bin/env bash

# --- PURPOSE ---

# Usage: bash tests/guard/RULE_GROUP.sh (exit 0 = every rule holds)

# --- /PURPOSE ---

set -u
. "$(dirname "$0")/lib.sh"

# --- RULE 1 NAME: explains what it checks

# [Optional] why text if needed

# --- /RULE 1 NAME

rule_1_name() {
  # boolean function: return 0 (pass) or 1 (fail)
  # print failures via `echo` or helper `report_lines`
  ...
}

# --- Main / Entry Point

require_no_arguments "$@" || exit 2
run_rules rule_1_name rule_2_name ... || exit 1
```

- Helper `run_rules RULE...` calls each rule, prints `PASS: rule` or `FAIL: rule`, exits 1 if any failed
- Helper `nowhere_matches REGEX FILE...` returns 0 if no match, prints all hits if any found
- Helper `report_lines PREFIX` reads stdin lines, prints each after PREFIX, returns 1 if any line seen

**Self-test (bash, with work folder and cases):**

```bash
#!/usr/bin/env bash

# --- PURPOSE ---

# Usage: bash tests/selftest/sbx/NAME.sh (exit 0 = all pass)

# --- /PURPOSE ---

set -u
. "$(dirname "$0")/lib.sh"

# --- CASE: what this case tests

case_something() {
  echo "--- what this case does"
  
  # use expect, equals, has_text, lacks_text helpers
  expect "assertion name" condition_command_or_function
  expect "another name" [ "$X" = "$Y" ]
  expect "file check" has_text "$file" "search text"
}

# --- Main / Entry Point

require_no_arguments "$@" || exit 2
start_group || exit 1
case_something
case_another
finish_cases
```

- Helper `expect NAME COMMAND...` runs command; `PASS: name` on success, `FAIL: name` on failure; increments FAILS
- Helper `equals A B` returns 0 if A equals B; used with expect
- Helper `has_text FILE TEXT` returns 0 if FILE contains TEXT
- Helper `lacks_text FILE TEXT` returns 0 if FILE exists, readable, and lacks TEXT
- Helper `finish_cases` prints summary and exits 0 (all pass) or 1 (any failed)
- Helper `start_group` enters repo root, makes temp WORK folder, unsets env vars, points Docker at nonexistent socket

**Self-test entrypoint (bash, real scripts):**
- Runs real `base/sbx-start-lib.sh`, `base/sbx-entrypoint`, `base/bin/sbx-link-bundle`, and start hooks in a temp folder with fake GSD
- Uses same case and expect pattern as sbx self-tests

**Host tests (bash, real Docker):**
- Builds throwaway images, mounts volumes, runs containers, verifies behavior
- Each test (H-03, H-04, etc.) is a standalone program returning 0 (pass) or 1 (fail)
- Summary printed by runner: `PASS: h03-...` or `FAIL: h03-...` with test output if failed

**Pytest tests (Python selfcheck modules):**

```python

# --- PURPOSE ---

# Tests of [module or check]

# --- /PURPOSE ---

import pytest

from check_result import Check, CheckResult
from helpers import load_shared_check

module_being_tested = load_shared_check("NNN_module_name")

# --- Constants and helpers

# ...

# --- TOPIC

# Functions related to one check or behavior

def test_X():
    # Arrange
    data = ...
    
    # Act
    result = module_being_tested.function_being_tested(data, ...)
    
    # Assert
    assert result.passed
    assert result.detail == "..."

def test_Y():
    result = module_being_tested.function_being_tested(bad_data)
    
    assert not result.passed
    assert "problem" in result.detail
    assert result.hint

# --- Main / Entry Point

# (pytest finds and runs test_* functions automatically)

```

- One test module per selfcheck module or topic (e.g. `test_tools_plain.py` for `140_tools_plain.py`)
- Fixtures in `conftest.py` provide temp paths, certificate generation, file mode restoration
- Tests use `tmp_path` fixture for temporary files; cleanup is automatic
- No monkeypatching; tests pass injectable parameters (environment map, home root, paths)
- Check functions return `CheckResult` objects with `passed`, `detail`, `hint` attributes

## Mocking

**Framework (shell):**
- No mocking; tests use real files, real commands, temp folders
- Docker socket mocked by setting `DOCKER_HOST=unix:///nonexistent` so scripts hit an error before running
- Registry folder redirected via `SBX_CONFIG_DIR=$WORK/cfg` so tests do not touch the host registry
- Fake GSD created as minimal folder structure in temp workspace for entrypoint tests

**Framework (Python):**
- No monkeypatching or unittest.mock.patch; use dependency injection
- Check functions accept environment maps, home paths, and other dependencies as parameters
- Tests pass injectable fake data (temp paths, temp files) instead of patching
- For OS checks: use `skipif` decorator for platform-specific tests (e.g. `@pytest.mark.skipif(os.getuid() == 0, reason="...")`)

**What to Mock:**
- Shell: external services behind Docker (tests use a nonexistent socket)
- Python: file system state (temp paths), environment (temp env maps, injectable parameters)

**What NOT to Mock:**
- Real tools on PATH (git, openssl, keytool, jq, etc.); assert they exist and work
- Real filesystem operations (mkdir, chmod, resolve paths); test behavior on real paths
- Real command output; assert it matches expected format and content

## Fixtures and Factories

**Test Data (shell):**
- Temp folder: `make_work_folder PREFIX` creates and traps cleanup at EXIT
- Registry entry: `plant_entry NAME [LINE...]` writes to `SBX_CONFIG_DIR/sandboxes/NAME`
- Example:

```bash
start_group || exit 1
SBX_CONFIG_DIR=$WORK/cfg
export SBX_CONFIG_DIR

plant_entry entry1 "SBX_DIR=/x/one" "SBX_AGENT=cursor"
expect "entry1 works" run_sbx label sbx-add entry1 "$WORK/path/one"
```

**Test Data (Python):**
- Temp path: `tmp_path` fixture from pytest (created, isolated per test, cleaned automatically)
- Certificate generation: `make_certificate(name)` fixture creates self-signed PEM (key removed)
- File mode restoration: `restorable_mode` fixture tracks chmod calls and restores on teardown
- Example:

```python
def test_X(tmp_path, make_certificate):
    cert_file = make_certificate("test-cert")
    state_dir = tmp_path / "state"
    
    result = check_function(state_dir)
    assert result.passed
```

- Helper `write_versions(path)` creates a fake `versions.env` file
- Helper `load_shared_check(name)` imports a check module (e.g. "140_tools_plain")
- Helper `agent_checks_dir(agent_name)` returns the path to agent selfcheck directory

## Coverage

**Requirements:** No explicit coverage target enforced in CI (no CI exists yet)

**View Coverage (Python):**
- pytest has coverage support but is not configured in this project
- To add: install `pytest-cov` and run `uv run pytest --cov=tests/selftest/selfcheck tests/selftest/selfcheck`

## Test Types

**Unit Tests (Python selfcheck modules):**
- Scope: individual check functions and their helpers
- Approach: pass fixtures (temp paths, temp files, injectable parameters), call check function, assert result
- Examples: `test_tools_plain.py` tests each tool check; `test_state_folders.py` tests folder existence and permissions

**Static Rule Tests (shell guards):**
- Scope: file content and structure (no execution)
- Approach: read files with grep, check patterns, report all hits
- Examples: supply chain rules check for GSD package, pin formats, pipe-to-shell installs
- What they catch: unpinned versions, floating tags, compromised packages, lint errors, missing files, configuration drift

**Integration Tests (host tests and entrypoint tests):**
- Scope: multiple components working together (entrypoint tests the whole start sequence; host tests build real images)
- Approach: set up test data, run scripts or build images, verify output and side effects
- Examples: H-06 tests git clone and restart together; entrypoint tests GSD sync and bundle links in one sequence
- What they catch: broken start sequences, lost files, mounts not working, bundle links stale

**End-to-End Tests (host tests only):**
- Scope: full lifecycle of a sandbox (create, start, use, list, stop, remove)
- Approach: build test images, run Docker Compose, execute operations, verify final state
- Examples: H-08 tests that history survives recreate; H-09 tests rebuild with volumes off loses history
- What they catch: data loss, mount issues, compose configuration problems

## Common Patterns

**Assertion Patterns (shell):**

```bash

# True/false condition

expect "assertion name" [ "$X" = "$Y" ]

# Command success/failure

expect "assertion name" command_that_should_succeed

# File contains text

expect "assertion name" has_text "$file" "search text"

# File does NOT contain text (file must exist and be readable)

expect "assertion name" lacks_text "$file" "excluded text"

# Variables equal

expect "name" equals "$actual" "$expected"

# Custom function

my_check() {
  # ... logic ...
  [ "$result" = "expected" ]  # returns 0 or 1
}
expect "name" my_check
```

**Error Testing (Python):**

```python
def test_check_fails_with_missing_file(tmp_path):
    result = check_function(tmp_path / "nonexistent")
    
    assert not result.passed
    assert "nonexistent" in result.detail or "missing" in result.detail
    assert result.hint  # hint should explain how to fix

def test_check_passes_with_valid_state(tmp_path):
    state_dir = tmp_path / "state"
    state_dir.mkdir()
    
    result = check_function(state_dir)
    
    assert result.passed
```

**Async Testing:**
- Not used in this codebase; tests are synchronous

**Temporary File Handling (Python):**

```python
def test_with_temp_file(tmp_path):
    test_file = tmp_path / "test.txt"
    test_file.write_text("content")
    
    result = process_file(test_file)
    
    # test_file and tmp_path are cleaned up automatically
    assert result.passed
```

**Temporary File Handling (shell):**

```bash
make_work_folder mytest || exit 1

# WORK is set to temp folder; EXIT trap cleans it up

echo "test data" > "$WORK/file.txt"
expect "process file" has_text "$WORK/file.txt" "test data"

# At exit, $WORK is removed automatically

```

## Running Tests

**From the Mac host:**
- Build and run all tests: `./host-test.sh` (builds test images, runs guards, entrypoint, sbx, and host tests; writes to `host-test.log`)
- Keep test images after failure: `./host-test.sh --keep`
- Guard rules only: `bash tests/guard/run-all.sh` (works without Docker)

**From a sandbox (Linux):**
- Guard rules: `bash tests/guard/run-all.sh`
- Entrypoint self-tests: `bash tests/selftest/entrypoint/run-all.sh`
- Sbx self-tests: `bash tests/selftest/sbx/run-all.sh`
- Selfcheck pytest tests: `uv run pytest tests/selftest/selfcheck`

**Individual test groups:**
- Guard: `bash tests/guard/supply-chain.sh`
- Sbx selftest: `bash tests/selftest/sbx/image-tag.sh`
- Host: `bash tests/host/h06-git-on-mac-repo.sh`
- Pytest: `uv run pytest tests/selftest/selfcheck/test_tools_plain.py`

## Test Execution Flow

**Guard rules (static file checks):**
1. Enter repo root
2. Read Dockerfile, docker-compose.yml, versions.env, shell scripts
3. Check each rule: lines match patterns, files exist, content is consistent
4. Print `PASS: rule` or `FAIL: rule` to stdout
5. Exit 0 (all pass) or 1 (any fail)

**Entrypoint self-tests (start sequence in temp folder):**
1. Enter repo root
2. Create temp WORK folder
3. Create fake GSD and fake host workspace structure
4. Source `base/sbx-start-lib.sh`
5. Run each start hook with fake environment
6. Verify GSD synced, bundle linked, state folders created
7. Print `PASS: case` or `FAIL: case`
8. Clean up WORK folder
9. Exit 0 (all pass) or 1 (any fail)

**Sbx self-tests (host scripts without Docker):**
1. Enter repo root
2. Create temp WORK folder
3. Set `DOCKER_HOST=unix:///nonexistent` (no real daemon reached)
4. Set `SBX_CONFIG_DIR=$WORK/cfg` (test registry)
5. Source `bin/sbx-lib.sh` and test functions
6. Run each case (create entries, call sbx-* scripts, check output)
7. Verify refusal of invalid input, correct registry entries, correct error codes
8. Print `PASS: case` or `FAIL: case`
9. Clean up WORK folder
10. Exit 0 (all pass) or 1 (any fail)

**Host tests (real Docker):**
1. Build test images (sbx-base:test, sbx-claude:test, sbx-cursor:test)
2. For each test (H-03, H-04, etc.):
   - Set up test data (volumes, compose project, files)
   - Run Docker Compose or sbx-* script
   - Verify output, file state, container state
   - Tear down (remove containers, clear volumes if needed)
3. Print `PASS: h03-...` or `FAIL: h03-...`
4. Exit 0 (all pass) or 1 (any fail)

**Pytest selfcheck tests:**
1. Load pythonpath (base/selfcheck, agent/selfcheck/lib)
2. For each test function:
   - Set up fixtures (temp paths, certificates)
   - Call check function with test data
   - Assert result.passed or result.detail contains expected text
   - Teardown removes temp data
3. Print summary (passed, failed, skipped counts)
4. Exit 0 (all pass) or 1 (any fail)

---

*Testing analysis: 2026-11-16*
