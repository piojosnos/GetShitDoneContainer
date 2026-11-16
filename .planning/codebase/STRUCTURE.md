---
last_mapped_commit: 031448ea8249fe34f6bd172818ba1c2807eaed35
last_mapped_at: 2026-11-16
---
# Codebase Structure

**Analysis Date:** 2026-11-16

## Directory Layout

```
sbx-tools-repo/
├── bin/                          # Host-side shell scripts (macOS)
│   ├── sbx-lib.sh               # Shared functions for all host scripts
│   ├── sbx-add                  # Register a new sandbox
│   ├── sbx-start                # Start a sandbox (docker compose up)
│   ├── sbx-upgrade              # Rebuild images and start
│   ├── sbx-shell                # Open bash in the project folder
│   ├── sbx-list                 # List registered sandboxes
│   ├── sbx-stop                 # Stop a sandbox
│   ├── sbx-rm                   # Remove a sandbox
│   ├── sbx-fix-modes            # Fix file permissions after host edits
│   └── sbx-start                # Alternative start script
│
├── base/                         # Base image (all agents)
│   ├── Dockerfile               # Base image definition
│   ├── sbx-entrypoint           # Container startup script
│   ├── sbx-start-lib.sh         # Startup functions sourced by entrypoint
│   ├── bin/                     # Shared commands in the base image
│   │   ├── sbx-gh-login         # GitHub CLI login helper
│   │   ├── sbx-bundle-clone     # Clone the best-practices bundle
│   │   └── sbx-link-bundle      # Link bundle rules and skills
│   └── selfcheck/               # Self-check validation framework
│       ├── runner.py            # Check runner and loader
│       ├── sbx-selfcheck        # Entry point script
│       ├── *.py                 # Libraries (paths.py, users.py, etc.)
│       └── checks/              # Base checks (shared by all agents)
│           ├── 010_workspace_mount.py
│           ├── 020_project_folder.py
│           ├── 030_state_folders.py
│           ├── 040_root_owned_state.py
│           ├── 050_user.py
│           ├── 060_home_layout.py
│           ├── 070_home_owners.py
│           ├── 080_architecture.py
│           ├── 090_git_safe_directory.py
│           ├── 100_git_identity.py
│           ├── 110_env_state_paths.py
│           ├── 120_env_bundle.py
│           ├── 130_java_home.py
│           ├── 140_tools_plain.py
│           ├── 150_tool_gh.py
│           ├── 160_tool_node.py
│           ├── 170_tool_python.py
│           ├── 180_tool_uv.py
│           ├── 190_tool_java.py
│           ├── 200_tool_maven.py
│           ├── 210_tool_gsd.py
│           ├── 220_tzdata.py
│           ├── 230_versions_record.py
│           ├── 240_versions_line.py
│           ├── 250_wrappers_root_owned.py
│           ├── 260_image_paths_protected.py
│           ├── 270_no_bundle_copy.py
│           └── 280_extra_ca.py
│
├── claude/                       # Claude Code agent image
│   ├── Dockerfile               # Adds Claude Code and ccusage to base
│   ├── managed-settings.json    # Claude Code managed settings
│   ├── bin/                     # Agent-specific commands
│   │   └── sbx-claude           # Claude wrapper script
│   ├── start.d/                 # Agent-specific startup hooks
│   │   ├── 05-gsd               # Syncs GSD into config folder
│   │   └── 10-best-practices    # Links bundle skills
│   └── selfcheck/               # Claude-specific checks and shared libs
│       ├── 010_tool_claude.py
│       ├── 020_tool_ccusage.py
│       ├── 030_env.py
│       ├── 040_home_links.py
│       ├── 050_no_home_copy.py
│       ├── 060_credentials.py
│       ├── 070_gsd_synced.py
│       ├── 080_bundle_links.py
│       ├── 090_managed_settings.py
│       ├── 100_wrappers.py
│       ├── 110_image_paths_protected.py
│       ├── 120_versions_line.py
│       └── lib/
│           └── claude_shared.py # Shared helpers for Claude checks
│
├── cursor/                       # Cursor agent image
│   ├── Dockerfile               # Adds Cursor CLI to base
│   ├── bin/                     # Agent-specific commands
│   │   └── sbx-cursor           # Cursor wrapper script
│   ├── start.d/                 # Agent-specific startup hooks
│   │   ├── 02-no-self-update    # Disables Cursor self-update
│   │   ├── 05-gsd               # Syncs GSD into config folder
│   │   └── 10-best-practices    # Links bundle skills
│   └── selfcheck/               # Cursor-specific checks
│       ├── 010_tool_cursor_agent.py
│       ├── 030_env.py
│       ├── 040_home_links.py
│       ├── 050_self_update_off.py
│       ├── 060_credentials.py
│       ├── 070_gsd_synced.py
│       ├── 080_bundle_links.py
│       ├── 100_wrappers.py
│       ├── 110_image_paths_protected.py
│       ├── 120_versions_line.py
│       └── lib/
│           └── cursor_shared.py # Shared helpers for Cursor checks
│
├── compose.yml                   # Docker Compose template
├── build.sh                      # Build script for all images
├── clean.sh                      # Clean up containers and images
├── host-test.sh                  # Host-side integration tests (macOS)
├── versions.env                  # Pins for every version (build time)
│
├── tests/                        # Test suite
│   ├── README.md                # Test documentation
│   ├── host/                    # Host-side tests (macOS)
│   │   ├── run-all.sh           # Run all host tests
│   │   ├── h*.sh                # Individual test files
│   │   └── lib*.sh              # Helper libraries for tests
│   ├── selftest/                # Self-tests (run in containers)
│   │   ├── sbx/                 # Tests for sbx-* scripts
│   │   ├── entrypoint/          # Tests for container startup
│   │   ├── selfcheck/           # Tests for selfcheck framework (pytest)
│   │   ├── run-all.sh           # Run all self-tests
│   │   └── lib-expect.sh        # Expect library for CLI testing
│   └── guard/                   # Guard checks (CI/lint)
│       ├── run-all.sh
│       ├── linters.sh           # Lint scripts (shellcheck, hadolint)
│       ├── isolation.sh         # Check image isolation
│       ├── supply-chain.sh      # Verify package sources
│       └── start.sh             # Test start procedure
│
├── README.md                     # Main documentation
├── MIGRATION.md                  # Migration from v1 layout
├── ZSCALER.md                    # Proxy/certificate setup
└── .dockerignore                 # Docker build context filter
```

