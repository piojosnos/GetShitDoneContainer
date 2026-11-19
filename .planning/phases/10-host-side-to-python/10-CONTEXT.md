# Phase 10: Host side to Python - Context

**Gathered:** 2026-11-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Every host command (`bin/sbx-*`, `build.sh`, `host-test.sh`, `clean.sh`) and every test suite with logic becomes Python run through `uv`. The registry becomes one JSON file per sandbox. The bash host scripts, the bash host tests, the bash guard and the bash unit harness for `bin/` are gone; only the agent wrappers and the two-line launchers stay in shell. Command names stay.

</domain>

<decisions>
## Implementation Decisions

### How a command runs
- **D-01:** All host logic lives in one Python package (`sbx/`, stdlib only at runtime). Keeping the small commands (`sbx-start`, `sbx-stop`, `sbx-shell`) in bash is rejected: their logic is in `bin/sbx-lib.sh` (name rule, registry, image tag, Docker checks), and a split would keep that logic twice, in two languages.
- **D-02:** Each `bin/sbx-*`, `build.sh` and `host-test.sh` is the same two-line launcher: it runs `uv` on `python -m sbx.<command> "$@"`. No logic in the launcher. The PATH setup and the command names stay; nothing is installed.
- **D-03:** The Mac's uv environment lives outside the repo. The repo's `.venv/` belongs to the dev sandbox (Linux) and the Mac sees it through the mount; the two must never share it.
- **D-04:** Each command module has a `main()`, so a later switch to `[project.scripts]` entry points installed with `uv tool install --editable .` only adds those entries and deletes the launchers. Not done now: the user wants real use to show a reason first.
- **D-05:** Anything with real logic (branches, loops) is Python: `bin/`, `build.sh`, `host-test.sh`, `clean.sh`, `sbx-fix-modes`, `tests/guard/`, `tests/unit/sbx/`, `tests/host/`. Shell stays only for the agent wrappers and the launchers.

### Registry
- **D-06:** `sbx-add` writes `~/.config/sbx/sandboxes/NAME.json` with `path` and `agent`; every other command reads it.
- **D-07:** A one-off `sbx-migrate-registry` converts every old `KEY=value` entry (`SBX_DIR`, `SBX_AGENT`) to `NAME.json` and prints what it did. Until it runs, the other commands refuse a sandbox that has only an old entry and name the command. It leaves the old files in place (only `sbx-rm` deletes data); `MIGRATION.md` says they can be deleted. The command is deleted in a later milestone.
  **Reversibility:** reversible: one file and one refusal path.

### Test runner
- **D-08:** Every suite runs under pytest (the pinned 9.2.0), not hand-rolled PASS/FAIL scripts. A full run never uses `-x`: every scenario runs, and the summary lists every failure.
- **D-09:** `./host-test.sh` stays the one command and runs everything: unit, guard and integration. All output goes to `host-test.log` with pytest's `-v` per-test lines, and live output from long steps is visible in the log. This reverses Phase 8 D-18 ("host-test.sh does not run pytest").

### Integration tests are scenario based
- **D-10:** One test function is one end-to-end scenario. Its steps run in code order; the first failed step ends that scenario and the failure names the step (a small `step("...")` helper). This rule is stated once in `tests/README.md` and must be obvious in the code.
- **D-11:** A check that does not belong to a scenario's story goes into its own scenario. Unrelated checks are never mixed into one scenario.
- **D-12:** Scenarios never depend on each other. Today's 10-check chain in `tests/host/run-all.sh` (one failure marks the rest NOT RUN) goes. Order between scenarios does not matter; no ordering plugin.
- **D-13:** The test sandbox is a shared resource, made explicit: one fixture guarantees a known state at the start of each scenario (running, init done). A scenario that upgrades, recreates or removes the sandbox leaves it in that known state, or the fixture restores it. The fixture also removes every container it starts.
- **D-14:** Every scenario and the shared fixture have a banner header in the project style: a title line and 1 to 3 schematic lines saying what it does (for example `plant login, history, caches -> sbx-upgrade -> each file still there`).
- **D-15:** Every scenario runs for both agents (Claude and Cursor) through one parametrized harness; only a few small checks differ per agent (success criterion 6).

### Which host checks survive
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

### Unit tests
- **D-20:** `tests/unit/sbx/` becomes pytest unit tests that call the Python functions in-process: the name rule, registry read and write, the path overlap check through symlinks and `..` (HOST-03), the image tag, argument parsing, the migration. Docker sits behind one small function passed in as a parameter; no fake docker, no monkey-patching.

### Names
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

