# Phase 10: Host side to Python - Research

**Researched:** 2026-11-19
**Domain:** Porting a bash host toolchain (`bin/sbx-*`, `build.sh`, `clean.sh`, `host-test.sh`, bash test suites) to stdlib-only Python run through `uv`, plus a pytest rewrite of every host suite
**Confidence:** HIGH on the inventory, the `uv` launcher and the porting design (read in this session, probed in the dev sandbox); MEDIUM on macOS-only behavior (cannot run Docker or macOS here, so the host run is the proof)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**How a command runs**
- **D-01:** All host logic lives in one Python package (`sbx/`, stdlib only at runtime). Keeping the small commands (`sbx-start`, `sbx-stop`, `sbx-shell`) in bash is rejected: their logic is in `bin/sbx-lib.sh` (name rule, registry, image tag, Docker checks), and a split would keep that logic twice, in two languages.
- **D-02:** Each `bin/sbx-*`, `build.sh` and `host-test.sh` is the same two-line launcher: it runs `uv` on `python -m sbx.<command> "$@"`. No logic in the launcher. The PATH setup and the command names stay; nothing is installed.
- **D-03:** The Mac's uv environment lives outside the repo. The repo's `.venv/` belongs to the dev sandbox (Linux) and the Mac sees it through the mount; the two must never share it.
- **D-04:** Each command module has a `main()`, so a later switch to `[project.scripts]` entry points installed with `uv tool install --editable .` only adds those entries and deletes the launchers. Not done now: the user wants real use to show a reason first.
- **D-05:** Anything with real logic (branches, loops) is Python: `bin/`, `build.sh`, `host-test.sh`, `clean.sh`, `sbx-fix-modes`, `tests/guard/`, `tests/unit/sbx/`, `tests/host/`. Shell stays only for the agent wrappers and the launchers.

**Registry**
- **D-06:** `sbx-add` writes `~/.config/sbx/sandboxes/NAME.json` with `path` and `agent`; every other command reads it.
- **D-07:** A one-off `sbx-migrate-registry` converts every old `KEY=value` entry (`SBX_DIR`, `SBX_AGENT`) to `NAME.json` and prints what it did. Until it runs, the other commands refuse a sandbox that has only an old entry and name the command. It leaves the old files in place (only `sbx-rm` deletes data); `MIGRATION.md` says they can be deleted. The command is deleted in a later milestone. **Reversibility:** reversible: one file and one refusal path.

**Test runner**
- **D-08:** Every suite runs under pytest (the pinned 9.2.0), not hand-rolled PASS/FAIL scripts. A full run never uses `-x`: every scenario runs, and the summary lists every failure.
- **D-09:** `./host-test.sh` stays the one command and runs everything: unit, guard and integration. All output goes to `host-test.log` with pytest's `-v` per-test lines, and live output from long steps is visible in the log. This reverses Phase 8 D-18 ("host-test.sh does not run pytest").

**Integration tests are scenario based**
- **D-10:** One test function is one end-to-end scenario. Its steps run in code order; the first failed step ends that scenario and the failure names the step (a small `step("...")` helper). This rule is stated once in `tests/README.md` and must be obvious in the code.
- **D-11:** A check that does not belong to a scenario's story goes into its own scenario. Unrelated checks are never mixed into one scenario.
- **D-12:** Scenarios never depend on each other. Today's 10-check chain in `tests/host/run-all.sh` (one failure marks the rest NOT RUN) goes. Order between scenarios does not matter; no ordering plugin.
- **D-13:** The test sandbox is a shared resource, made explicit: one fixture guarantees a known state at the start of each scenario (running, init done). A scenario that upgrades, recreates or removes the sandbox leaves it in that known state, or the fixture restores it. The fixture also removes every container it starts.
- **D-14:** Every scenario and the shared fixture have a banner header in the project style: a title line and 1 to 3 schematic lines saying what it does (for example `plant login, history, caches -> sbx-upgrade -> each file still there`).
- **D-15:** Every scenario runs for both agents (Claude and Cursor) through one parametrized harness; only a few small checks differ per agent (success criterion 6).

**Which host checks survive**
- **D-16:** Scenarios, mapped from today's checks:

  | Scenario | From |
  |---|---|
  | Persistence: planted files survive one `sbx-upgrade` | H-08, H-09, H-23, H-29 |
  | Refusal | H-10, bad names from H-03 |
  | Smoke: add, start, stop, shell, list, rm; git on a repo made on the host | H-28, H-31, H-32, H-33, H-06 |
  | Isolation: one bind mount, no privileges | H-26 |
  | First run and relink: refusal, init, clone, push, relink after a pull | H-27, H-16 |
  | Init and selfcheck pass | H-34 |
  | Init gives root-owned state back | H-35 (owner part only) |
  | Images match `versions.env` | H-25 (version part only) |

- **D-17:** Dropped: H-03's "variables reach compose" (smoke and isolation fail when a variable is wrong); H-35's lock part (`tests/unit/init` already tests it with a real second process). H-25's "a bare build is refused" moves to a unit test (no Docker needed).
- **D-18:** The plan carries a table mapping every step of every old check to its new test, or to "dropped, because ...". Review checks it before the bash goes.
- **D-19:** Success criterion 4 and HOST-04 are amended to list the scenarios of D-16; criterion 5 reads "no host logic in bash; launchers only"; criterion 1 says the commands are two-line launchers into Python run through `uv`.

**Unit tests**
- **D-20:** `tests/unit/sbx/` becomes pytest unit tests that call the Python functions in-process: the name rule, registry read and write, the path overlap check through symlinks and `..` (HOST-03), the image tag, argument parsing, the migration. Docker sits behind one small function passed in as a parameter; no fake docker, no monkey-patching.

**Names**
- **D-21:** The real-Docker suite is `tests/integration/`. `tests/README.md` and `GLOSSARY.md` say it runs only on the host, the fact the old name carried.
- **D-22:** The H-nn IDs go; scenario names and step names replace them. `tests/host-checklist.md` shrinks to what cannot live in code: the manual Cursor login check and how to read `host-test.log`.
- **D-23:** `./host-test.sh` and `host-test.log` keep their names.

### Claude's Discretion
- Package location and module names (`sbx/` at the repo root or under a folder), and the launcher's exact uv flags.
- Where the Mac's uv environment lives (D-03), as long as it is outside the repo.
- The `step()` helper's shape and how pytest output is fed live into `host-test.log`.
- How the guard rules are grouped into pytest files; which guard rules lose their point once bash is gone (for example shellcheck now covers only the wrappers and launchers).
- How the shared fixture detects and restores the known state.
- Doc updates: `README.md`, `MIGRATION.md`, `tests/README.md`, `GLOSSARY.md`, `tests/host-checklist.md`, `.claude/CLAUDE.md` stack notes.

### Deferred Ideas (OUT OF SCOPE)
- Switch the `sbx-*` commands to an installed tool (`uv tool install --editable .` with `[project.scripts]`) once real use gives a reason (D-04).
- Delete `sbx-migrate-registry` once every sandbox has moved (D-07).
- Reviewed todos not folded: `2026-10-24-bundle-clone-error-hint-and-option-guard.md`, `2026-10-26-sbx-gh-login-skip-when-logged-in.md` (in-image commands), `2026-11-08-limit-token-exposure-in-bypass-mode.md`, `2026-11-14-mac-run-glue-script.md`, `2026-11-18-host-portability-and-macos-wording.md`, `2026-11-08-migration-recipe-follow-ups.md`, `2026-11-08-refresh-claude-md-for-the-new-layout.md`, `2026-11-15-recurring-test-audit.md`.

### Folded todos (in scope)
- H-34 host check hygiene: (a) planted state left behind is solved by the fixture (D-13); (c) the Python `clean.sh` names the certificate directory explicitly, not by the `sbx-hosttest-*` glob. (b) closed, not done.
- Selfcheck review follow-ups: (d) the selfcheck scenario checks the whole output and count, not one grep; (e) the fixture removes every container it starts. (a) to (c) closed, not done.
- Test duplication cleanup: part (d) only (the bash helpers it would merge are deleted).
- Test suite names: decided by D-20 to D-23.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HOST-01 | `bin/sbx-*`, `build.sh` and `host-test.sh` are Python run through `uv` (`brew install uv` is the only prerequisite on a macOS host); command names stay | Launcher shape probed and working (`uv run --directory ... --no-project --python 3.12 -q python -m sbx.X`); module map in "Recommended Project Structure"; uv fetches Python 3.12 itself, so no other prerequisite, but a proxy root needs `UV_SYSTEM_CERTS` (Pitfall 3) |
| HOST-02 | The registry is one JSON file per sandbox, `~/.config/sbx/sandboxes/NAME.json`, with `path` and `agent` | Registry module design, atomic exclusive create with `open(..., "x")`, read-as-data rules, old-entry refusal and `sbx-migrate-registry` (Pattern 2, Runtime State Inventory) |
| HOST-03 | The directory-overlap check resolves both paths and compares them | Prototype of `paths_overlap` run in the dev sandbox against symlink, `..`, holds, inside and text-prefix cases (Code Examples); macOS case rules kept (Pitfall 6) |
| HOST-04 | pytest suite: persistence group, refusal group, smoke tests; a group stops at its first failure and names the step (amended by D-19 to the D-16 scenarios) | Scenario harness design, `step()` helper verified against pytest 9.2.0 output, old-check to new-scenario map (D-18 draft), sandbox fixture design |
| HOST-05 | The bash host scripts, bash host tests and the last of the fake docker are gone | File-by-file inventory with fate (port, delete, move), guard rule port table, guard rule that no host shell file is more than a launcher |
</phase_requirements>

