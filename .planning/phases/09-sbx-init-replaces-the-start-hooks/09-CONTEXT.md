# Phase 9: sbx-init replaces the start hooks - Context

**Gathered:** 2026-11-16
**Status:** Ready for planning

<domain>
## Phase Boundary

A container start only keeps the container alive: no entrypoint, no hooks, no poll, no wait. The user runs `sbx-init` (Python, in the image) to create the state folders, sync GSD, link the bundle, turn Cursor's self-update off and give `state/` back to `sandbox`; it prints one OK or FAIL line per step. The agent wrappers `sbx-claude` and `sbx-cursor` refuse to start the agent until init has run in this container. Every verification lives in `sbx-selfcheck`; `sbx-init` only acts and reports.

</domain>

<decisions>
## Implementation Decisions

### Inside or outside, never split
- **D-01:** Each job sits 100% on one side. Validation of name and folders is the host scripts' job (they already check before `up`, and compose refuses a missing folder); everything that sets up the sandbox from inside is `sbx-init`'s job. No job is split 5% outside and 95% inside.
- **D-02:** The entrypoint goes. `base/sbx-entrypoint` and `base/sbx-start-lib.sh` are deleted; compose runs `sleep infinity` under tini (`init: true`). Its mount, name and folder checks are dropped (the host scripts and the self-check's mount check cover them), and its `create_state_dirs` moves into `sbx-init`.
  **Reversibility:** costly: bringing an entrypoint back touches both Dockerfiles, compose and the host checks that rely on a refusal.
- **D-03:** H-12 ("a plain `docker run` is refused") is deleted, reversing the slimmed H-12 kept in Phase 8. A hand-typed `docker run` gives a throwaway container whose self-check FAILs on the mount.
- **D-04:** The start-hook runner, `start.d/` (all three hooks), the readiness poll (`wait_until_ready` in `bin/sbx-lib.sh`, `wait_for_start_hooks` in `tests/host/lib-sandbox.sh`), their guard rules and the entrypoint self-test cases that test removed code are gone. `sbx-link-bundle` (bash) is replaced by the Python bundle step.

### sbx-init shape (mirrors sbx-selfcheck)
- **D-05:** `sbx-init` mirrors `sbx-selfcheck` in layout and modularization: the base image ships the runner and the shared steps; each agent image adds its own step file to a fixed folder; small helper modules, a small result type, one OK or FAIL line per step, pytest unit tests in the dev sandbox. The runner may share its result and printing module with the self-check. Nothing records which agent an image is for.
- **D-06:** Steps: create the state folders (`shell gh git` plus `SBX_STATE_DIRS`); sync GSD into the agent's config folder; link the bundle; Cursor only: set the static channel in `cli-config.json` (today `cursor/start.d/02-no-self-update`); give every root-owned file in `state/` back to `sandbox` (INIT-06).
- **D-07:** Init stops at the first FAIL, except that a skill clash (D-14) fails the bundle step after linking every other skill.
- **D-08:** A rerun always redoes every step. The steps are idempotent and take seconds, and a rerun after `git pull` of the bundle is the way to relink it. INIT-02's "quick no-op" is dropped.
- **D-09:** A `flock` lock stops a second run while one is running: the second run prints FAIL ("another sbx-init is running") and changes nothing. The kernel releases the lock when the process ends, also on a crash or Ctrl-C, so no stale lock exists.
- **D-10:** Init's last line, after every step passed, says to verify with `sbx-selfcheck`. Init never runs the self-check itself.
- **D-11:** `sbx-bundle-clone` ends by running `sbx-init` (instead of the bundle hook), and its error text names `sbx-init` as the way to relink.

### No diagnostics in sbx-init
- **D-12:** Every verification goes to `sbx-selfcheck`, for build tests, for checks after init, and for the user. A step's OK or FAIL is only its own outcome (the installer's exit code, a link it refused to make). The hooks' own checks move out: the synced GSD `VERSION` against the image's, and the `../../best-practices` resolves-to-clone precheck.
- **D-13:** The self-check covers, adding what is missing: the synced GSD equals the image's; the bundle links resolve; the init marker is present; Cursor's self-update is off; no root-owned file anywhere in `state/` (the tolerance for the GSD sync folders `gsd-core`, `hooks`, `scripts` in `040_root_owned_state.py` goes).

