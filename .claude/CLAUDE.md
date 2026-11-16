<!-- GSD:project-start source:PROJECT.md -->

## Project

**GSD Agent Sandbox Containers**

A Docker-based sandbox for running AI coding agents (Claude Code and Cursor today, others later) plus GSD on a macOS laptop without installing those agents on the host. Each project gets its own container that can only see one bind-mounted host folder, so the agent can't touch the rest of the laptop. The code stays a regular folder on the Mac, so any host IDE can open it directly. Small `sbx-*` commands (`sbx-add`, `sbx-start`, `sbx-shell`, `sbx-stop`, `sbx-upgrade`, ...) drive the sandbox lifecycle, and `sbx-selfcheck` inside the image says whether a sandbox is set up right.

**Core Value:** **Rebuilding the image must reliably deliver new or updated tools into a project sandbox without losing the agent's login, settings, or history, and without the host mount hiding anything the image provides.**

### Constraints

- **Security**: Agents never run on the host, and each container sees only its project's mount. Why: this isolation is the reason the project exists.
- **Security**: GSD comes only from `@opengsd/gsd-core`. Never use `get-shit-done-cc` or `gsd-build`. Why: the old package was compromised.
- **Platform**: Must work on macOS + Docker Desktop (likely arm64), with bind mounts. Why: that's the user's only host.
- **Simplicity**: Anything with logic is Python (through `uv` on the host, the image's `python3` inside); shell stays only for thin `exec` wrappers and Dockerfile `RUN` lines. Why: the v1 bash tooling grew about 10.9k lines of test shell around about 2.1k lines of product shell.
- **Toolchains**: JDK 21 LTS, Maven, Node.js, and Python in the shared base. Why: these are the stacks the user develops in.
- **Verification**: Docker isn't available inside the dev sandbox, so plans must include host-side manual verification steps.
- **Coexistence** (retired in Phase 5): the old layout ran side by side with the new one until every old sandbox moved; it is now deleted, and old `cc_` containers left on the Mac are plain stopped containers.

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages

- Bash 3.2+ (POSIX compatible): Shell scripts for container entrypoints, build orchestration, host CLI wrappers, test harnesses; runs on macOS and Linux
- Python 3.12+: Selfcheck framework for validating container setup; tests via pytest
- YAML: Docker Compose service definitions and Dockerfile linting configuration
- Dockerfile: Multi-stage container image definitions for base, Claude agent, and Cursor agent images
- JavaScript/Node.js: Runtime for CLI tools installed via npm; no source code (executables only)

## Runtime

- Docker Engine and Docker Compose: Container orchestration and service definition
- Ubuntu 24.04: Base Linux distribution for all container images; specified by SHA-256 pinned digest in `versions.env`
- npm: JavaScript package manager bundled with Node.js; manages GSD Core, Claude Code, and ccusage CLI tools
- uv: Python package manager and runtime manager; v0.12.21; installed in base image via container copy from official image
- Lockfile: `versions.env` contains all tool version pins; no package-lock.json or similar

## Frameworks

- pytest 9.2.0: Unit testing framework for Python selfcheck modules and integration tests
- uv run pytest: Test runner; configured in `pyproject.toml` with no cache provider
- Docker multi-stage builds: Base image (`sbx-base`) layered with agent-specific configurations (`sbx-claude`, `sbx-cursor`)
- Dockerfile with BuildKit cache mounts: Optional certificate injection during build via bind mounts
- shell linting with shellcheck v0.11.0: Guard tests validate shell script syntax
- Dockerfile linting with hadolint v2.15.1: Guard tests validate Dockerfile correctness

## Key Dependencies

- Node.js 24.21.0: JavaScript runtime for all npm-installed CLIs; downloaded from nodejs.org and verified against SHASUMS256.txt
- GitHub CLI (gh) v2.102.0: Git operations, GitHub API access; downloaded from cli/cli releases and verified against checksums
- Apache Maven 3.9.11: Java project build tool; from Maven Central; note: v3.9.12+ fails on Docker Desktop mounts
- JDK 21 (Temurin) 21.0.12_8: Java runtime; copied from eclipse-temurin:21.0.12_8-jdk-noble image
- @opengsd/gsd-core 1.15.0: GSD CLI framework; installed via npm globally into base image
- uv 0.12.21: Python package manager; copied as binary from official uv image
- shellcheck v0.11.0: Static analysis for shell scripts; copied as binary from official image
- hadolint v2.15.1: Dockerfile linter; copied as binary from official image
- @anthropic-ai/claude-code 2.1.285: Claude Code CLI; installed in `sbx-claude` image only
- ccusage 20.0.26: Usage analytics tool for Claude; installed in `sbx-claude` image only
- cursor-agent 2026.11.11-b912975: Cursor IDE agent CLI; installed in `sbx-cursor` image only
- `get-shit-done-cc`: the old GSD package; never used (it was compromised); GSD comes only from `@opengsd/gsd-core`
- ca-certificates: TLS certificate store; extended with optional custom root certificates
- curl, wget: Download tools for fetching binaries and checksums
- git: Version control; configured with safe.directory='*' for macOS mount compatibility
- jq: JSON processor for parsing and reporting
- ripgrep: Fast file search
- procps, xz-utils, zip, unzip: Utilities for process info, compression, and archive handling
- openssh-client: SSH client for git operations
- make, build-essential: Compilation toolchain for native modules
- less: Pager for command output
- tzdata: Timezone database
- python3, python3-venv, python3-pip: Python runtime and packaging tools

## Configuration

- `versions.env`: Single source of truth for all tool version pins; sourced by `build.sh`; no defaults for any pin
- `.python-version`: Python version hint (3.12) for uv
- `pyproject.toml`: Python project metadata; requires Python 3.12+; pytest configured with testpaths, pythonpath (includes selfcheck modules), and no cache provider
- `.dockerignore`: Files excluded from Docker build context
- `.hadolint.yaml`: Hadolint configuration
- `.shellcheckrc`: Shellcheck configuration for bash linting
- `build.sh`: Main build orchestration; reads `versions.env`, collects pins, optionally injects extra CA certificates, builds three images in sequence
- `Dockerfile` (base): Shared base layer; installs system packages, downloads and verifies all tools, sets up `sandbox` user (UID 1000), creates mount point
- `Dockerfile` (claude): Claude-specific layers; installs Claude Code and ccusage; links home directories to persistent state folders
- `Dockerfile` (cursor): Cursor-specific layers; installs cursor-agent CLI; links home directories to persistent state folders
- `docker-compose.yml`: Service definition; accepts `SBX_NAME`, `SBX_DIR`, `SBX_AGENT`, `SBX_IMAGE_TAG` environment variables; binds single host folder to `/home/sandbox/workspace`
- `sbx-entrypoint` (shell script): Root-owned init script; sources `sbx-start-lib.sh`; runs start hooks in `/etc/sbx/start.d/` in name order; execs CMD
- Start hooks in `/etc/sbx/start.d/`:
- `.initialized` marker file: Idempotency guard; prevents repeated setup of mounted home directory

## Platform Requirements

- macOS or Linux host with Docker Desktop or Docker Engine
- BSD sed and grep (macOS); shell scripts tested on both BSD and GNU variants
- Bash 3.2+ (POSIX compatible)
- Docker image run target: any Docker-capable host with Docker Compose
- CPU architecture support: x86_64 (amd64) and arm64 (detected at build time; handled per tool)
- Minimum memory: 4GB (not enforced; recommended)
- Network access required for: Node.js downloads, Maven Central, npm registry, GitHub, cursor downloads, optional custom CA certificate
- Node version matches `NODE_VERSION` pin
- GSD runtime identity matches `GSD_CORE_VERSION` pin
- GitHub CLI version matches `GH_VERSION` pin
- Maven version matches `MAVEN_VERSION` pin
- Temurin JDK detected in Java version output
- uv and python3 versions printable without error
- shellcheck and hadolint binaries present and runnable
- Mount point `/home/sandbox/workspace` is empty before final RUN (no files leaked from build)

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Naming Patterns

- Shell programs: lowercase with hyphens (`build.sh`, `sbx-add`, `host-test.sh`)
- Shell libraries: lowercase with hyphens ending in `-lib.sh` (`sbx-lib.sh`, `sbx-start-lib.sh`)
- Python modules: lowercase with underscores (`check_result.py`, `image_roots.py`)
- Dockerfiles: named `Dockerfile` (agent-specific files in agent directories: `claude/Dockerfile`, `cursor/Dockerfile`)
- Configuration: lowercase with underscores or hyphens (`.shellcheckrc`, `.hadolint.yaml`, `versions.env`)
- Start hooks: two-digit prefix with dash (`05-gsd`, `10-best-practices`, `02-no-self-update`)
- Lowercase with underscores: `check_workspace_mount`, `run_start_hooks`, `is_mount`
- Helper functions with leading underscore when private to a module: `_elf_machine`, `_version_problem`
- Main entry point is signaled by `Main / Entry Point` banner comment, not a function name
- Lowercase with underscores: `make_state_folders`, `cert_fingerprint`, `tool_result`
- Private functions with leading underscore: `_elf_machine`, `_version_matches`, `_native_machine_problem`
- Public functions get type hints on parameters and return
- Environment variables and exports: UPPERCASE with underscores (`SBX_NAME`, `SBX_CONFIG_DIR`, `DOCKER_HOST`)
- Local variables: lowercase with underscores (`workspace`, `hook`, `configDir`, `groupOutput`)
- Global state marked explicitly: `FAILS=0`, `BUILD_RC`, `SBX_RC` (uppercase; results of last operation)
- Indexed: `knownAgentList`, `knownImageTagList` (bare list of space-separated values)
- Module-level constants: UPPERCASE with underscores (`ELF_MACHINE_BY_UNAME_MAP`, `_HOME_ROOT`, `_ELF_MAGIC`)
- Local variables: lowercase with underscores
- Type hints on public function parameters and returns
- Classes: PascalCase (`Check`, `CheckResult`)
- Named tuples and dataclasses: PascalCase

## Code Style

- Indentation: 2 or 4 spaces consistently (observed in this codebase; 4-space in `build.sh`)
- Brace style: opening brace on same line as keyword (`if [ ... ]; then`, `for x in ...; do`)
- Multi-line continuation: backslash on Dockerfile; structured statements elsewhere
- Quoting: `"$var"` always for variable expansion (defensive against word splitting)
- No dashes as punctuation; use colons, semicolons, or parentheses instead
- Indentation: 4 spaces (PEP 8)
- No bare `except:` blocks; catch specific exceptions or `Exception` at top level only
- Type hints on all public functions
- No monkey-patching; use dependency injection or config overrides
- `FROM` line first, then ARG and ENV, then RUN commands
- RUN commands chain with `&&` to reduce layers
- Cleanup commands (`rm -rf /var/lib/apt/lists/*`) at end of RUN chain
- USER directive near end, after tools installed
- ENTRYPOINT specifies the script; CMD can be overridden

## Import Organization

- Program: `set -eu` first (or `set -u` for libraries)
- Library sourced first: `. "$(dirname "$0")/lib.sh"` or `. "$(dirname "${BASH_SOURCE[0]}")"/lib.sh"`
- Local script imports come before function definitions
- No relative path imports without defensive subshell; always use `$(cd ... && pwd -P)`
- Standard library imports first
- Third-party imports second
- Local imports last (from project modules)
- Explicit imports only; never `from module import *`
- Sourced via pythonpath in pytest configuration for selfcheck modules

## Section and File Organization

- File header banner: purpose as title, usage in optional block below (80-dash rule lines; 82 cols total)
- Library marker comment: "A library: defines variables and functions, runs nothing, sets no options"
- Program marker comment: "A program: runs; nothing sources it" (implicit; marked by `set -e` or `Main / Entry Point` banner)
- Section banners before each logical group: `# --- TEXT ---` (82 cols)
- Optional "why" block under banner, at most 2 lines, closed by a third rule line
- Function banners in libraries: `# name ARGS: what it does` inside the banner
- All functions grouped by topic; related functions adjacent
- `Main / Entry Point` banner before the list of top-level calls
- Example:

#!/usr/bin/env bash
- File header banner: purpose as title (80-dash rule lines; 82 cols total)
- Optional "why" block under banner, at most 2 lines, closed by a third rule line
- Section banners before logical groups: `# --- TEXT ---` (82 cols)
- Module-level constants after imports, before functions
- Functions grouped by topic; helpers marked private with `_` prefix
- `Main / Entry Point` banner before `if __name__ == "__main__":` block
- Example:

## Error Handling

- Programs use `set -e` to exit on first error; libraries use `set -u` only
- A function that fails reports it and returns non-zero; caller decides whether to stop: `step || exit 1`
- Under `set -e`, a function called with `||` runs without `set -e`; make it return on its own failures: `mkdir -p "$dir" || return 1`
- Fail closed: an input the script cannot use (missing config, invalid name) stops with an error (never skip silently)
- Exit codes: 0 for success, 1 for failure, 2 for usage error
- Error messages print to stderr with label: `sbx_error MESSAGE` sends to stderr with script name prefixed
- Start errors in containers: `start_error MESSAGE` prefixed with `[sbx] ERROR:` and remediation advice
- Guards and tests: failures reported as `FAIL: name` on stdout, counted and summarized
- A check function returns a `CheckResult` object with `passed` bool, `detail` string (on success), and `hint` string (on failure)
- Check helpers like `tool_result` take injectable parameters (environment map, home root) for testability
- Errors reported via `failed(problem_text, hint_text)` or `passed(detail_text)` helper functions
- Pytest fixtures handle setup and teardown; test functions focus on assertions
- No bare `except:` blocks; catch specific exceptions

## Logging

- `echo` for informational output (visible to user)
- `echo "..." >&2` for errors (to stderr)
- Prefixed messages: `"$scriptName: $message"` via helper `sbx_error`
- Guard and test output: `PASS: name` or `FAIL: name` to stdout
- Terse output; avoid logging at debug level in shipped scripts
- `logging` module for real logging (when needed; this codebase uses minimal logging)
- `print()` only for CLI output that is the real result, not diagnostics
- Check functions return `CheckResult` with `detail` and `hint` strings instead of logging

## Comments

- No comments on past changes; `git log` covers that
- No internal IDs (phase numbers, planning file references) in code; external readers lack context
- Forward-looking design context IS fine when it answers "why not the obvious thing"; keep short and self-contained
- `TODO:` is fine for tracked work; prefer `# TODO(<phase/ticket>): <action>` with owner and deadline
- ASCII only in source files; no smart quotes, arrows, ellipses, em or en dashes; use `->`, `...`, plain quotes

## Function Design

- Size: small; most library functions 5-20 lines
- Split long functions into named helper functions; outer function orchestrates and reads as list of steps
- Early return on edge cases: handle bad input first, return or fail, then main path reads at one indentation
- Preconditions: move validation into the function that needs it, not into every caller
- Overloads: the one with fewer parameters calls the one with more and passes defaults
- Pass structured data via variable names, not nested function calls where possible
- Type hints on all public function signatures
- Small private helpers with leading `_`; keep logic modular
- Dependency injection for testability: pass environment maps, home roots, paths as parameters
- Return typed objects (`CheckResult`, tuples) not bare dictionaries
- Explicit returns; no implicit `None`

## Module Design

- A file is either a library (defines functions and variables, runs nothing, sets no shell options) or a program (runs; nothing sources it); never both
- A helper goes into a shared library only when two or more scripts use it; otherwise keep it in the one script that needs it
- Libraries are sourced with `set -u` (no set -e so a caller can decide what to do on failure)
- Programs are sourced with `set -eu` and run all steps in order
- Program exit is explicit: `exit 0` on success or `exit 1` / `exit 2` on failure
- Library exit is implicit: functions return non-zero on failure
- Globals exported only when needed for subprocesses: `export SBX_CONFIG_DIR`
- Modules contain business logic; entrypoint stays thin and calls into modules
- Shared setup (fixtures, helpers) in conftest.py; test files hold assertions
- Check functions injected with dependencies (environment maps, paths) for testability
- One module, one topic; split large modules by responsibility
- Explicit exports; no barrel files or `__all__` unless needed

## Arguments

- Script arguments read first in Main block, same way in every script
- A script without options refuses any argument; usage error prints one `Usage:` line to stderr, caller exits 2
- A script with options reads them in one function with `while`, `case` and `shift` loop
- Early validation: check required arguments first, then proceed with work
- Functions take explicit parameters, no bare `*args` or `**kwargs` (except for fixture adapters in pytest)
- Config via environment variables or JSON files; secrets from environment only

## Refactoring and Symmetry

- When two things can be implemented the same way, implement them the same way; symmetry lets a maintainer reason about one thing and apply it to its sibling
- If an asymmetry exists, flag it explicitly and justify it by a genuine difference
- Align names across similar things: if `UserService` has `findById`, a sibling `OrderService` gets `findById`, not `getOrder`

## Testing

- A test is a function that returns 0 (pass) or 1 (fail)
- Helper `nowhere_matches REGEX FILE...` returns 0 if no line matches, prints hits
- Helper `report_lines PREFIX` prints each stdin line after PREFIX, returns 1 if any line found
- Test output: `PASS: name` on success, `FAIL: name` on failure, both to stdout
- Exit 0 when all pass, 1 if any failed
- Helper `expect NAME COMMAND...` runs the command; prints `PASS: name` on success, `FAIL: name` on failure; increments FAILS
- Helper `equals A B` returns 0 if equal
- Helper `has_text FILE TEXT` returns 0 if FILE contains TEXT
- Helper `lacks_text FILE TEXT` returns 0 if FILE exists, is readable, and does NOT contain TEXT
- Test output: count and summarize: `All cases pass.` or `N case(s) failed.`
- Exit 0 when all pass, 1 if any failed
- Fixtures in conftest.py for shared setup; test functions use them
- Test names follow `test_<what>` pattern
- Assertions use `assert` keyword; pytest introspects and reports failures
- Temporary folders via `tmp_path` fixture; tests clean up automatically
- No monkey-patching; use dependency injection (pass injectable parameters) or config overrides

## Portability

- Target: macOS (BSD bash 3.2, BSD tools)
- Tests run on Linux (GNU bash, GNU tools) before commit
- Avoid GNU-only options and bash 4 features: no `grep -P`, `readlink -f`, `date -d`, `mapfile`
- In-place edit: `sed "s/old/new/" file > file.tmp && mv file.tmp file`, not `sed -i`
- If `-i` unavoidable: `sed -i.bak` works on both GNU and BSD
- Use POSIX regex where possible; test with BSD tools before commit
- Base: `ubuntu:latest` (latest stable Ubuntu)
- Tools installed via `apt-get` (Debian/Ubuntu package manager)
- Pinned versions via `versions.env` passed as build args; no floating tags like `:latest`

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Host Scripts | Register sandboxes, manage lifecycle (start, stop, upgrade); invoke Docker Compose | `bin/sbx-add`, `bin/sbx-start`, etc. |
| Registry | Store sandbox metadata (host path, agent type) outside every mount | `~/.config/sbx/sandboxes/<name>` |
| Compose Template | Define container service, mount point, image, entrypoint | `compose.yml` |
| Base Image | OS packages, toolchains, GSD, shared commands, selfcheck framework | `base/Dockerfile` |
| Agent Images | Agent-specific CLI, wrappers, start hooks, checks | `claude/Dockerfile`, `cursor/Dockerfile` |
| Entrypoint | Validate mount and state folders, run hooks, enter project folder | `base/sbx-entrypoint` |
| Start Hooks | Agent-specific setup (sync GSD, link skills, disable self-update) | `*/start.d/*` |
| Selfcheck | Validate image state, tools, mounts, ownership before operation | `base/selfcheck/runner.py` and `checks/` |

## Pattern Overview

- Isolation: one container, one project folder, no cross-sandbox access
- Reproducibility: pinned toolchain versions in `versions.env`; smoke tests at build time verify all pins
- Idempotency: start hooks are reentrant; existing state folders and configs are reused
- Validation: entrypoint checks mount, folders and sandbox name before running hooks; selfcheck validates image state
- Composition: base image includes GSD and shared helpers; agent images add their CLI and checks

## Layers

- Purpose: Provides operating system, toolchains, GSD, and shared infrastructure
- Location: `base/Dockerfile` builds `sbx-base:local`
- Contains: Ubuntu 24.04, Node.js, Python, JDK 21, Maven, uv, git, gh, GSD, sbx-selfcheck framework
- Depends on: Official Docker images (Ubuntu, Temurin, Node, Python)
- Used by: `sbx-claude:local` and `sbx-cursor:local`
- Key State: `/etc/sbx/versions.env` (pins), `/etc/sbx/tool-versions` (display line), `/etc/sbx/start.d/` (hook folder)
- Purpose: Adds agent-specific CLI and configuration
- Location: Builds `sbx-claude:local` (Claude) or `sbx-cursor:local` (Cursor)
- Contains: Claude Code or Cursor CLI, agent-specific start hooks, managed settings, agent checks
- Depends on: `sbx-base:local`
- Used by: Containers running the agent
- Key State: Environment variables for agent config directory, start hooks in `/etc/sbx/start.d/`
- Purpose: Validates state and runs the agent
- Location: Launched from `compose.yml` by host scripts
- Contains: Mounted project folder, mounted state folders (caches, login, git identity)
- Depends on: Agent image
- Used by: Developer and GSD execution
- Key Flow: entrypoint validation, hook execution, agent CLI
- Purpose: Track sandbox registrations and provide CLI for sandbox operations
- Location: Registry in `~/.config/sbx/sandboxes/`; scripts in `bin/`
- Contains: Per-sandbox metadata (folder path, agent type)
- Depends on: Installed Docker Desktop, `compose.yml`, agent images
- Used by: Developer running `sbx-*` commands

## Data Flow

### Sandbox Registration and First Start

### Container Startup

### Agent Operation

### Container Validation (sbx-selfcheck)

## Key Abstractions

- Purpose: Isolates one project and one agent session
- Examples: `~/.config/sbx/sandboxes/demo` (registry), `/Users/you/sbx-demo/` (host folder), `sbx-demo` (container)
- Pattern: Registry entry + host folders + container instance; name rules prevent collisions
- Purpose: Binds the host project folder into the container without hiding image contents
- Examples: `$SBX_DIR` on Mac; `/home/sandbox/workspace` in container
- Pattern: `compose.yml` uses `create_host_path: false` to fail fast if the folder is missing
- Purpose: Preserve agent login, settings, caches, and history across container recreates
- Examples: `state/claude`, `state/gh`, `state/shell`, `state/cache/npm`, `state/m2`
- Pattern: Created at startup by `create_state_dirs`; persisted on the host under `state/`; environment variables direct tools to use them
- Purpose: Run agent-specific setup tasks atomically at container start
- Examples: `05-gsd` syncs GSD; `10-best-practices` links skills
- Pattern: Executable shell scripts in `/etc/sbx/start.d/` run in name order; failure stops the start
- Purpose: Validate image state and container setup before the agent operates
- Examples: Check tool versions, mount point, ownership, environment variables
- Pattern: Python modules in `base/selfcheck/checks/` and agent-specific `*/selfcheck/` define `CHECK_LIST`; runner collects and runs them
- Purpose: Persist sandbox metadata outside the project folder
- Examples: `SBX_DIR=/Users/you/sbx-demo`, `SBX_AGENT=claude`
- Pattern: One file per sandbox in `~/.config/sbx/sandboxes/<name>`; sourced by host scripts

## Entry Points

- `sbx-add`: Registers a new sandbox; validates name and paths; creates folders; writes registry entry
- `sbx-start`: Starts a sandbox (docker compose up) without rebuilding images
- `sbx-upgrade`: Rebuilds images and starts the sandbox
- `sbx-shell`: Execs a bash shell into the running container at the project folder
- `sbx-list`: Lists all registered sandboxes
- `sbx-stop`, `sbx-rm`: Stop and remove containers
- Entrypoint: `base/sbx-entrypoint` validates mount and state, runs start hooks, then execs the user command
- Start hooks: Located in `/etc/sbx/start.d/`, run in name order (e.g., `05-gsd`, `10-best-practices`)
- Agent CLI: `claude` or `cursor-agent` (not managed by sbx; the agent runs as a subprocess)
- Selfcheck: `sbx-selfcheck` validates the image and container state

## Architectural Constraints

- **One mount**: Entire `/home/sandbox/workspace` is mounted; no nested mounts or subtree separations
- **Sandbox name rule**: Names start with a lowercase letter, then lowercase, digits or hyphens, 31 chars max (`^[a-z][a-z0-9-]{0,30}$`). Prevents Docker naming errors and sandbox folder collisions
- **Reserved names**: `state` and `best-practices` are reserved; a sandbox cannot use them as its project name
- **No root access**: The container runs the unprivileged `sandbox` user; image files are root-owned and immutable
- **Immutable image paths**: Image-provided binaries in `/usr/local/bin` and libraries are read-only to the sandbox user
- **Non-interactive entrypoint**: Start hooks must succeed or the container fails to start; no interactive recovery
- **Pins are not defaults**: Every version in `versions.env` must be provided; `build.sh` stops without them
- **Registry outside mounts**: Registry in `~/.config/sbx/` prevents a sandbox from rewriting its own entry
- **No state pollution**: Start hooks are idempotent; rerunning them does not create duplicates or corrupt existing state

## Anti-Patterns

### Baking Mutable State into the Image

### Storing Secrets in the Dockerfile or Environment

### Hard-Coding the Agent Type into the Base Image

### Mounting the Home Directory Directly

## Error Handling

- Mount point must be mounted; failing here means the developer used `docker run` directly instead of `docker compose up`
- Sandbox name must follow the rule; failing here prevents name collisions and Docker compose errors
- Project and state folders must exist; failing here indicates a missing or mistyped path or a broken registry entry
- State directories are created; failures here stop the start (permission issue with the mount)
- Hooks run in sequence; the first failure stops the start and is reported on stderr
- A missing hook file is silently skipped; only regular executable files run
- Each hook exit code is checked; a non-zero exit stops the start
- Hook output is not captured; stdout and stderr go to the container log for debugging
- Smoke tests at build time verify every version pin (node version, GSD version, etc.)
- Version mismatches cause build failure; the image is not produced
- Missing versions are named in the error; `versions.env` must provide them
- Syntax errors in Python files (selfcheck checks) cause build failure
- Errors are printed to stderr with `[sbx] ERROR:` prefix
- Exit code is 1; the container does not start
- Developer sees the error in `docker compose up` output or `docker logs sbx-<name>`
- Remediation hints are in the error message (e.g., "rebuild the images" or "check the mount")

## Cross-Cutting Concerns

- Container startup: Errors go to stderr via `echo ... >&2` in the entrypoint and start hooks
- Selfcheck: Results are printed to stdout (PASS/FAIL per check); remediation hints follow failures
- Image builds: Verbose output from curl, tar, compilation tools; layer cache hits are shown
- History: Bash history is saved to `state/shell/bash_history` across sessions
- `SBX_NAME`: Set by `compose.yml` from the `--name` Docker Compose project name
- `SBX_DIR`: Set by host scripts; passed to `compose.yml`; binds the mount point
- `SBX_AGENT`: Set by host scripts (defaults to `claude`); selects the image (`sbx-claude` or `sbx-cursor`)
- `SBX_IMAGE_TAG`: Defaults to `local`; `test` is used for test images; any other value is refused
- Tool-specific: `CLAUDE_CONFIG_DIR`, `CURSOR_CONFIG_DIR`, `GH_CONFIG_DIR`, etc.; all point into `state/`
- No capabilities in the container; `cap_drop: ALL`
- Non-root user; `sandbox` uid 1000
- Image binaries are root-owned, immutable by the sandbox user
- Mount is read-write; the sandbox user can read and write project files
- Registry outside every mount; the sandbox user cannot modify its own registration
- Repos behind a proxy trust the proxy's root certificate (if `SBX_CA_CERT` is set); this is configurable per build

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