## Project Constraints (from CLAUDE.md and the user's rules)

Follow these in every new Python file; the planner should copy the relevant ones into plan acceptance checks.

- **Python style** [VERIFIED: .claude/CLAUDE.md "Conventions"]: 4-space indent; type hints on all public functions; no bare `except:`; no monkey-patching, use dependency injection (pass `environ`, paths, the Docker function); explicit returns; early return; small functions; file header banner (title line, 80 dashes, optional 1 to 3 lines); section banners `# ---...--- / # TEXT / # ---...---` at 82 columns; `Main / Entry Point` banner before the `if __name__ == "__main__":` block; module constants after imports; private helpers with a leading `_`; Classes PascalCase; collection names carry a shape suffix (`entry_list`, `agent_by_name_map`).
- **Comments and IDs**: no comments about past changes; no phase, decision or H-nn IDs in committed code, tests, fixtures or READMEs (the user's rule, D-22 retires the H-nn IDs); ASCII only in source files; no dashes as punctuation in any prose or comment (`--` only as literal CLI flag text).
- **Control flow** [VERIFIED: coding-general.md]: imperative `if`/`for`/`while` over comprehension chains; blank line before and after every `for`/`while`/`if`/`try` block; composition over inheritance (an `AgentSpec` dataclass of data, not subclasses); full variable names; no doc-comments (docstrings) unless asked.
- **Messages and exit codes** [VERIFIED: bin/sbx-lib.sh]: errors on stderr as `<command>: <text>`; exit 0, 1 or 2 (2 only for usage, one `Usage: <command> ARGS` line on stderr). Existing wording is pinned by docs and tests; port it byte for byte except where the JSON registry changes the sentence.
- **Tests**: a bug fix starts with a failing test; real infrastructure over mocks (Docker is the one external boundary, injected as a function); each test from a clean state; fixtures committed; test file names unique across suites (pytest `prepend` import mode, no `__init__.py`).
- **Docker is not available in the dev sandbox**: everything that needs Docker or macOS is proven by `./host-test.sh` on the host, so the plan needs a human-verify checkpoint per Docker-dependent wave (config has `human_verify_mode: end-of-phase`).
- **PR hygiene** [VERIFIED: MEMORY.md "separate-prs-for-planning-and-claude"]: code, `.planning/` and `.claude/` never share a branch or PR. This phase touches all three (code, ROADMAP/REQUIREMENTS amendments per D-19, `.claude/CLAUDE.md` stack notes), so plan three PRs. Branch from updated `main`, no AI attribution in commits, explicit staging, push only with the user's go, the user merges.
- **Exec bits**: sandbox edits leave new files at 644 on the host [VERIFIED: MEMORY.md "sandbox-edits-drop-exec-bit-on-mac"]. Every new launcher (including `bin/sbx-migrate-registry`) needs `chmod +x` and `git update-index --chmod=+x`; add a guard rule that asserts launcher modes in the git index.
- **GLOSSARY** [VERIFIED: .claude/CLAUDE.md "Vocabulary"]: code and docs use `GLOSSARY.md` terms. The glossary currently defines "launcher" as the Python entry file of `sbx-init` and `sbx-selfcheck` and says an agent wrapper differs from a launcher. D-02 uses "launcher" for the two-line shell files in `bin/`. The plan must update the glossary and pick distinct wording (Open Question 8).
- Security: `security_enforcement` is `false` in `.planning/config.json`, so the ASVS section is omitted. The security-relevant behavior that stays (registry values read as data, never executed; overlap refusals fail closed; only `sbx-rm` deletes data) is covered in Pitfalls and Validation.

## Summary

The host side today is about 8,900 lines across 11 command files, one 314-line library, 17 host check scripts with 8 helper libraries, 11 bash unit harnesses, 5 bash guard files, and three top-level scripts (`build.sh`, `clean.sh`, `host-test.sh`). Almost everything is a faithful port: the rules (name pattern, reserved names, image tags, error wording, exit codes) are small and already reviewed. The real design work is in four places: (1) the launcher and where uv keeps its environment, (2) the JSON registry and its migration, (3) the injected Docker function that lets unit tests run in-process with no fake docker, and (4) the scenario harness that replaces a 10-link bash chain with independent, per-agent pytest scenarios over a shared sandbox fixture.

The uv question has a clean answer that makes D-03 almost free. Host commands have no dependencies, so the launcher can run them with `uv run --no-project`: uv creates no project environment at all, so nothing can touch the shared `.venv/`. The test launcher needs pytest, and `uv run --isolated --frozen` builds a throwaway environment in uv's cache (outside the repo) from the existing `uv.lock`, about 0.9 s overhead after the first run; I verified both in the dev sandbox. `--directory` makes the launcher independent of the caller's directory and puts the repo root on `sys.path` as an absolute path, so `python -m sbx.add` works with no install. uv spawns the Python process as a child (it does not `exec`), which matters only for `sbx-shell` TTY and signal behavior, to be proven on the host.

Today's host checks are Claude-only in most places (H-09, H-16, H-27 use `state/claude` and `sbx-claude`), with Cursor appearing only in H-34. D-15 makes every scenario run for both agents, so the plan needs an `AgentSpec` data table (state directory, login file, wrapper, binary, selfcheck count, init step count, whether rules are linked) and it must be the single home of the counts that `tests/unit/selfcheck/test_inventory.py` currently reads out of `tests/host/h34-selfcheck.sh` by text. The old chain's habit of taking the shared sandbox down, registering the same name on a different directory and restoring it goes away if the shared sandbox is created by the real `sbx-add` and `sbx-start` against a test registry, which also makes `sbx-upgrade`, `sbx-stop` and `sbx-rm` scenarios possible on it directly.

**Primary recommendation:** One stdlib-only `sbx/` package at the repo root; two-line `/bin/sh` launchers using `uv run --directory <repo> --no-project --python 3.12 --quiet python -m sbx.<cmd>` (and `--isolated --frozen` without `--no-project` for `host-test.sh`); hand-rolled argument checks (not argparse) to keep the pinned `Usage:` lines; Docker behind a small injected function; per-agent `AgentSpec`; the shared sandbox fixture built from the real commands; every Docker call through one timeout helper that kills the process group.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Name rule, agent list, image tag rule | Python package (`sbx/`) | none | One definition read by every command and by `build` (today `bin/sbx-lib.sh` read by `build.sh`) |
| Registry read and write | Python package | Host filesystem (`~/.config/sbx/sandboxes/NAME.json`) | Registry sits outside every mount so a sandbox cannot rewrite its entry |
| Directory overlap check | Python package | Host filesystem (resolves symlinks, inodes) | Needs real filesystem resolution, not text comparison |
| Compose and image calls | Docker engine via one injected function | Python package builds the argument lists and env | Keeps unit tests in-process; Docker behavior is proven only by integration scenarios |
| Command launch (`bin/sbx-*`, `build.sh`, `host-test.sh`) | Shell launcher (two lines) | uv | PATH setup and command names stay; no logic in shell |
| Test sandbox state (running, init done) | Integration fixture | Docker engine | The one place that knows how to detect and restore the known state |
| Per-agent differences | Data table (`AgentSpec`) | none | Shared scenarios stay agent-neutral; a third agent is one more row |
| Test output to `host-test.log` | `sbx/host_test.py` (runs pytest, tees) | pytest `-v` | One command, one log, live output |
| Linters (shellcheck, hadolint) on the host | Guard rule via `docker run` of `sbx-base:test` | dev sandbox native binaries | The host has neither tool; the image has both |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python stdlib | 3.12 (`.python-version`, `requires-python >=3.12`) | All host logic: `json`, `pathlib`, `os`, `subprocess`, `shutil`, `re`, `dataclasses`, `contextlib`, `tempfile`, `pty` | D-01: stdlib only at runtime; 3.12 matches the dev sandbox and image |
| uv | 0.12.21 in the image; the host installs whatever `brew install uv` gives | Runs every command and the test suite | D-02; probed here: `uv 0.12.21 (aarch64-unknown-linux-musl)` [VERIFIED: `uv --version` in this session] |
| pytest | 9.2.0 | Every suite (unit, guard, integration) | Already pinned in `pyproject.toml`: `dev = ["pytest==9.2.0"]` and in `uv.lock` [VERIFIED: pyproject.toml:8] |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `docker` / `docker compose` CLI | host's Docker Desktop (Compose v2 or newer required) | Run via the injected function only | Every container, image and compose call |
| `openssl` | host's (LibreSSL on macOS) | Validate and print certificates in `build`, make the throwaway root in the test harness | `SBX_CA_CERT` handling and test root; keep, do not replace with `ssl` (Don't Hand-Roll) |
| `git` | host's | `sbx-fix-modes` (`ls-files -s -z`), fixture repos | Real git, as in the bash |
| `xattr` | macOS built-in | `sbx-fix-modes` attribute read and write | macOS only; Python's `os.getxattr` is not available on macOS, so keep the CLI behind an injected function |
| `shellcheck`, `hadolint` | from `sbx-base:test` on the host, native in the dev sandbox | Guard linter rules | Host runs them with `docker run --rm -v "$PWD:$PWD:ro"` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `uv run --no-project` for commands | `uv run --project <repo>` with `UV_PROJECT_ENVIRONMENT` outside the repo | Works (verified) but needs an env location and creates a persistent venv for a package with no dependencies |
| `--isolated` for `host-test.sh` | `UV_PROJECT_ENVIRONMENT=$HOME/.cache/sbx/venv` | Persistent env is faster by about 0.8 s per run but is one more path to name, document and clean; `--isolated` needs no location |
| argparse | hand-rolled length checks | argparse prints `usage: prog ...` in its own format and rejects `sbx-upgrade NAME --no-cache`; the repo pins `Usage: sbx-add NAME HOST_PATH [claude|cursor]` in tests and docs. Hand-roll (recommended) |
| `hashlib` + `ssl.PEM_cert_to_DER_cert` for fingerprints | `openssl x509 -fingerprint` | The stdlib route does not validate the certificate (it only base64-decodes), so "not a valid certificate" refusal would need openssl anyway. Keep openssl |
| In-process `build.main()` from `sbx-upgrade` | spawn the `build.sh` launcher | In-process is testable with the injected Docker function and avoids a second uv start; the "failed build leaves the sandbox alone" behavior is the return value |