### Bundle links
- **D-14:** For each skill folder in the clone, init looks at `skills/NAME` in the agent's config folder: nothing there, it makes the link; a link into the bundle (an earlier run's), it replaces it; anything else (the user's own folder, a copy, a link elsewhere, a GSD skill), it leaves it alone and the step FAILs naming it, with the fix "rename or move `skills/NAME`". Then any link into the bundle whose skill the clone no longer has is removed.
- **D-15:** Init's own links are recognised by where they point (into the bundle's `skills/`), so the `.best-practices-skills` list file goes. Init never deletes anything that is not its own link into the bundle.
- **D-16:** No atomic swap. An interrupted run leaves a partial set of links and a rerun fixes it; nothing reads the links until the agent starts. INIT-05 and success criterion 4 drop "atomically".
- **D-17:** Claude gets rules and skills linked, Cursor skills only, as today (Phase 6.1 D-09, D-19).

### The init marker
- **D-18:** When every step passes, init writes a marker in the container layer, outside the mount (for example `/home/sandbox/.sbx-init-done`). A recreate or `sbx-upgrade` wipes it, so a container whose `state/` was synced by an older image always needs a new init. No version comparison.

### Agent wrappers and the PATH
- **D-19:** The real `claude` and `cursor-agent` move to a folder that is not on the PATH (for example `/opt/sbx/agents/bin`). `sbx-claude` and `sbx-cursor` keep their names.
- **D-20:** A wrapper with no init marker fails at once (non-zero exit, message: run `sbx-init`), with no wait and no init run. With the marker, it prepends the agents folder to `PATH` and execs the agent, so everything the agent starts (for example `/gsd-review`, which looks for `claude` and `cursor-agent` with `command -v`) finds it. A plain shell does not find `claude`. Not a security boundary, a push to use the wrapper.
- **D-21:** The wrappers' no-clone warning and its 5-second sleep go: a missing clone is reported by init's bundle step and by the self-check.
  **Reversibility:** costly: the agent location is named by both Dockerfiles, the wrappers, the self-check's tool checks and the docs.

### Requirement and criteria amendments
- **D-22:** REQUIREMENTS.md INIT-02 to INIT-05 and ROADMAP.md Phase 9 success criteria 1 to 4 are amended to match D-02, D-08, D-16, D-19 and D-20.