## Directory Purposes

**`bin/` (Host Scripts)**

- Purpose: Manage sandbox lifecycle on the Mac
- Contains: Shell scripts for registration, starting, stopping, and debugging sandboxes
- Key files: `sbx-lib.sh` (shared functions), `sbx-add` (register), `sbx-start` (launch)
- Runs on: macOS (bash 3.2, BSD tools)
- Portability: Must work on macOS; no GNU-specific flags (e.g., `sed -i` uses `-i.bak` format)

**`base/` (Base Image)**

- Purpose: Provides OS, toolchains, and shared infrastructure for all agents
- Contains: Dockerfile, entrypoint script, startup library, selfcheck framework, shared helpers
- Key files: `Dockerfile` (image definition), `sbx-entrypoint` (container startup), `sbx-start-lib.sh` (startup functions)
- Builds to: `sbx-base:local` (or `sbx-base:test`)

**`base/selfcheck/` (Self-Check Framework)**

- Purpose: Validate image state and container setup
- Contains: Python modules for checks; runner that loads and executes them
- Key files: `runner.py` (loader and executor), `sbx-selfcheck` (CLI entry point), `checks/` (40+ check modules)
- Structure: Each check is a numbered `.py` file; `CHECK_LIST` variable holds the checks to run
- Shared Libraries: `*.py` files at root (e.g., `paths.py`, `users.py`, `image_roots.py`) are utilities

**`claude/` and `cursor/` (Agent Images)**