**Installation:** nothing new. `pyproject.toml` stays `dependencies = []` with the same dev pin. Host: `brew install uv` (the only prerequisite).

**Version verification:** `uv.lock` already pins pytest 9.2.0 and the isolated env resolved it here: `9.2.0` printed by `uv run --isolated --frozen --project . python -c "import pytest; print(pytest.__version__)"` [VERIFIED: probe in this session].

## Package Legitimacy Audit

This phase installs no new package. pytest is already pinned and locked since Phase 8.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| pytest | PyPI | many years (latest release 2026-10-27) | not reported by the seam | github.com/pytest-dev/pytest | SUS (reasons `too-new`, `unknown-downloads`) | Already installed and locked; the flag only reflects that the latest release is recent and PyPI download counts are not available to the seam. No new install, so no `checkpoint:human-verify` task |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** pytest (existing pin, heuristic noise; see A7)

## Architecture Patterns

### System Architecture Diagram

```text
 user shell (macOS host)
   |  sbx-add / sbx-start / ... / build.sh / host-test.sh        (PATH -> repo bin/)
   v
 launcher (/bin/sh, 2 lines)  exec uv run --directory <repo> --no-project ... python -m sbx.<cmd> "$@"
   v
 sbx.<cmd>.main(argv, docker=run_docker, environ=os.environ) -> exit code
   |-- rules:      name rule, agent list, image tag      (sbx.names)
   |-- registry:   read NAME.json / write exclusively / detect old entry   (sbx.registry)
   |                  ~/.config/sbx/sandboxes/NAME.json   (outside every mount)
   |-- overlap:    resolve both paths -> samefile + case-insensitive tail   (sbx.overlap)
   |-- docker fn:  run(args, env, capture|inherit) --> docker / docker compose  (sbx.docker)
   |                  compose env set per call: SBX_NAME, SBX_DIR, SBX_AGENT, SBX_IMAGE_TAG
   +-- build:      versions.env text -> --build-arg NAME=value, optional SBX_CA_CERT banner

 ./host-test.sh -> uv run --isolated --frozen ... python -m sbx.host_test
   v
 pytest -v (one process): tests/unit/sbx -> tests/guard -> tests/integration
   |  tests/unit/sbx    in-process, docker function = recorder, tmp_path registry   (no Docker)
   |  tests/guard       reads repo files; linters via `docker run sbx-base:test` when absent
   |  tests/integration session fixtures: preflight -> run dir -> test root cert -> best-practices origin
   |                    -> build test images (SBX_IMAGE_TAG=test) -> per-agent sandbox (sbx-add, sbx-start, sbx-init)
   |                    scenario = one test function x 2 agents; step("...") names the first failing step
   v
 host-test.log (tee of the pytest stream) ; exit code = pytest's
```

### Recommended Project Structure

```text
sbx/                       # stdlib-only package, repo root (outside .dockerignore's allow list, so never in an image)
  __init__.py
  names.py                 # name rule, reserved names, known agents, image tag rule, image name
  registry.py              # Entry dataclass; read, write (exclusive), list, old-entry detection
  overlap.py               # check_host_path, locate_dir, paths_overlap
  docker.py                # DockerResult, run_docker (the injected function), compose env, require_docker, state queries
  cli.py                   # SbxError, UsageError, report, run(main) wrapper, shared warn text
  add.py start.py stop.py shell.py list.py rm.py upgrade.py fix_modes.py migrate_registry.py
  build.py clean.py host_test.py
  hosttest_names.py        # run dir prefix, root cert dir, test sandbox name prefix: one place for host_test, clean and the fixtures
bin/                       # launchers only: sbx-add sbx-start sbx-stop sbx-shell sbx-list sbx-rm sbx-upgrade sbx-fix-modes sbx-migrate-registry
build.sh clean.sh host-test.sh      # launchers
tests/unit/sbx/            # pytest, in-process
tests/guard/               # pytest files replacing the five bash groups
tests/integration/         # was tests/host/; conftest.py, agent_specs.py, harness modules, test_<scenario>.py, support/best-practices/
tests/README.md  tests/host-checklist.md (shrunk)
```

Module names are Claude's discretion (CONTEXT). One naming trap: a module called `list` is legal (`python -m sbx.list` works) but never write `from sbx import list`, which shadows the builtin. A neutral name such as `sbx/list_sandboxes.py` is safer; if the module is named `list`, import it only as `import sbx.list as list_command`.

### Pattern 1: The launcher (two lines, verified)

`bin/sbx-add`:

```sh
#!/bin/sh
exec uv run --directory "$(dirname "$0")/.." --no-project --python 3.12 --quiet python -m sbx.add "$@"
```

`build.sh`, `clean.sh` and `host-test.sh` sit at the repo root, so they use `--directory "$(dirname "$0")"`. `host-test.sh` needs pytest, so it replaces `--no-project` with `--isolated --frozen`:

```sh
#!/bin/sh
exec uv run --directory "$(dirname "$0")" --isolated --frozen --quiet python -m sbx.host_test "$@"
```

Verified in the dev sandbox [VERIFIED: probes this session]: from three different caller directories and via PATH the launcher printed `sys.path[0]` and cwd as the absolute repo path, passed `"a b"` and `c` through as two arguments, and propagated exit code 3. `--no-project` created no `.venv`. `uv run --isolated --frozen --project .` printed `9.2.0`, left `.venv` untouched (same mtime before and after) and `git status` clean, at about 0.85 s per call on a warm cache.

Consequences to design for:
- `--directory` changes the working directory, so the caller's cwd is lost. No command takes a relative path (`sbx-add` refuses one textually, `SBX_CA_CERT` must be absolute), so this is safe; state it in `tests/README.md`.
- uv starts Python as a child process (`getppid()` named `uv` in the probe), it does not `exec`. Interactive `sbx-shell` therefore has uv as a parent; Ctrl-C and window resize reach `docker exec` through the shared foreground process group. Prove on the host (Open Question 9).
- On first use uv downloads a managed Python 3.12 (macOS ships 3.9), so the first run needs network. Behind a TLS proxy set `UV_SYSTEM_CERTS=true` [CITED: docs.astral.sh/uv/reference/environment/]; document in `ZSCALER.md`.
- Set `PYTHONDONTWRITEBYTECODE=1` only if the planner wants no `__pycache__` in `sbx/` on the mount (the directory is already git-ignored). Optional.

### Pattern 2: Registry as data, one JSON file per sandbox

- File `NAME.json` under `SBX_CONFIG_DIR/sandboxes` (default `~/.config/sbx`, absolute, same rule as `sbx_init` today: refuse empty `HOME` and a relative `SBX_CONFIG_DIR`). Content `{"path": "<absolute>", "agent": "claude"}`, written with `json.dumps(..., indent=2)` plus newline.
- Create with `open(path, "x")` (O_EXCL): the same "second `sbx-add` of one name at the same time is refused" guarantee the bash got from noclobber.
- Read with `json.loads`; require a dict with a string absolute `path` and an `agent` in the known list; anything else is a "broken entry" with a specific message. Nothing in the file is ever executed or interpolated into a shell string [VERIFIED: bin/sbx-lib.sh:143-144 comment: "The file is read line by line as text and never sourced"]. Ignore unknown extra keys (room for later fields) but never act on them.
- A name has no dot (`^[a-z][a-z0-9-]{0,30}$`), so `demo` (old entry) and `demo.json` (new) can never collide and the file stem is the name.
- Old entry detection: a regular file in the registry directory with no `.json` suffix. `read_entry(name)`: if `NAME.json` is missing and `NAME` exists, raise a refusal that names `sbx-migrate-registry`. `sbx-add` must refuse while any old entry exists (otherwise its overlap scan silently ignores unmigrated sandboxes and fails open); `sbx-list` shows such a name as a row (`old entry`) with the hint, symmetric to the existing `broken entry` row.
- `sbx-migrate-registry`: for each old file, parse `SBX_DIR=` and `SBX_AGENT=` lines as text, validate as the reader does, write `NAME.json` exclusively (skip with a printed line when it already exists, so a rerun is a no-op), print one line per file, leave the old file, exit 1 when any file could not be converted. It is a command with a launcher in `bin/` like the others.

### Pattern 3: Docker behind one injected function