### Folded Todos
- **H-34 host check hygiene** (`.planning/todos/pending/2026-11-14-h34-host-check-hygiene.md`): (a) planted state left behind is solved by the fixture (D-13); (c) the Python `clean.sh` names the certificate folder explicitly, not by the `sbx-hosttest-*` glob. (b) closed, not done: the folder owner check only matters on a shared Linux `/tmp`; the host is a Mac with a per-user `TMPDIR`.
- **Selfcheck review follow-ups** (`.planning/todos/pending/2026-11-14-selfcheck-review-follow-ups.md`): (d) the selfcheck scenario checks the whole output and count, not one grep; (e) the fixture removes every container it starts. (a) to (c) closed, not done: cosmetic wording for cases that practically never happen.
- **Test duplication cleanup** (`.planning/todos/pending/2026-11-18-test-duplication-cleanup.md`): part (d) only; the bash host helpers it would merge are deleted. Parts (a) to (c) stay in the todo for their own PR.
- **Test suite names** (`.planning/todos/pending/2026-11-18-test-suite-names-in-phase-10.md`): decided by D-20 to D-23.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and requirements
- `.planning/ROADMAP.md` (Phase 10): goal and success criteria, amended by D-19
- `.planning/REQUIREMENTS.md` (HOST-01 to HOST-05): HOST-04 amended by D-19
- `.planning/PROJECT.md`: core value and constraints (Python for logic, macOS host, no Docker in the dev sandbox)

### Prior decisions
- `.planning/phases/08-in-image-self-check/08-CONTEXT.md`: D-16 (pytest pin, `pyproject.toml`), D-18 (reversed by D-09)
- `.planning/phases/09-sbx-init-replaces-the-start-hooks/09-CONTEXT.md`: D-01 (each job wholly inside or outside)

### Code being replaced
- `bin/sbx-lib.sh`, `bin/sbx-*`, `build.sh`, `host-test.sh`, `clean.sh`
- `tests/host/run-all.sh` (current check order, the chain) and `tests/host/h*.sh`
- `tests/unit/sbx/`, `tests/guard/`
- `tests/README.md`, `tests/host-checklist.md`, `GLOSSARY.md`

### Folded todos
- `.planning/todos/pending/2026-11-14-h34-host-check-hygiene.md`
- `.planning/todos/pending/2026-11-14-selfcheck-review-follow-ups.md`
- `.planning/todos/pending/2026-11-18-test-duplication-cleanup.md`
- `.planning/todos/pending/2026-11-18-test-suite-names-in-phase-10.md`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `pyproject.toml`, `.python-version` (3.12), `uv.lock`: pytest 9.2.0 already pinned; `testpaths` and `pythonpath` extend to the new package and suites.
- `base/selfcheck/` and `base/init/`: the Python style to follow (banner headers, small result types, injected dependencies, `tests/unit/` layout).
- `bin/sbx-add` functions (`locate_dir`, `dir_within`, `paths_overlap`, `refuse_*_overlap`): the overlap rules to port, now resolving both paths first (HOST-03).

### Established Patterns
- `bin/sbx-lib.sh`: name rule `^[a-z][a-z0-9-]{0,30}$`, reserved names, image tag only `local` or `test`, `[sbx] ERROR:` messages on stderr, exit 0, 1 or 2.
- `tests/host/run-all.sh`: three tiers today (no sandbox; shared test sandbox; a chain that stops at its first failure). The chain goes (D-12).
- Guard rules that read host test files (no `:local` image named, only `sbx-rm` deletes data) must be ported to the Python files.

### Integration Points
- `compose.yml` (unchanged): `SBX_NAME`, `SBX_DIR`, `SBX_AGENT`, `SBX_IMAGE_TAG`.
- `versions.env`: read by the Python `build.sh`.
- The repo `.venv/` is shared with the dev sandbox through the mount (D-03).

</code_context>

<specifics>
## Specific Ideas

- The user compared the shared test sandbox to integration tests against a database: initialise once, call several APIs, do not reset between calls. Acceptable as long as it is clear, obvious in the code and properly managed.
- The user wants the scenario rule stated very clearly so the suite does not grow into a mix of unrelated checks and scenarios.
- Prefer cutting tests that re-prove a library, test something obvious or guard an unrealistic case.

</specifics>

<deferred>
## Deferred Ideas

- Switch the `sbx-*` commands to an installed tool (`uv tool install --editable .` with `[project.scripts]`) once real use gives a reason (D-04).
- Delete `sbx-migrate-registry` once every sandbox has moved (D-07).

### Reviewed Todos (not folded)
- `2026-10-24-bundle-clone-error-hint-and-option-guard.md`, `2026-10-26-sbx-gh-login-skip-when-logged-in.md`: in-image commands, not the host rewrite.
- `2026-11-08-limit-token-exposure-in-bypass-mode.md`: security, unrelated.
- `2026-11-14-mac-run-glue-script.md`: tooling, its own quick task.
- `2026-11-18-host-portability-and-macos-wording.md`, `2026-11-08-migration-recipe-follow-ups.md`, `2026-11-08-refresh-claude-md-for-the-new-layout.md`, `2026-11-15-recurring-test-audit.md`: docs and process, not this phase.

</deferred>

---

*Phase: 10-host-side-to-python*
*Context gathered: 2026-11-19*
