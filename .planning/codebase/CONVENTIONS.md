---
last_mapped_commit: 031448ea8249fe34f6bd172818ba1c2807eaed35
last_mapped_at: 2026-11-16
---
# Coding Conventions

**Analysis Date:** 2026-11-16

## Naming Patterns

**Files:**
- Shell programs: lowercase with hyphens (`build.sh`, `sbx-add`, `host-test.sh`)
- Shell libraries: lowercase with hyphens ending in `-lib.sh` (`sbx-lib.sh`, `sbx-start-lib.sh`)
- Python modules: lowercase with underscores (`check_result.py`, `image_roots.py`)
- Dockerfiles: named `Dockerfile` (agent-specific files in agent directories: `claude/Dockerfile`, `cursor/Dockerfile`)
- Configuration: lowercase with underscores or hyphens (`.shellcheckrc`, `.hadolint.yaml`, `versions.env`)
- Start hooks: two-digit prefix with dash (`05-gsd`, `10-best-practices`, `02-no-self-update`)

**Functions (shell):**
- Lowercase with underscores: `check_workspace_mount`, `run_start_hooks`, `is_mount`
- Helper functions with leading underscore when private to a module: `_elf_machine`, `_version_problem`
- Main entry point is signaled by `Main / Entry Point` banner comment, not a function name

**Functions (Python):**
- Lowercase with underscores: `make_state_folders`, `cert_fingerprint`, `tool_result`
- Private functions with leading underscore: `_elf_machine`, `_version_matches`, `_native_machine_problem`
- Public functions get type hints on parameters and return

**Variables (shell):**
- Environment variables and exports: UPPERCASE with underscores (`SBX_NAME`, `SBX_CONFIG_DIR`, `DOCKER_HOST`)
- Local variables: lowercase with underscores (`workspace`, `hook`, `configDir`, `groupOutput`)
- Global state marked explicitly: `FAILS=0`, `BUILD_RC`, `SBX_RC` (uppercase; results of last operation)
- Indexed: `knownAgentList`, `knownImageTagList` (bare list of space-separated values)

**Variables (Python):**
- Module-level constants: UPPERCASE with underscores (`ELF_MACHINE_BY_UNAME_MAP`, `_HOME_ROOT`, `_ELF_MAGIC`)
- Local variables: lowercase with underscores
- Type hints on public function parameters and returns

**Types and classes (Python):**
- Classes: PascalCase (`Check`, `CheckResult`)
- Named tuples and dataclasses: PascalCase

## Code Style

**Formatting (Shell):**
- Indentation: 2 or 4 spaces consistently (observed in this codebase; 4-space in `build.sh`)
- Brace style: opening brace on same line as keyword (`if [ ... ]; then`, `for x in ...; do`)
- Multi-line continuation: backslash on Dockerfile; structured statements elsewhere
- Quoting: `"$var"` always for variable expansion (defensive against word splitting)
- No dashes as punctuation; use colons, semicolons, or parentheses instead

**Formatting (Python):**
- Indentation: 4 spaces (PEP 8)
- No bare `except:` blocks; catch specific exceptions or `Exception` at top level only
- Type hints on all public functions
- No monkey-patching; use dependency injection or config overrides

**Formatting (Dockerfile):**
- `FROM` line first, then ARG and ENV, then RUN commands
- RUN commands chain with `&&` to reduce layers
- Cleanup commands (`rm -rf /var/lib/apt/lists/*`) at end of RUN chain
- USER directive near end, after tools installed
- ENTRYPOINT specifies the script; CMD can be overridden

## Import Organization

**Shell:**
- Program: `set -eu` first (or `set -u` for libraries)
- Library sourced first: `. "$(dirname "$0")/lib.sh"` or `. "$(dirname "${BASH_SOURCE[0]}")"/lib.sh"`
- Local script imports come before function definitions
- No relative path imports without defensive subshell; always use `$(cd ... && pwd -P)`

**Python:**
- Standard library imports first
- Third-party imports second
- Local imports last (from project modules)
- Explicit imports only; never `from module import *`
- Sourced via pythonpath in pytest configuration for selfcheck modules

## Section and File Organization

**Shell (programs and libraries):**
- File header banner: purpose as title, usage in optional block below (80-dash rule lines; 82 cols total)
- Library marker comment: "A library: defines variables and functions, runs nothing, sets no options"
- Program marker comment: "A program: runs; nothing sources it" (implicit; marked by `set -e` or `Main / Entry Point` banner)
- Section banners before each logical group: `# --- TEXT ---` (82 cols)
- Optional "why" block under banner, at most 2 lines, closed by a third rule line
- Function banners in libraries: `# name ARGS: what it does` inside the banner
- All functions grouped by topic; related functions adjacent
- `Main / Entry Point` banner before the list of top-level calls
- Example:

```bash
#!/usr/bin/env bash

# ------------------------------------------------------------------------------

# Builds sbx-base, then one image per agent, with the pins in versions.env

# ------------------------------------------------------------------------------

# Usage: ./build.sh [DOCKER_BUILD_OPTION...]

# Extra options go to every build, for example --no-cache.

# With SBX_CA_CERT set to a PEM file, every image also trusts its root

# certificates.

# SBX_IMAGE_TAG picks the tag of all three: local when unset or empty, or test

# for the test run. Any other value stops the build.

# With test, a line on stderr names it before the first build.

# ------------------------------------------------------------------------------

set -eu

# ------------------------------------------------------------------------------

# check_versions_file: stops when versions.env is not next to this script

# ------------------------------------------------------------------------------

check_versions_file() {
  ...
}

# ...

# ------------------------------------------------------------------------------

# Main / Entry Point

# ------------------------------------------------------------------------------

cd "$(dirname "$0")"
scriptName=build.sh
. bin/sbx-lib.sh

# ... calls to functions

```

**Python (modules):**
- File header banner: purpose as title (80-dash rule lines; 82 cols total)
- Optional "why" block under banner, at most 2 lines, closed by a third rule line
- Section banners before logical groups: `# --- TEXT ---` (82 cols)
- Module-level constants after imports, before functions
- Functions grouped by topic; helpers marked private with `_` prefix
- `Main / Entry Point` banner before `if __name__ == "__main__":` block
- Example:

```python

# ------------------------------------------------------------------------------

# Tools on PATH

# ------------------------------------------------------------------------------

# A tool must come from the image, not from a copy under /home, must be built for

# the machine it runs on and must report its pinned version. The image puts this

# file in /usr/local/lib/sbx-selfcheck/.

# ------------------------------------------------------------------------------

import os
import platform
import shutil
from pathlib import Path
from typing import Mapping

from check_result import CheckResult, failed, passed

ELF_MACHINE_BY_UNAME_MAP = {"aarch64": 0xB7, "x86_64": 0x3E}
_HOME_ROOT = "/home"

# ------------------------------------------------------------------------------

# The machine a binary is built for

# ------------------------------------------------------------------------------

def _elf_machine(path: Path) -> int | None:
    ...
```

## Error Handling

**Patterns (shell):**
- Programs use `set -e` to exit on first error; libraries use `set -u` only
- A function that fails reports it and returns non-zero; caller decides whether to stop: `step || exit 1`
- Under `set -e`, a function called with `||` runs without `set -e`; make it return on its own failures: `mkdir -p "$dir" || return 1`
- Fail closed: an input the script cannot use (missing config, invalid name) stops with an error (never skip silently)
- Exit codes: 0 for success, 1 for failure, 2 for usage error
- Error messages print to stderr with label: `sbx_error MESSAGE` sends to stderr with script name prefixed
- Start errors in containers: `start_error MESSAGE` prefixed with `[sbx] ERROR:` and remediation advice
- Guards and tests: failures reported as `FAIL: name` on stdout, counted and summarized

**Patterns (Python):**
- A check function returns a `CheckResult` object with `passed` bool, `detail` string (on success), and `hint` string (on failure)
- Check helpers like `tool_result` take injectable parameters (environment map, home root) for testability
- Errors reported via `failed(problem_text, hint_text)` or `passed(detail_text)` helper functions
- Pytest fixtures handle setup and teardown; test functions focus on assertions
- No bare `except:` blocks; catch specific exceptions

## Logging

**Framework (shell):**
- `echo` for informational output (visible to user)
- `echo "..." >&2` for errors (to stderr)
- Prefixed messages: `"$scriptName: $message"` via helper `sbx_error`
- Guard and test output: `PASS: name` or `FAIL: name` to stdout
- Terse output; avoid logging at debug level in shipped scripts

**Framework (Python):**
- `logging` module for real logging (when needed; this codebase uses minimal logging)
- `print()` only for CLI output that is the real result, not diagnostics
- Check functions return `CheckResult` with `detail` and `hint` strings instead of logging

## Comments

**Conventions (shell and Python):**
- No comments on past changes; `git log` covers that
- No internal IDs (phase numbers, planning file references) in code; external readers lack context
- Forward-looking design context IS fine when it answers "why not the obvious thing"; keep short and self-contained
- `TODO:` is fine for tracked work; prefer `# TODO(<phase/ticket>): <action>` with owner and deadline
- ASCII only in source files; no smart quotes, arrows, ellipses, em or en dashes; use `->`, `...`, plain quotes