One small function type, passed as a keyword parameter with `run_docker` as the default, so no test needs a fake `docker` executable and no code is monkey-patched (D-20).

```python
# design sketch [ASSUMED: shape is a recommendation, not read from the repo]
@dataclass(frozen=True)
class DockerResult:
    returncode: int
    stdout: str

Docker = Callable[[Sequence[str], Mapping[str, str] | None, bool], DockerResult]  # args, env, capture
```

- `run_docker` maps `FileNotFoundError` (no `docker` binary, which is the dev sandbox case) to the same "cannot reach Docker; is Docker running?" refusal as a failing `docker info`. [VERIFIED: `which docker` returned `docker: command not found` in this session.]
- Compose environment is built from scratch for each call: `SBX_NAME`, `SBX_DIR`, `SBX_AGENT`, `SBX_IMAGE_TAG` set from the registry and the checked tag, every `COMPOSE_*` variable dropped, `--env-file /dev/null -p sbx-NAME -f <repo>/compose.yml`, stdin closed [VERIFIED: bin/sbx-lib.sh:96 and :218]. A unit test on the pure function that builds this argument list and env replaces the guard greps in `tests/guard/start.sh` (`SBX_AGENT="$entryAgent" docker compose`, `SBX_IMAGE_TAG="$imageTag"`, `for agent in $knownAgentList; do`).
- `sbx-shell` ends with `os.execvp("docker", ["docker", "exec", "-it", "-w", ..., "sbx-NAME", "bash"])` after flushing; make the final exec injectable (a `replace` mode on the same function) so the unit test can assert the arguments and stop. The behavior itself is an integration step.
- Interactive and long calls (`compose up`, `docker build`, `docker exec -it`) inherit stdout and stderr; queries (`docker ps`, `inspect`, `info`) capture.

### Pattern 4: Scenario harness

- One test function is one scenario; `step("name")` is a context manager that adds a note naming the step to the exception that ends the scenario. Verified against pytest 9.2.0: `e.add_note(f"STEP FAILED: {name}")` appears as an `E` line under the failing assertion [VERIFIED: probe this session]. The first failing step ends the test function by raising, so "stops at its first failure and names the step" costs nothing more than an ordinary exception.
- Agents: a parametrized fixture `agent` over `AGENT_SPEC_LIST` (ids `claude`, `cursor`). A function-scoped `sandbox` fixture depends on it, so every scenario runs for each agent and the report shows `test_x[claude]`, `test_x[cursor]`.
- `AgentSpec` is a frozen dataclass of data (composition, no subclasses). Fields found in today's checks:

  | Field | claude | cursor | Source |
  |---|---|---|---|
  | name | `claude` | `cursor` | `knownAgentList="claude cursor"` (bin/sbx-lib.sh:9) |
  | state subdirectory | `state/claude` | `state/cursor` | `AGENT_CONFIG_DIR = STATE_DIR / "claude"` and `"cursor"` (claude_shared.py, cursor_shared.py) |
  | fake login file | `.credentials.json` | `auth.json` | lib-login.sh `claudeDir/.credentials.json`; h34-selfcheck.sh `state/cursor/auth.json` |
  | agent wrapper, binary | `sbx-claude`, `claude` | `sbx-cursor`, `cursor-agent` | `exec sbx-run-agent sbx-claude claude "$@"`, `... sbx-cursor cursor-agent` |
  | selfcheck line count | 55 | 53 | `expectedClaudeCount=55`, `expectedCursorCount=53` (h34-selfcheck.sh:33-34) |
  | init step count | 4 | 5 | `expectedClaudeStepCount=4`, `expectedCursorStepCount=5` (h34-selfcheck.sh:35-36) |
  | links rules into the config dir | yes | no (skills only) | cursor/init/900_best_practices_links.py header: "Cursor gets the skills only" |

  The same table must feed `tests/unit/selfcheck/test_inventory.py`, whose `expected_count` currently reads `tests/host/h34-selfcheck.sh` by text (test_inventory.py:30). Put `AGENT_SPEC_LIST` in a plain module with no Docker import (`tests/integration/agent_specs.py`) and add that directory to `pythonpath`; change `expected_count` to import it. Counts are data, so Phase 10.1.1 and 10.2 only edit rows.
- Fake login files and other planted state: plant through a helper that records what it planted and removes it in a finalizer (folded todo H-34 (a)); the git identity is unset the same way.
- Every Docker call, including `docker exec`, goes through one `run_timeout` helper (Code Examples). pytest has no timeout of its own and adding `pytest-timeout` would break D-01's dependency budget.

### Pattern 5: The shared sandbox fixture (D-13)