### Decisions taken at planning
- **D-23:** A real folder (or any entry that is not init's own link) where Claude's `rules` link belongs is left in place and the step FAILs with the fix, the same rule as a skill clash (D-15). Init never deletes it.
- **D-24:** A missing best-practices clone FAILs the best-practices step, with a fix naming `sbx-gh-login` then `sbx-bundle-clone`. No marker is written, so the agent wrappers refuse until the clone exists and init passes.
- **D-25:** Step order: state folders, GSD sync, Cursor channel, ownership, best-practices links last, so a clash or a missing clone cannot skip the mechanical steps.
- **D-26:** After taking the lock, every run removes the marker first; it is written again only when every step passes.
- **D-27:** `sbx-gh-login` gets a one-line precondition that points at `sbx-init` when the state folders do not exist yet.
- **D-28:** The stale `.best-practices-skills` file in existing sandboxes is left alone (it is inert) and noted in `MIGRATION.md`.
- **D-29:** Every name this phase adds (files, functions, step names, messages, tests) says best-practices, never bundle. Existing names this phase does not otherwise touch (`SBX_BUNDLE_DIR`, `sbx-bundle-clone`, guard rules) stay; Phase 09.1 sweeps them.

### Claude's Discretion
- Folder names for the init steps and the agents folder; the marker path.
- How the step result type is shared with the self-check (shared module or a sibling).
- How the GSD step drives the installer (time limit, output only on failure, as today).
- How the ownership fix walks `state/` (skip the cache folders the self-check already skips).
- Which host checks and self-test files change or go once the entrypoint is gone (H-10, H-17, H-20, `tests/selftest/entrypoint/`), and how the host tests run `sbx-init` before `sbx-selfcheck`.
- Doc updates: `README.md`, `SANDBOX.md`, `tests/README.md`, `tests/host-checklist.md`, `bin/sbx-shell` usage text.

### Folded Todos
- **Bundle hook deletes a user skill with a bundle skill's name** (`.planning/todos/pending/2026-10-24-bundle-hook-keeps-user-skills.md`): solved by D-14 and D-15.
- **Bundle hook is not atomic and verifies only the rules link** (`.planning/todos/pending/2026-10-24-bundle-hook-atomic-and-verified.md`): atomicity dropped by D-16; verification moves to the self-check (D-12, D-13).
- **sbx-claude waits 5 seconds when nothing is linked** (`.planning/todos/pending/2026-10-24-sbx-claude-no-wait-when-non-interactive.md`): the wait goes (D-20, D-21).
- **The GSD sync leaves files owned by root in state/claude** (`.planning/todos/pending/2026-11-08-gsd-sync-leaves-root-owned-files.md`): init gives them back (D-06), the self-check stops tolerating them (D-13).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone decisions and requirements
- `.planning/research/v2-simple-tooling-decisions.md` item 4: why `sbx-init` replaces the hooks, what was rejected.
- `.planning/REQUIREMENTS.md` INIT-01 to INIT-06 (as amended by D-22).
- `.planning/ROADMAP.md` Phase 9 (as amended by D-22).

### The pattern to mirror
- `.planning/phases/08-in-image-self-check/08-CONTEXT.md`: self-check layout, output and host check decisions.
- `base/selfcheck/runner.py`, `base/selfcheck/check_result.py`, `base/selfcheck/sbx-selfcheck`: runner, result type, launcher.
- `tests/selftest/selfcheck/`: the pytest layout to mirror.

### Code being replaced
- `base/sbx-entrypoint`, `base/sbx-start-lib.sh`: the entrypoint and its steps.
- `claude/start.d/05-gsd`, `claude/start.d/10-best-practices`, `cursor/start.d/02-no-self-update`, `cursor/start.d/05-gsd`, `cursor/start.d/10-best-practices`.
- `base/bin/sbx-link-bundle`, `base/bin/sbx-bundle-clone`.
- `claude/bin/sbx-claude`, `cursor/bin/sbx-cursor`.
- `bin/sbx-lib.sh` (`wait_until_ready`, `bring_up_sandbox`), `tests/host/lib-sandbox.sh` (`wait_for_start_hooks`, `compose_up`).

### Agent CLIs
- `$HOME/workspace/state/claude/gsd-core/workflows/review.md` lines 21 and 26: GSD finds the agent CLIs with `command -v`.

### Prior Cursor decisions
- `.planning/phases/06.1-cursor-agent-image/06.1-CONTEXT.md` D-08, D-09, D-19: GSD and bundle in Cursor, shared bundle step.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `base/selfcheck/` modules (`paths.py`, `users.py`, `tree_walk.py`, `bundle_links.py`, `agent_config.py`): paths, uid, tree walk and bundle-link logic init can reuse or share.
- Self-check checks already present for D-13: `test_claude_gsd_synced.py`, `test_cursor_gsd_synced.py`, `test_*_bundle_links.py`, `test_cursor_self_update_off.py`, `040_root_owned_state.py`.

### Established Patterns
- Agent images add files to a fixed folder and append to `SBX_STATE_DIRS`; the base never names an agent.
- Claude Code is installed with `npm install -g` (`claude/Dockerfile:20`); the Cursor CLI is unpacked to `/usr/local/lib/cursor-agent` and linked into `/usr/local/bin` (`cursor/Dockerfile:27-31`). Both change for D-19.
- Bundle links are relative (`../../best-practices/rules`, `../../../best-practices/skills/NAME`) so they resolve in the container and on the Mac.

### Integration Points
- `compose.yml` (command, init), `base/Dockerfile` (ENTRYPOINT, `/etc/sbx/start.d`), both agent Dockerfiles (COPY of `start.d`, agent install path).
- `bin/sbx-lib.sh` `bring_up_sandbox`: drop the poll; `up -d --wait` returns when the container runs.
- Host tests: run `sbx-init` in the test sandbox before `sbx-selfcheck` (H-34).

</code_context>

<specifics>
## Specific Ideas

- Simplicity first: remove polling and waiting outright; no job split across inside and outside.
- The wrapper refuses instead of warning, so the user cannot run an agent in a sandbox that was not initialised.

</specifics>

<deferred>
## Deferred Ideas

None; discussion stayed within phase scope.

### Reviewed Todos (not folded)
- `2026-10-24-bundle-clone-error-hint-and-option-guard.md`, `2026-10-26-sbx-gh-login-skip-when-logged-in.md`: future requirements, not this phase (D-11 only changes the relink text).

</deferred>

---

*Phase: 09-sbx-init-replaces-the-start-hooks*
*Context gathered: 2026-11-16*