## Function Design

**Shell:**
- Size: small; most library functions 5-20 lines
- Split long functions into named helper functions; outer function orchestrates and reads as list of steps
- Early return on edge cases: handle bad input first, return or fail, then main path reads at one indentation
- Preconditions: move validation into the function that needs it, not into every caller
- Overloads: the one with fewer parameters calls the one with more and passes defaults
- Pass structured data via variable names, not nested function calls where possible

**Python:**
- Type hints on all public function signatures
- Small private helpers with leading `_`; keep logic modular
- Dependency injection for testability: pass environment maps, home roots, paths as parameters
- Return typed objects (`CheckResult`, tuples) not bare dictionaries
- Explicit returns; no implicit `None`

## Module Design

**Shell:**
- A file is either a library (defines functions and variables, runs nothing, sets no shell options) or a program (runs; nothing sources it); never both
- A helper goes into a shared library only when two or more scripts use it; otherwise keep it in the one script that needs it
- Libraries are sourced with `set -u` (no set -e so a caller can decide what to do on failure)
- Programs are sourced with `set -eu` and run all steps in order
- Program exit is explicit: `exit 0` on success or `exit 1` / `exit 2` on failure
- Library exit is implicit: functions return non-zero on failure
- Globals exported only when needed for subprocesses: `export SBX_CONFIG_DIR`

**Python:**
- Modules contain business logic; entrypoint stays thin and calls into modules
- Shared setup (fixtures, helpers) in conftest.py; test files hold assertions
- Check functions injected with dependencies (environment maps, paths) for testability
- One module, one topic; split large modules by responsibility
- Explicit exports; no barrel files or `__all__` unless needed

## Arguments

**Shell:**
- Script arguments read first in Main block, same way in every script
- A script without options refuses any argument; usage error prints one `Usage:` line to stderr, caller exits 2
- A script with options reads them in one function with `while`, `case` and `shift` loop
- Early validation: check required arguments first, then proceed with work

**Python:**
- Functions take explicit parameters, no bare `*args` or `**kwargs` (except for fixture adapters in pytest)
- Config via environment variables or JSON files; secrets from environment only

## Refactoring and Symmetry

**Principles:**
- When two things can be implemented the same way, implement them the same way; symmetry lets a maintainer reason about one thing and apply it to its sibling
- If an asymmetry exists, flag it explicitly and justify it by a genuine difference
- Align names across similar things: if `UserService` has `findById`, a sibling `OrderService` gets `findById`, not `getOrder`

## Testing

**Patterns (shell guard tests):**
- A test is a function that returns 0 (pass) or 1 (fail)
- Helper `nowhere_matches REGEX FILE...` returns 0 if no line matches, prints hits
- Helper `report_lines PREFIX` prints each stdin line after PREFIX, returns 1 if any line found
- Test output: `PASS: name` on success, `FAIL: name` on failure, both to stdout
- Exit 0 when all pass, 1 if any failed

**Patterns (shell selftest):**
- Helper `expect NAME COMMAND...` runs the command; prints `PASS: name` on success, `FAIL: name` on failure; increments FAILS
- Helper `equals A B` returns 0 if equal
- Helper `has_text FILE TEXT` returns 0 if FILE contains TEXT
- Helper `lacks_text FILE TEXT` returns 0 if FILE exists, is readable, and does NOT contain TEXT
- Test output: count and summarize: `All cases pass.` or `N case(s) failed.`
- Exit 0 when all pass, 1 if any failed

**Patterns (pytest):**
- Fixtures in conftest.py for shared setup; test functions use them
- Test names follow `test_<what>` pattern
- Assertions use `assert` keyword; pytest introspects and reports failures
- Temporary folders via `tmp_path` fixture; tests clean up automatically
- No monkey-patching; use dependency injection (pass injectable parameters) or config overrides

## Portability

**Shell scripts:**
- Target: macOS (BSD bash 3.2, BSD tools)
- Tests run on Linux (GNU bash, GNU tools) before commit
- Avoid GNU-only options and bash 4 features: no `grep -P`, `readlink -f`, `date -d`, `mapfile`
- In-place edit: `sed "s/old/new/" file > file.tmp && mv file.tmp file`, not `sed -i`
- If `-i` unavoidable: `sed -i.bak` works on both GNU and BSD
- Use POSIX regex where possible; test with BSD tools before commit

**Dockerfile:**
- Base: `ubuntu:latest` (latest stable Ubuntu)
- Tools installed via `apt-get` (Debian/Ubuntu package manager)
- Pinned versions via `versions.env` passed as build args; no floating tags like `:latest`

---

*Convention analysis: 2026-11-16*