Recommended design (Claude's discretion): create each agent's shared sandbox with the real commands against a test registry, not with raw compose.

- Env for every command run by tests: `SBX_CONFIG_DIR=<run>/cfg`, `SBX_IMAGE_TAG=test`, `SBX_CA_CERT=<build-ca.pem>`, plus bogus ambient `SBX_DIR=/nonexistent-ambient SBX_NAME=ambient COMPOSE_PROJECT_NAME=sbx-ambient` (today's proof that commands ignore the caller's variables, run_sbx in lib-sbx.sh).
- Session fixture, once per agent on first use: `sbx-add hosttest-<agent> <run>/<agent> <agent>` on a directory name that has a space (today's H-28 to H-33 do this on purpose), clone the fixture best-practices origin into `<dir>/best-practices` (init fails at the links step without it), `sbx-start`, `sbx-init`.
- Function fixture, every scenario: inspect the container; if it is missing or stopped run `sbx-start`; if `/home/sandbox/.sbx-init-done` is missing run `sbx-init`. This is the "known state" check, so a scenario that upgraded, recreated or stopped leaves nothing for the next one to trip on, and no scenario needs its own restore code.
- Throwaway sandboxes for scenarios that must create or remove one (add, rm lifecycle) use their own name (`hosttest-smoke-<agent>`), own directory and a finalizer that `sbx-rm --unregister --yes`.
- Session teardown removes every container the fixtures started (by name list kept in the fixture, not by glob) and the run directory unless `--keep`. `--keep` is a custom pytest option (`pytest_addoption`) that `host_test.py` forwards.
- Keep the container name prefix `sbx-hosttest` so `clean.sh` and `sbx-list`'s leftover block keep working. Old runs may have left a container named exactly `sbx-hosttest`, so `clean` must still know that name for one release (Runtime State Inventory).

### Anti-Patterns to Avoid
- **Chained scenarios or an ordering plugin.** D-12 forbids it; the fixture's "known state" check is the replacement.
- **A fake `docker` executable, `DOCKER_HOST` pointing nowhere, a stand-in `xattr` script, or a stand-in `shellcheck` shim.** D-20 and HOST-05. Inject functions. The linter rule runs `docker run --rm -v "$PWD:$PWD:ro" -w "$PWD" --entrypoint shellcheck sbx-base:test` from Python when the binary is absent; nothing is written to disk.
- **`pytest -x` in `host-test.sh`.** D-08. A quick local loop may use it.
- **argparse for the sbx commands.** It changes pinned wording and breaks pass-through arguments.
- **Bare `uv run pytest` on the host.** It creates `.venv/` in the repo, which the dev sandbox shares through the mount (D-03). Say so in `tests/README.md` and the README.
- **Naming H-nn, D-nn, HOST-nn or phase numbers in code, test names, headers or docs.**

## Current Host Side Inventory (every file, what happens to it)

| File | Lines | Behavior to carry over | Fate |
|---|---|---|---|
| `bin/sbx-lib.sh` | 314 | Name rule `^[a-z][a-z0-9-]{0,30}$` and reserved `state best-practices` (`nameRulePattern='^[a-z][a-z0-9-]{0,30}$'`, `reservedNameList="state best-practices"`); agents `knownAgentList="claude cursor"`; tags `knownImageTagList="local test"` (unset or empty = local, a non-local accepted tag is named on stderr, any other value refused); `SBX_CONFIG_DIR`/`HOME` handling; `run_compose` env and flags; `require_docker`, `require_images`, `sandbox_is_running`, `runs_older_image` (image id compare), `warn_sessions_close`, `bring_up_sandbox`, `check_sandbox_dirs` | Port into `names`, `registry`, `docker`, `cli`; delete the file |
| `bin/sbx-add` | 295 | Usage `NAME HOST_PATH [claude\|cursor]`; refuse in this order: name, already registered, host path (empty, relative, line break, trailing slash stripped, empty/`.`/`..` part), overlap with registry dir, tools clone, other sandboxes; make `PATH/NAME` and `PATH/state`; write entry exclusively; two success lines | Port; entry becomes JSON; overlap rewritten (Pattern, Code Examples) |
| `bin/sbx-start` | 25 | name, entry, dirs, image present, recreate-on-older-image warning, `up -d --wait`, three success lines | Port |
| `bin/sbx-stop` | 33 | `compose stop`; exits 0 when never started; "nothing in DIR was changed" | Port |
| `bin/sbx-shell` | 38 | start when not running, then `exec docker exec -it -w /home/sandbox/workspace/NAME sbx-NAME bash`; never recreates a running sandbox | Port; exec at the end |
| `bin/sbx-list` | 175 | One `docker ps -a --filter label=sbx.name` call, sorted bytewise; `%-31s %-20s %s` rows; statuses `running`, `stopped`, `no container`, `running, older image`, `broken entry`; older-image note; leftover block for labeled containers without an entry | Port; glob `*.json`; add `old entry` row |
| `bin/sbx-rm` | 211 | `NAME [--unregister] [--yes]` in any order, once each; confirm on a terminal, refuse without one and without `--yes`; broken entry path (stop and rm by name, only with `--unregister`); the only deleter | Port; `isatty` replaces `[ -t 0 ]` |
| `bin/sbx-upgrade` | 80 | warn if running, `build` with pass-through options, `up -d --force-recreate --wait`, init-marker note, versions line last | Port |
| `bin/sbx-fix-modes` | 117 | `git ls-files -s -z`, only modes `100644` and `100755`, host `chmod`, `xattr -p/-w user.containers.override_stat` (uid:gid:mode, keeps uid and gid), counts line, `xattr` missing is said | Port; `xattr` behind an injected function |
| `build.sh` | 201 | `cd` to repo, tag check, `versions.env` present, one `--build-arg NAME` per pin, `SBX_CA_CERT` (absolute, readable, openssl present, split PEM blocks, validate each, fingerprints, banner before and after), base image then one image per agent with `BASE_IMAGE=sbx-base:<tag>`, `--build-context cacert=DIR`, `EXTRA_CA_FINGERPRINTS` | Port; read `versions.env` as text (no `source`); update the file's header comment that says build.sh sources it |
| `clean.sh` | 150 | dry run unless `--yes`; remove `sbx-hosttest` only when it mounts a run directory; remove run directories; `builder prune -a -f`; `image prune -a -f` | Port; names the root cert directory explicitly; also removes the old container name once |
| `host-test.sh` | 261 | preflight (Compose v2), context lines, host checks, run directory, linter versions, pin digests, guard in `sbx-hosttest`, guard on the host with linter shims, build warnings, remove sandbox, summary, `--keep` | Replace by `sbx/host_test.py` plus fixtures and tests (Test runner section) |
| `tests/host/run-all.sh` and `h*.sh`, `lib*.sh` (about 4,000 lines) | | the checks in the map below | Delete after the D-18 table is approved; move `support/best-practices/` to `tests/integration/support/best-practices/` with `git mv` |
| `tests/unit/sbx/*.sh`, `tests/unit/lib-expect.sh` | ~1,300 | 146 `expect` cases | Replace by pytest unit tests; keep the cases that guard real behavior, cut those that re-prove the shell or a library |
| `tests/guard/*.sh` (5 files) | ~670 | 20 rules | Port to pytest (table below) |

## Old Check to New Scenario Map (draft for the D-18 table)

"Kept" means one step in the named scenario, written once for both agents. Items marked CONFIRM are not decided by D-16 or D-17 and need the user's review before the bash goes.

| Old | Old steps | New home | Note |
|---|---|---|---|
| H-03 | variables reach compose; project name; image follows tag | dropped (D-17) | smoke and isolation fail on a wrong variable |
| H-03 | missing `SBX_DIR` or `SBX_NAME` refused by name (`SBX_DIR is required`) | CONFIRM: recommend dropped | the commands always set both; the message is Compose's text on our `:?` guards |
| H-03 | `up` refuses uppercase `SBX_NAME` before creating anything (`name-check` service, `must be lowercase`) | Refusal scenario, step "uppercase name via compose" | plain-compose guard for a caller bypassing `sbx-*`; the `sbx-*` name rule is a unit test |
| H-06 | `git init` on the host, `git status` in the container, no dubious ownership | Smoke scenario, step "git on a host-made repo" | host git must ignore the user's config (`GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`) |
| H-08 | history written per command, survives recreate | Persistence | agent independent; runs for both anyway (D-15) |
| H-09 | sentinels in project dir, state, clone, memory; fake credentials and session; survive rebuild | Persistence | the memory sentinel exists for Claude (`projects/.../memory`); Cursor has no such path today, so `AgentSpec.session_dir` may be `None` |
| H-09 | volume list unchanged | dropped: the one-mount assertion proves no volume is used (the old file says so itself) | CONFIRM |
| H-09, H-29 | one bind mount after rebuild or upgrade | Persistence, one assertion via the helper shared with Isolation | written once |
| H-10 | start on a missing directory refused by Compose, directory not created (`create_host_path: false`) | Refusal scenario, step "missing sandbox directory via compose" | raw compose call; the `sbx-start` pre-check is a unit test |
| H-16 | edit of the clone on the host live in the container; pull inside the sandbox live | First run and relink | Claude: rule file; Cursor links no rules, use a skill file |
| H-16 | plant user files, drop a skill, `sbx-init` relinks, dropped link gone, uncommitted edit kept, user files spared | First run and relink | |
| H-16 | a user skill directory and a real `rules` directory are kept and reported as a FAIL | CONFIRM: recommend dropped | `tests/unit/init/test_init_best_practices_linker.py` covers INIT-05 against real files |
| H-23 | cache locations (`NPM_CONFIG_CACHE`, `UV_CACHE_DIR`, `~/.m2` link) and files survive recreate | Persistence | |
| H-25 | `/etc/sbx/versions.env` in the image equals the repo's | Images match versions.env | |
| H-25 | a bare `docker build` without `build.sh` stops naming the missing pin | unit test (D-17) | CONFIRM what the unit test asserts: `build` refuses a missing or empty `versions.env`, and every `*_VERSION` ARG is guarded by a `${NAME:?... build with ./build.sh}` RUN line (the BuildKit message itself is Docker's) |
| H-26 | privileges, namespaces, devices, group add; one bind mount | Isolation | `HostConfig` fields read with `docker inspect --format '{{json .HostConfig}}'` and parsed as JSON instead of `|`-split text |
| H-27 | `sbx-<agent>` refuses before init; agent not on plain PATH | First run and relink | wrapper and binary names from `AgentSpec` |
| H-27 | init without a clone fails at the links step and names `sbx-best-practices-clone`; clone then init passes; links and read-through; second clone changes nothing; remote URL; push reaches origin; agent starts after init | First run and relink | offline `docker run --rm --network none` on a fresh directory, as today; step counts from `AgentSpec` |
| H-27 | login shell inside an agent session finds the agents directory, plain login shell does not | First run and relink | today Claude here and Cursor in H-34; one parametrized step covers both |
| H-27 | GSD synced at the pin, no `npx`/`@latest` in output | First run and relink | CONFIRM: tests our install, keep; Cursor path is `state/cursor/gsd-core` [ASSUMED] |
| H-27 | clone of a missing origin names `sbx-gh-login` and leaves no directory | CONFIRM: recommend dropped | `tests/unit/init/test_init_best_practices_clone.py` exists |
| H-28 | `sbx-add` writes the entry, makes dirs, second add refused and entry unchanged (dir with a space) | Smoke | entry check becomes the JSON content |
| H-28 | stop before start exits 0; start runs on the registered directory in the right Compose project (ambient variables ignored); no entrypoint; files visible; second start reuses the container; start of a running sandbox on the current image prints no older-image warning; stop under 10 s, keeps files | Smoke | |
| H-28 | lookup of the command through PATH | Smoke, one step per command or a guard rule | the exec-bit and shebang proof moves to a guard rule on launcher modes plus one launcher run |
| H-29 | failed build (`--no-such-option`) leaves id and start time, prints "the build failed" and the warning | CONFIRM: separate scenario "failed upgrade changes nothing" | D-16 lists H-29 under Persistence, but D-11 says unrelated checks get their own scenario |
| H-29 | upgrade recreates only this sandbox (others unchanged), keeps files and fake login, warns, ends with the versions line, starts a stopped sandbox | Persistence (files and login, one upgrade); "others unchanged" and "stopped sandbox starts" CONFIRM | D-16 says one `sbx-upgrade` |
| H-31 | `sbx-shell` on no container starts it; no terminal makes Docker refuse; with a terminal bash opens in the project directory on running and on stopped sandboxes | Smoke (shell) | use `pty` instead of BSD `script`; prove on the host |
| H-32 | list with empty registry; leftovers; rows for no container, running, stopped match `docker ps -a`; no older-image mark | Smoke (list) | |
| H-33 | rm refused without `--yes` and terminal; `--yes` removes container and network, keeps files, entry, volumes, images; again with no container; with the directory moved; `--unregister` deletes only the entry; `sbx-add` of the same directory brings state back | Smoke (rm) | |
| H-34 | `sbx-init` passes (step count), planted identity and fake login, `sbx-selfcheck`: exit status matches FAIL lines, line count, FAIL lines listed with `fix:`, no "no extra root certificate requested" | Init and selfcheck pass | whole-output check, not one grep (folded todo d) |
| H-34 | Cursor sandbox started and removed inside the check | folded into the per-agent fixture | the fixture owns every container (folded todo e) |
| H-35 | root-owned file in the agent state directory given back, no root-owned state left | Init gives root-owned state back | throwaway root container gets a name and is removed in `finally` |
| H-35 | second `sbx-init` refused while one holds the lock | dropped (D-17) | |
| host-test | context, Compose v2 check | preflight in `host_test.py` (unit test the version parser) | |
| host-test | sbx unit tests under `/bin/bash` 3.2 | dropped: no bash logic is left to test | |
| host-test | linter versions | integration test, no scenario | CONFIRM |
| host-test | pin digests vs registry (INFO on a moved tag, FAIL only when unresolvable) | integration test, no scenario | CONFIRM keep; needs network and `docker buildx` |
| host-test | guard inside `sbx-hosttest` on a clone of HEAD | CONFIRM: recommend dropped | the host guard runs the same linter binaries from `sbx-base:test`; the image has no pytest |
| host-test | guard on the host with linter shims | tests/guard run by the same pytest session | linter rule shells to `docker run` when the tool is absent |
| host-test | no `InvalidDefaultArgInFrom` in build logs | assertion in the image-build fixture | CONFIRM |
| host-test | remove test sandbox, `--keep` | session teardown, `--keep` option | |

## Guard Rules Port

20 rules today (README: "20 rules"): linters 2, isolation 5, start 3, supply chain 10. All become pytest functions, one file per group, using one helper `nowhere_matches(regex, path_list) -> list[str]` (replaces the bash helper). File lists use `pathlib` globs, and the new Python and test files join the lists the old ones were in. Keep `tests/guard/` out of its own scan lists (the rule text names the strings it forbids).

| Rule | Port notes |
|---|---|
| `shellcheck_passes` | `SHELL_FILES` becomes the launchers (`bin/*`, `build.sh`, `clean.sh`, `host-test.sh`) plus `base/bin/*`, `claude/bin/*`, `cursor/bin/*`; no `tests/**/*.sh` remain. Native `shellcheck` or `docker run` of `sbx-base:test` |
| `hadolint_passes` | same |
| `no_docker_socket_or_privileges` | `compose.yml` and Dockerfile greps, unchanged |
| `host_scripts_keep_sandbox_data` | scan every `sbx/*.py` except `rm.py` (and `clean.py`, which deletes test runs by design) for `shutil.rmtree`, `os.remove`, `unlink`, `rmdir`, and Docker verbs `rm`, `down`, `prune`, `kill`, `--volumes`; also scan `tests/integration` fixtures per CONTEXT "only `sbx-rm` deletes data" |
| `managed_settings_deny_skill_edits` | `claude/managed-settings.json` text, unchanged |
| `host_tests_never_name_the_local_tag` | scan `host-test.sh`, `sbx/host_test.py`, `sbx/hosttest_names.py`, `tests/integration/**/*.py` for `:local\b`; `tests/unit/sbx` may name it |
| `owner_fix_hint_matches_container_name` | `compose.yml` and `base/selfcheck/root_owned_scan.py`, unchanged |
| `container_runs_no_entrypoint`, `agents_stay_off_the_path` | unchanged |
| `compose_image_follows_agent_and_tag` | split: the `compose.yml` image line stays a grep; the `bin/sbx-lib.sh` and `build.sh` greps become unit tests of the compose env builder and the build plan |
| 10 supply-chain rules | regexes move to `re`; the file lists (`SANDBOX_FILES`, GSD scan list) swap shell files for `sbx/*.py`, `tests/**/*.py`, `tests/integration/support/**` |
| new: launchers are two lines, executable, exec `uv` | asserts each file in `bin/`, plus `build.sh`, `clean.sh`, `host-test.sh`, has a `#!/bin/sh` line and one `exec uv run` line naming a module that exists, and mode `100755` in `git ls-files -s` |
| new: no host shell logic and no stand-in docker | `tests/` and `bin/` contain no `.sh` besides launchers; no file named `docker` under `tests/` |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-test timeout | a custom watchdog thread, `pytest-timeout` | `subprocess.Popen(start_new_session=True)` + `os.killpg` in one helper | `subprocess.run(timeout=)` kills only the direct child; a grandchild (`docker build` under `build.sh`) keeps running [VERIFIED: probe: `sh -c 'sleep 5 & wait'` returned at 1.0 s with the `sleep` orphaned on POSIX]. No new dependency |
| Pseudo-terminal for `sbx-shell` tests | BSD or GNU `script -q /dev/null` | stdlib `pty.openpty()` / `pty.fork()` | `script` differs between BSD and GNU; `pty` is the same call on both [ASSUMED: macOS behavior to be proven on the host] |
| JSON registry parse | line parsing as in the bash | `json.loads` | Typed values, one error path |
| Exclusive create | check-then-write | `open(path, "x")` | Atomic, same guarantee as noclobber |
| Path resolution | manual symlink walking | `os.path.realpath` (resolves symlinks and `..` for the existing part) then `os.path.samefile` | Handles `/tmp` vs `/private/tmp` and inode equality |
| Temp directories | `mktemp` shell-outs | `tempfile.mkdtemp`, pytest `tmp_path` for unit tests | Cleanup and permissions |
| Certificate validation | parse PEM by hand | `openssl x509 -noout` subprocess | Only openssl validates the ASN.1; LibreSSL and OpenSSL print the fingerprint prefix differently, so read only the text after `=` as today |
| Tee of the test stream | shell pipelines | a 10-line pump in `host_test.py` (read child stdout, write to terminal and log, flush per line) | Live log, no `tee` or `PIPESTATUS` |
| CLI parsing | argparse | tiny hand-rolled checks | Pinned `Usage:` wording and pass-through arguments |
| Xattr | `os.setxattr` | the `xattr` CLI behind an injected function | `os.getxattr` is Linux only |

**Key insight:** every piece of the bash that reads like plumbing (`run_timeout`, `tree_pids`, `kill_tree`, `any_alive`, `restart_test_sandbox`, `report_check`, `problemList`) is a stdlib or pytest feature in Python; the code that remains is rules and Docker calls.

## Runtime State Inventory

The registry format changes (a data migration), so each category is answered.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `~/.config/sbx/sandboxes/NAME` old `KEY=value` files on each user's host (`SBX_DIR`, `SBX_AGENT`). Sandbox directories, state and containers do not change | Data migration: `sbx-migrate-registry` (new). Code edit: every reader moves to `NAME.json` |
| Live service config | Containers are named `sbx-NAME`, project `sbx-NAME`, label `sbx.name`; none changes. Leftover test containers: `sbx-hosttest` and `sbx-hosttest-cursor` from old runs | None for user sandboxes. `clean` keeps recognizing the old test container names for one release |
| OS-registered state | The user's `~/.zshrc` PATH line points at the repo `bin/`; command names stay, so it keeps working. No launchd or scheduled tasks | None. Docs: the commands now need `uv` on PATH |
| Secrets and env vars | `SBX_CONFIG_DIR`, `SBX_IMAGE_TAG`, `SBX_CA_CERT` keep their names. `SBX_DIR`, `SBX_NAME`, `SBX_AGENT` stay Compose-only variables set per call | None. A new optional `UV_SYSTEM_CERTS` for proxy users (docs) |
| Build artifacts and installed packages | Repo `.venv/` is Linux and shared with the Mac through the mount; `host-test.log`; `$TMPDIR/sbx-hosttest-root-ca/` and `sbx-hosttest-*` run directories; `__pycache__/` (git-ignored); `uv.lock` unchanged | Never create `.venv` from the host (launchers use `--no-project` and `--isolated`). If the root cert directory is renamed, `clean` removes both names |

## Common Pitfalls

### Pitfall 1: `tests/unit/sbx` vs the `sbx` package, and duplicate module names
**What goes wrong:** `import sbx` finds the wrong thing, or two test helper files both called `helpers.py` collide (`tests/unit/selfcheck/helpers.py` already exists).
**Why it happens:** pytest `prepend` import mode with no `__init__.py` puts each test directory on `sys.path`; module basenames must be unique across suites. A regular package at the repo root wins over a namespace directory, but only if the repo root is on `pythonpath`.
**How to avoid:** add `"."` and `"tests/integration"` to `pythonpath`; give new helper modules unique names (`sbx_helpers.py`, `scenario_helpers.py`, `agent_specs.py`); `conftest.py` files may repeat.
**Warning signs:** `import file mismatch` at collection.

### Pitfall 2: uv and the shared `.venv/`
**What goes wrong:** a bare `uv run pytest` on the host creates a macOS `.venv/` in the repo; the dev sandbox then sees a broken environment.
**How to avoid:** launchers use `--no-project` (commands) and `--isolated --frozen` (tests); docs forbid bare `uv run` on the host. `--frozen` also keeps `uv.lock` from being rewritten through the mount.

### Pitfall 3: First run needs network and, behind a proxy, system certificates
**What goes wrong:** the first `sbx-*` call downloads Python 3.12; behind a TLS-intercepting proxy it fails with a certificate error, and "`brew install uv` is the only prerequisite" turns false.
**How to avoid:** document `UV_SYSTEM_CERTS=true` [CITED: docs.astral.sh/uv/reference/environment/] next to the existing Zscaler steps; the user's own root is already trusted by the macOS store.

### Pitfall 4: Orphaned Docker children after a timeout
**What goes wrong:** a timed-out `sbx-upgrade` leaves `docker build` running and the next scenario collides with it.
**How to avoid:** every long call uses the process-group `run_timeout`; scenarios never call `subprocess.run` on Docker directly.

### Pitfall 5: `argparse`-style usage and exit codes drifting
**What goes wrong:** exit 2 with a different usage line breaks docs and tests; `sbx-upgrade NAME --no-cache` is rejected.
**How to avoid:** hand-rolled checks; one `UsageError` type mapped to exit 2 and one `Usage: <command> ARGS` line; `sbx-upgrade` takes everything after NAME as build options. A usage error runs before any registry or Docker access, as in `sbx_usage` today.

### Pitfall 6: macOS path semantics in the overlap check
**What goes wrong:** the default macOS disk ignores letter case, `/tmp` is `/private/tmp`, and firmlinks make two spellings one directory. Text comparison of resolved paths misses these.
**How to avoid:** keep the reviewed algorithm: resolve, find the deepest existing directory, compare existing parts with `os.path.samefile` and the not-yet-made tails per segment with `casefold()`; anything that cannot be resolved counts as an overlap [VERIFIED: bin/sbx-add:146-152 header comment]. The `..` and symlink cases are tested on Linux; the case rule can only be unit tested on the tail (a nonexistent tail), the existing-directory case proof is on the host.

### Pitfall 7: Registry entry written before the overlap scan sees the old format
**What goes wrong:** with an unmigrated registry, `sbx-add` scans only `*.json` and registers an overlapping sandbox.
**How to avoid:** `sbx-add` refuses when any old entry exists and names `sbx-migrate-registry` (Pattern 2).

### Pitfall 8: Scenario fixtures that restore by hand
**What goes wrong:** a scenario dies mid-way and leaves the sandbox stopped or half-upgraded; every later scenario fails for the wrong reason.
**How to avoid:** detect-and-repair at scenario start (Pattern 5); finalizers for planted files; containers removed by name at session end.

### Pitfall 9: Docker Desktop file sharing and `TMPDIR`
**What goes wrong:** "Mounts denied" when the run directory is not under a shared path.
**How to avoid:** keep creating the run directory under `$TMPDIR/sbx-hosttest-<timestamp>-...` (not pytest's `tmp_path`, whose base `pytest-of-<user>` retains old runs and is not named for `clean`), resolve it with `os.path.realpath`, and keep the existing hint text on a failed `up`.

### Pitfall 10: Exec bits and pycache on the mount
**What goes wrong:** launchers created in the dev sandbox are mode 644 on the host; `sbx-migrate-registry` would not run.
**How to avoid:** the launcher-mode guard rule; `chmod +x` plus `git update-index --chmod=+x` in the plan task; `sbx-fix-modes` is the repair.

## Code Examples

### Overlap check (prototype run in the dev sandbox)

Cases verified true or false as expected on Linux: same directory via symlink (true), new directory inside a symlink (true), `c/../a/b/q` against `a` (true), text-prefix sibling `a-other` vs `a` (false), inside (true), holds (true), two new siblings (false), case-differing new tail (true), symlink up (true) [VERIFIED: ran in this session].

```python
# design prototype [VERIFIED: executed in the dev sandbox; macOS case behavior is proven on the host]
import os


def locate_dir(path: str) -> tuple[str, list[str]]:
    resolved = os.path.realpath(path)
    tail_list: list[str] = []

    while not os.path.isdir(resolved):
        resolved, last_part = os.path.split(resolved)
        tail_list.insert(0, last_part)

    return resolved, tail_list


def paths_overlap(first: str, second: str) -> bool:
    try:
        first_base, first_tail = locate_dir(first)
        second_base, second_tail = locate_dir(second)
    except (OSError, ValueError):
        return True

    if os.path.samefile(first_base, second_base):
        return _tails_overlap(first_tail, second_tail)

    if not second_tail and _dir_within(first_base, second_base):
        return True

    if not first_tail and _dir_within(second_base, first_base):
        return True

    return False
```

`_dir_within` walks `os.path.dirname` upward comparing with `os.path.samefile`; `_tails_overlap` compares the shared-length prefix of the two segment lists after `casefold()`. Keep `check_host_path` (textual refusals) as a separate step before it.

### Registry write and read

```python
# design sketch [ASSUMED]
def write_entry(registry_dir: Path, entry: Entry) -> None:
    registry_dir.mkdir(parents=True, exist_ok=True)
    text = json.dumps({"path": str(entry.path), "agent": entry.agent}, indent=2) + "\n"

    with open(registry_dir / f"{entry.name}.json", "x") as entry_file:
        entry_file.write(text)
```

### Timeout helper that kills the tree

```python
# design sketch [ASSUMED], semantics of killpg after a TERM grace period as in the bash run_timeout
def run_timeout(args, seconds, env=None, log_file=None) -> int:
    process = subprocess.Popen(args, env=env, stdin=subprocess.DEVNULL, stdout=..., stderr=subprocess.STDOUT, start_new_session=True)

    try:
        return process.wait(timeout=seconds)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)

        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()

        return 143
```

### `step()` helper (verified against pytest 9.2.0)

```python
@contextlib.contextmanager
def step(name: str):
    try:
        yield
    except Exception as error:
        error.add_note(f"STEP FAILED: {name}")
        raise
```

Probe output showed `E   STEP FAILED: upgrade` under the failing assert and `1 failed`. A scenario header banner (D-14) sits above each test function in the project's banner style, for example `plant login, history, caches -> sbx-upgrade -> each file still there`.

### Live log

`host_test.py` runs `python -m pytest -v -s -p no:cacheprovider <paths>` as a child with `stdout=PIPE, stderr=STDOUT`, reads lines, writes each to the terminal and `host-test.log` and flushes, returns the child's exit code, and prints `N step(s) failed. Log: <path>` at the end like today. `-s` lets long-step output (build, init) stream; scenarios print their own progress lines through a helper so the `-v` per-test lines stay readable. Run order: `tests/unit/sbx tests/guard tests/integration` (cheap suites first, so a failed image build, which aborts through `pytest.exit` from the session fixture, still leaves their results in the log). The `-s` interleaving of the `-v` name and test output is cosmetic; the banner helper prints a leading newline.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `source versions.env` in bash (file is code) | parse `NAME=value` lines as text | this phase | the file header comment ("build.sh sources this file, so it is code") must change; the guard rule on the line format already enforces `NAME=value` with no spaces |
| noclobber and `cmp` on a two-line file | `open("x")` and JSON | this phase | simpler, typed |
| BSD `script` to give `sbx-shell` a terminal | `pty` module | this phase | one code path on both platforms, to be proven on the host |
| `-x` style chain in `run-all.sh` | independent scenarios, first failed step ends only its scenario | this phase | a failure no longer hides unrelated results |
| Phase 8 "pytest runs in the dev sandbox only" | `./host-test.sh` runs pytest | D-09 | host needs `uv`; Phase 8 D-18 is reversed |

**Deprecated or outdated:** `UV_NATIVE_TLS` (use `UV_SYSTEM_CERTS`) [CITED: docs.astral.sh/uv/reference/environment/]; the bash 3.2 and BSD-tool portability section of `.claude/CLAUDE.md` and `.shellcheckrc` rationale (only launchers and agent wrappers remain shell).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `tests/unit/selfcheck` and `tests/unit/init` are Linux-only enough that `host-test.sh` should not run them on the Mac (they use real keytool, `stat -c`, flock, `ps`) | Open Question 2 | If they pass on macOS, D-09 "runs everything" could include them at no cost |
| A2 | `pty.openpty()` drives `docker exec -it` through the launcher on macOS | Don't Hand-Roll | `sbx-shell` scenario needs another approach (or stays a manual check) |
| A3 | `cursor-agent --version` prints the pinned version string, so the "agent starts after init" step can assert `CURSOR_AGENT_VERSION` | Old Check Map (H-27) | Step asserts exit code only for Cursor |
| A4 | The Cursor GSD sync writes `state/cursor/gsd-core/VERSION` like Claude's | Old Check Map | Per-agent path field in `AgentSpec` differs |
| A5 | Docker Desktop shares `$TMPDIR` by default on macOS | Pitfall 9 | The existing "Mounts denied" hint covers it |
| A6 | Interactive `sbx-shell` works when uv is the parent of the Python process (Ctrl-C, window resize, exit code) | Pattern 1 | Replace `os.execvp` with a `subprocess` call or drop uv for that one command |
| A7 | The SUS verdict for pytest is seam heuristic noise (the existing pin since Phase 8 stands) | Package Legitimacy Audit | A checkpoint would be needed before touching the pin; this phase does not |
| A8 | `Docker = Callable[[Sequence[str], Mapping | None, bool], DockerResult]` is the right shape for the one injected function | Pattern 3 | Cosmetic; any equivalent small function works |

## Open Questions

1. **`..` in `sbx-add HOST_PATH`: keep refusing it, or resolve it?**
   - What we know: the bash refuses any empty, `.` or `..` part before the overlap check, and a unit case pins that message; success criterion 3 says a `..` path is refused "because both paths are resolved before they are compared".
   - Recommendation: keep the textual refusal in `check_host_path` and make `paths_overlap` itself resolve `..`, so the function-level unit test (D-20) proves HOST-03 and the CLI stays fail closed. A `..` path that points into another sandbox is refused either way.

2. **Does `./host-test.sh` also run `tests/unit/selfcheck` and `tests/unit/init`?**
   - What we know: D-09 says "unit, guard and integration"; CONTEXT's Phase 8 note says those suites are Linux and dev sandbox only; the CI phase (11) is meant to run Linux-runnable checks.
   - Recommendation: host run covers `tests/unit/sbx`, `tests/guard`, `tests/integration`; the two image-code suites stay dev sandbox and CI. Ask the user, since D-09 can be read either way.

3. **Create the shared sandbox with the real commands (recommended) or keep raw compose with a registry only for smoke scenarios?**
   - Recommendation: the real commands (Pattern 5). It removes the restore dance and lets `sbx-upgrade`, `sbx-stop` and `sbx-rm` scenarios run on the shared sandbox. Cost: the container name changes from `sbx-hosttest` to per-agent names (`sbx-hosttest-claude`, `sbx-hosttest-cursor`), so `clean` and the docs that name `sbx-hosttest` change.

4. **Guard "inside `sbx-hosttest`" step: drop it?** Recommendation: drop; the host guard runs the same linter binaries from `sbx-base:test` and the image has no pytest. Needs the user's nod because host-test.sh has it today.

5. **Small host-test steps that no D-16 row covers:** linter versions, pin digests, build warnings. Recommendation: keep the pin digest check and the build-warning assertion as plain integration tests, drop the linter versions print (the guard fails when a linter is missing).

6. **Failed-build step (H-29), "others unchanged" and "stopped sandbox starts" (H-29), the clash step (H-16), the missing-origin and GSD steps (H-27), and H-09 volume list:** see CONFIRM rows in the map. Recommendation as marked there; the D-18 review is the place to decide.

7. **Old entries and `sbx-list` / `sbx-add`:** recommended behavior in Pattern 2 (list shows `old entry`, add refuses until migrated). Confirm.

8. **GLOSSARY "launcher":** the glossary reserves "launcher" for the image's Python entry file and says a wrapper is a different thing. D-02 calls the two-line shell files launchers. Propose "host launcher" (two-line shell file in the repo's `bin/`, `build.sh`, `clean.sh`, `host-test.sh`) and keep the image term; update the glossary rows on tests (host check, host tests, host run) to scenario, step, integration tests and host run.

9. **Host proof list (cannot be proven in the dev sandbox):** launcher through uv on macOS with Python download; `sbx-shell` TTY, Ctrl-C and exit status under uv; `pty`-driven shell test; macOS case-insensitive overlap on existing directories; Docker Desktop mounts of the run directory; the cost of two agents times every scenario (the persistence scenario runs `sbx-upgrade` twice).

10. **`H-25` bare-build unit test content** (what exactly it asserts): see the CONFIRM row; recommendation there.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| uv | launchers, pytest | yes (dev sandbox) | 0.12.21 | none; `brew install uv` on the host |
| Python 3.12 | all code | yes (dev sandbox `python3` 3.12.3) | 3.12.3 | uv downloads a managed 3.12 on the host |
| pytest 9.2.0 | all suites | yes through `uv run --isolated --frozen` | 9.2.0 | none |
| shellcheck, hadolint | guard linter rules | yes (dev sandbox) | on PATH | on the host: `docker run` of `sbx-base:test` |
| openssl, git, pgrep | build, fixtures, fix-modes | yes (dev sandbox) | system | none |
| docker, docker compose | integration, `build`, `clean`, most commands | no (`docker: command not found`) | none | none in the dev sandbox; unit tests inject a Docker function; integration is proven on the host |
| xattr | `sbx-fix-modes` | no on Linux | none | injected function in unit tests; macOS has it |
| macOS, Docker Desktop | HOST-01 proof, integration, TTY and case rules | no | none | the user's `./host-test.sh` run, read through `host-test.log` |

**Missing dependencies with no fallback:** Docker and macOS here, so every Docker-dependent success criterion (1, 4, 5 on the host) needs the user's host run; plan human-verify checkpoints.
**Missing dependencies with fallback:** xattr and the linters (injected function; `docker run`).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest 9.2.0 |
| Config file | `pyproject.toml` (`[tool.pytest.ini_options]`: `testpaths`, `pythonpath`, `addopts = "-p no:cacheprovider"`) |
| Quick run command | `uv run pytest tests/unit/sbx tests/guard -q` (dev sandbox; guard linter rules pass natively there) |
| Full suite command | `uv run pytest` in the dev sandbox (existing `testpaths` plus `tests/unit/sbx` and `tests/guard`; `tests/integration` stays out of `testpaths`); `./host-test.sh` on the host for everything including integration |

Planned config edit: `testpaths = ["tests/unit/selfcheck", "tests/unit/init", "tests/unit/sbx", "tests/guard"]`, `pythonpath` gains `"."` and `"tests/integration"`. `host-test.sh` passes explicit paths, so integration only runs there.

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HOST-01 | every launcher is two lines, `#!/bin/sh`, `exec uv run`, names an existing module, mode 100755 | guard | `uv run pytest tests/guard -k launcher -q` | no, Wave 0 |
| HOST-01 | each launcher with no arguments exits 2 with its `Usage:` line (proves the uv wiring on Linux) | unit | `uv run pytest tests/unit/sbx -k launcher -q` | no, Wave 0 |
| HOST-01 | same names on macOS through uv | integration, host | `./host-test.sh` | no, Wave 0 |
| HOST-02 | entry JSON content, exclusive create, values read as data, broken forms, old entry refusal, migration | unit | `uv run pytest tests/unit/sbx -k registry -q` | no, Wave 0 |
| HOST-03 | symlink, `..`, holds, inside, text prefix, tails; sbx-add refusals for registry dir, tools clone, other sandboxes | unit | `uv run pytest tests/unit/sbx -k "overlap or add" -q` | no, Wave 0 |
| HOST-04 | persistence, refusal, smoke, isolation, first run, init and selfcheck, owner, images match, per agent; first failed step named | integration, host only | `./host-test.sh` | no, Wave 0 |
| HOST-05 | no `.sh` under `tests/`, `bin/` holds only launchers, no stand-in docker or xattr scripts, bash helpers gone | guard | `uv run pytest tests/guard -k "no_host_shell" -q` | no, Wave 0 |

Unit coverage list (D-20): name rule (valid, uppercase, underscore, 32 chars, line break, non-ASCII, reserved); image tag (unset, empty, `local`, `test`, other refused, notice only for `test`); the compose argument list and env builder; the build plan (one image per known agent, base arg of the same tag, `--build-context cacert`); `check_host_path` refusals; argument parsing and usage errors for each command (including `sbx-rm` option orders and `sbx-upgrade` pass-through); the refusal order (name, entry, directories, Docker, images); list rows with a recorder returning canned `docker ps` text; `fix_modes` with an injected xattr function; Compose v2 version parser; migration.

### Sampling Rate
- **Per task commit:** `uv run pytest tests/unit/sbx tests/guard -q`
- **Per wave merge:** `uv run pytest` (dev sandbox full), and for Docker waves the user's `./host-test.sh` read through `host-test.log`
- **Phase gate:** `./host-test.sh` green on the host, then `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `pyproject.toml` `testpaths` and `pythonpath` edit
- [ ] `tests/unit/sbx/conftest.py` (tmp registry, recorder Docker function, injected `environ`)
- [ ] `tests/guard/` Python rule files and the `nowhere_matches` helper
- [ ] `tests/integration/conftest.py`, `agent_specs.py`, the sandbox harness, `step()` and `run_timeout`
- [ ] `tests/integration/support/best-practices/` moved with `git mv`
- [ ] `tests/unit/selfcheck/test_inventory.py` reads counts from `agent_specs.py`

## Security Domain

Omitted: `security_enforcement` is `false` in `.planning/config.json`. Security-relevant behavior carried over and to be tested: registry content read as data only; overlap refusals fail closed when a path cannot be resolved; only `sbx-rm` deletes data (guard rule); GSD comes only from `@opengsd/gsd-core` (guard rule, file lists extended to the new Python files).

## Sources

### Primary (HIGH confidence)
- Repo files read in full this session: `bin/sbx-lib.sh`, `bin/sbx-add`, `sbx-rm`, `sbx-list`, `sbx-start`, `sbx-stop`, `sbx-shell`, `sbx-upgrade`, `sbx-fix-modes`, `build.sh`, `clean.sh`, `host-test.sh`, `tests/host/run-all.sh` and `lib*.sh`, `h03`, `h06`, `h08`, `h09`, `h10`, `h16`, `h23`, `h25`, `h26`, `h28`, `h29`, `h31`, `h32`, `h34`, `h35` (most of `h27`, `h33`), `tests/guard/*.sh`, `tests/unit/sbx/*.sh` (headers and case names), `tests/unit/lib-expect.sh`, `compose.yml`, `pyproject.toml`, `.dockerignore`, `versions.env`, `tests/README.md`, `tests/host-checklist.md`, `GLOSSARY.md`, CONTEXT, REQUIREMENTS
- Probes in the dev sandbox: `uv run --no-project`, `uv run --isolated --frozen --project .`, launcher from three directories and via PATH, `Popen` timeout behavior, pytest `add_note` output, overlap prototype, `which docker`, `uv --version`
- `gsd-tools package-legitimacy check --ecosystem pypi pytest` (verdict SUS, reasons `too-new`, `unknown-downloads`)

### Secondary (MEDIUM confidence)
- docs.astral.sh/uv/reference/environment/ (`UV_SYSTEM_CERTS`, `UV_NATIVE_TLS` deprecated, `UV_PROJECT_ENVIRONMENT`, `UV_ISOLATED`, `UV_FROZEN`) and docs.astral.sh/uv/concepts/projects/config/ (no `[build-system]` means uv does not install the project)

### Tertiary (LOW confidence)
- None used for recommendations; macOS-only behavior is marked [ASSUMED] and routed to the host run.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH; stdlib plus the existing pytest pin; uv behavior probed here
- Architecture: HIGH for commands, registry and launcher; MEDIUM for the integration harness (cannot execute Docker here)
- Pitfalls: HIGH for items probed or read; MEDIUM for macOS-specific items

**Research date:** 2026-11-19
**Valid until:** 2026-12-19 (uv and pytest are pinned; re-check uv flag names if the host's `brew` uv is much newer than 0.12.21)