- Purpose: Add agent-specific CLI and startup configuration
- Contains: Dockerfile (inherits from base), agent wrappers, start hooks, agent-specific checks
- Key files: `Dockerfile` (image definition), `start.d/` (startup hooks), `selfcheck/` (agent checks)
- Environment: `CLAUDE_CONFIG_DIR` or `CURSOR_CONFIG_DIR` point to `state/` on the host
- Startup: Hooks in `start.d/` run in name order (e.g., `02-*`, `05-*`, `10-*`)

**`tests/` (Test Suite)**

- Purpose: Verify the system works (host side) and inside containers (self-tests)
- Contains: Host tests (shell scripts on macOS), self-tests (shell + pytest in containers), guard checks (CI)
- Key files: `host/run-all.sh` (run host tests), `selftest/run-all.sh` (run container tests), `guard/run-all.sh` (run lint)
- Patterns: Host tests use `docker compose` commands; self-tests run inside containers; guard checks are CI gates

**`.planning/` (GSD Planning)**

- Purpose: Planning artifacts from GSD phases
- Contains: Phase definitions, state, requirements, and codebase maps
- Note: Excluded from this codebase map (outside scope)

## Key File Locations

**Entry Points**

- `bin/sbx-add`: Register a new sandbox (host; entry point for setup)
- `base/sbx-entrypoint`: Container startup (runs at `docker compose up` and `docker exec`)
- `compose.yml`: Docker Compose template (defines services and mounts)

**Configuration**

- `versions.env`: Pinned versions for all tools (loaded by `build.sh`)
- `compose.yml`: Service definition and environment variables
- `base/sbx-start-lib.sh`: Sandbox name rules and state folder names

**Core Logic**

- `base/Dockerfile`: Base image installation
- `claude/Dockerfile`: Claude image (inherits base)
- `cursor/Dockerfile`: Cursor image (inherits base)
- `build.sh`: Build all images with pinned versions
- `base/sbx-entrypoint`: Container startup validation and hook execution

**Testing**

- `host-test.sh`: Host-side manual test runner
- `tests/host/run-all.sh`: Automated host tests
- `tests/selftest/run-all.sh`: Container self-tests
- `tests/guard/run-all.sh`: Linting and supply-chain checks

**Self-Check**

- `base/selfcheck/runner.py`: Check loader and executor
- `base/selfcheck/sbx-selfcheck`: CLI entry point
- `base/selfcheck/checks/`: 40+ base checks (mounts, folders, tools, versions)
- `claude/selfcheck/`: Claude-specific checks
- `cursor/selfcheck/`: Cursor-specific checks

## Naming Conventions

**Files**

- Shell scripts: lowercase with hyphens (`sbx-add`, `sbx-start-lib.sh`)
- Dockerfiles: exactly `Dockerfile` (no extension or suffix)
- Python modules: lowercase with underscores (`runner.py`, `check_result.py`)
- Check files: numbered prefix (two digits) + description (`010_workspace_mount.py`, `150_tool_gh.py`)
- Start hooks: two-digit prefix + description (`05-gsd`, `10-best-practices`)
- Test files: `h`-prefixed for host tests (`h01-`, `h02-`), `test_*` for pytest

**Directories**

- Lowercase with hyphens: `base`, `claude`, `cursor`, `start.d`, `selfcheck`
- Grouped by function: `bin/` (host scripts), `selfcheck/` (checks), `start.d/` (hooks)

## Where to Add New Code

**New Host Script**

- Location: `bin/sbx-<function>`
- Pattern: Source `bin/sbx-lib.sh`; use functions from it (`sbx_init`, `sbx_error`, etc.)
- Example: `sbx-add`, `sbx-start`

**New Base Check**

- Location: `base/selfcheck/checks/<NNN>_<description>.py`
- Pattern: Define a `CHECK_LIST` containing `Check` objects; import and use helper libraries
- Example: `110_env_state_paths.py`
- Numbering: Use the next available number in sequence; lower numbers run first

**New Agent-Specific Check**

- Location: `claude/selfcheck/<NNN>_<description>.py` or `cursor/selfcheck/<NNN>_<description>.py`
- Pattern: Same as base checks; place shared helpers in `lib/` subfolder
- Example: `010_tool_claude.py` in claude, `010_tool_cursor_agent.py` in cursor

**New Start Hook**

- Location: `<agent>/start.d/<NN>-<description>`
- Pattern: Executable shell script; runs at container startup; failure stops the start
- Order: `02-*` for pre-startup, `05-*` for GSD/bundle, `10-*` for post-startup
- Example: `02-no-self-update` (Cursor), `05-gsd` (both)

**New Host Test**

- Location: `tests/host/h<NN>-<description>.sh`
- Pattern: Source `tests/host/lib.sh` and other helpers; run on macOS
- Example: `h10-missing-folder-refused.sh`

**New Container Self-Test**

- Location: `tests/selftest/sbx/` (sbx-* scripts) or `tests/selftest/entrypoint/` (entrypoint) or `tests/selftest/selfcheck/` (checks)
- Pattern: Shell scripts in `sbx/` or `entrypoint/`; pytest in `selfcheck/`
- Example: `tests/selftest/sbx/add.sh`, `tests/selftest/selfcheck/test_user.py`

**New Build Output/Configuration**

- Location: `versions.env` (for a version pin); `compose.yml` (for a service)
- Pins: All versions go in `versions.env`; no defaults in Dockerfiles
- Example: Add `MYPACKAGE_VERSION=1.2.3` to `versions.env`; then `ARG MYPACKAGE_VERSION` and `RUN : "${MYPACKAGE_VERSION:?...}"` in the Dockerfile

## Special Directories

**`state/` (Host-side, per-sandbox)**

- Purpose: Persist agent login, settings, and caches across container recreates
- Generated: Yes (created by `sbx-add` and start hooks)
- Committed: No (in `.gitignore` if in repo; usually at `$SBX_DIR/state/`)
- Contents: `state/claude`, `state/cursor`, `state/gh`, `state/git`, `state/shell`, `state/cache/npm`, `state/cache/uv`, `state/m2`

**`best-practices/` (Host-side, per-sandbox)**

- Purpose: Clone of the best-practices bundle repository
- Generated: No (cloned by `sbx-bundle-clone` on demand)
- Committed: No (in `.gitignore`)
- Contents: Rules files (`rules/`) and skills (`skills/`)
- Linked: At startup, linked into `state/claude/rules` and `state/claude/skills`

**`.dockerignore`**

- Purpose: Limit what enters the Docker build context
- Contents: Allows only `base/`, `claude/`, `cursor/`, and `versions.env`
- Effect: Keeps the repo's test files, planning docs, and history out of the image layer

**`/etc/sbx/` (Inside container, image-provided)**

- Purpose: Image-provided configuration and runtime metadata
- Contents: `versions.env`, `tool-versions`, `extra-ca.pem` (if proxy), `extra-ca-fingerprints` (if proxy)
- Read-only: Yes (root-owned)

**`/etc/sbx/start.d/` (Inside container, image-provided)**

- Purpose: Agent startup hooks
- Contents: Executable scripts in name order (e.g., `05-gsd`, `10-best-practices`)
- Root-owned: Yes; sandbox user cannot modify

**`/usr/local/lib/sbx-selfcheck/` (Inside container, image-provided)**

- Purpose: Self-check runner and libraries
- Contents: `sbx-selfcheck` (runner), `*.py` (libraries), `checks/` (base checks), `agents/` (agent-specific helpers)
- Read-only: Yes (root-owned)

## Image Path Protection

Paths provided by the image (not the mount) are protected from modification:

- `/usr/local/bin/`: Shared and agent-specific commands (sbx-*, claude, cursor-agent)
- `/usr/local/lib/sbx/`: Entrypoint and startup library
- `/usr/local/lib/sbx-selfcheck/`: Self-check framework
- `/etc/sbx/`: Configuration and pins
- `/opt/java/`, `/opt/maven/`: Toolchains

These are root-owned and read-only to the sandbox user. Attempts to modify them fail with "permission denied".

---

*Structure analysis: 2026-11-16*
