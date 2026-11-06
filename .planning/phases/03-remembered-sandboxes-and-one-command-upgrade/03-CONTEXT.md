# Phase 3: Remembered Sandboxes and One-Command Upgrade - Context

**Gathered:** 2026-11-06
**Status:** Ready for planning

<domain>
## Phase Boundary

The user registers each sandbox once with `sbx-add <name> <host_path>`, then starts, stops and upgrades it by name alone. One command rebuilds both images and recreates the sandbox; login and history survive. Tool versions are printed at the end of a rebuild and when a bash shell opens. All `sbx-*` scripts run on macOS stock bash 3.2 and with host paths that contain spaces.

Requirements: SCR-01, SCR-02, SCR-03, SCR-07. Jump-in, list and remove are Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Registry
- **D-01:** One small file per sandbox at `~/.config/sbx/sandboxes/<name>` on the Mac. It holds two `NAME=value` lines: `SBX_DIR=<absolute host path>` and `SBX_AGENT=claude`. **Reversibility:** costly. Why: every `sbx-*` script and the Phase 4 list and remove commands read this path and format.
- **D-02:** The registry lives outside the repo and outside every sandbox mount. Why: this repo is itself checked out inside a sandbox mount, so a registry there is agent-writable; an agent that changes one `SBX_DIR` to the Mac home would get the whole home mounted on the next start.
- **D-03:** Scripts read the file line by line and never `source` it, so the file is data, not code. Paths with spaces must work.
- **D-04:** `sbx-add` refuses a name that is already registered (no overwrite). It checks the name against the one sandbox name rule (`sandboxNamePattern` in `base/sbx-start-lib.sh`; the rule stays defined once) and refuses the reserved names `state` and `best-practices`. It requires an absolute host path.
- **D-05:** `sbx-add` creates the host folder when it is missing, plus `<name>/` and `state/` inside it. After `sbx-add`, no script needs the host path again.
- **D-06:** `SBX_AGENT` defaults to `claude`. This phase only records it; `claude` is the only agent there is.

### Scripts and their location
- **D-07:** Four scripts: `sbx-add`, `sbx-start`, `sbx-stop`, `sbx-upgrade`. Each takes `<name>` (`sbx-add` also takes the host path).
- **D-08:** They live in a `bin/` folder at the repo root that the user adds to `PATH` once. They find `compose.yml` and `build.sh` relative to their own location, so `bin/` goes on `PATH` rather than being symlinked. Phase 4 adds its commands next to them.
- **D-09:** Shared code (reading a registry entry, the name check) lives in one sourced `bin/sbx-lib.sh`, not copied into each script.
- **D-10:** `sbx-start` runs `docker compose up -d --wait` with `SBX_NAME` and `SBX_DIR` taken from the registry. It does the folder pre-check that `SANDBOX.md` today asks the user to paste by hand ("Before every start: check the sandbox folder").

### Stop and upgrade semantics
- **D-11:** `sbx-stop` runs `docker compose stop`: the container is kept, nothing in `<name>/` or `state/` is touched. Removing the container is Phase 4's remove command, and Phase 4's list shows stopped containers.
- **D-12:** `sbx-upgrade <name>` runs `build.sh` (base image, then Claude image), then recreates that one sandbox. When the build fails, the sandbox is left as it was.
- **D-13:** Upgrade recreates a running sandbox without asking. It prints one line saying open shells and Claude sessions in that sandbox will be closed.
- **D-14:** Other sandboxes are not touched; they pick up the new image at their next `sbx-start`, because Compose recreates a container whose image changed.

### Version printout
- **D-15:** The versions are written once at build time into a file in the image. The existing build-time smoke tests (`base/Dockerfile`, `claude/Dockerfile`) already fail the build when a tool differs from its pin, so the file cannot be stale. Rejected: asking each tool at every shell open (Java and Maven add about 2 to 3 seconds per shell).
- **D-16:** An interactive bash shell prints that file when it opens. Scripts and one-off `docker exec` commands stay quiet. `sbx-upgrade` prints it at the end of the rebuild.
- **D-17:** One line, for example:
  ```
  claude 2.1.285 · gsd 1.15.0 · ccusage 20.0.26 · node 24.21.0 · jdk 21.0.12 · mvn 3.9.11 · python 3.12
  ```
  The separator must be ASCII in source (code conventions); the planner picks it.

### Settled after research
- **D-18:** `sbx-upgrade` leaves the sandbox running, even when it was stopped or never started before. "Upgraded" always means "running on the new image".
- **D-19:** `sbx-start` waits for the start hooks to finish (polling, bounded at 120 s) before it returns, so the sandbox is ready when the command ends. Phase 7's healthcheck later replaces the polling.
- **D-20:** The reserved names `state` and `best-practices` move into one variable in `base/sbx-start-lib.sh`; `sbx-add` reads that same list rather than keeping a copy.
- **D-21:** `sbx-add` also refuses a host path that contains the registry folder (which covers `/` and `$HOME`), and a host path that another registered sandbox already uses.
- **D-22:** The version line uses ` | ` as its separator and the full Python version (for example `3.12.3`). `SBX_CONFIG_DIR` overrides the registry folder; only tests set it.

### Claude's Discretion
- Exact output and error wording of the scripts, and the usage lines.
- Where the version file sits in the image and how the shell prints it (`.bashrc` or `/etc/bash.bashrc` hook, interactive check).
- How `sbx-upgrade` passes extra options (for example `--no-cache`) through to `build.sh`.
- How the host checks prove the scripts on the Mac (a test registry folder so the user's `~/.config/sbx` is never touched, spaces in the path, bash 3.2).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and requirements
- `.planning/ROADMAP.md` (Phase 3 section): goal and the five success criteria
- `.planning/REQUIREMENTS.md`: SCR-01, SCR-02, SCR-03, SCR-07 (and SCR-04 to SCR-06 for Phase 4, so the registry fits them)
- `.planning/PROJECT.md`: constraints (security, simplicity, coexistence, Mac verification)

### Existing behaviour the scripts wrap
- `compose.yml`: `SBX_NAME` and `SBX_DIR`, the `name-check` service, `create_host_path: false`
- `build.sh`: the only build path; option pass-through
- `base/sbx-start-lib.sh`: `sandboxNamePattern` and `sandboxNameRuleText` (the one name rule)
- `base/Dockerfile`, `claude/Dockerfile`: build-time smoke tests that prove versions equal the pins; `/etc/sbx/versions.env`
- `SANDBOX.md`: the manual flow these scripts replace ("Create a sandbox folder", "Start, enter, stop", "Rebuild without losing login", "Before every start: check the sandbox folder")

### Conventions
- `~/.claude/code-conventions.md` and `~/.claude/AGENTS.md`: shell layout, naming, no dashes as punctuation, ASCII only in source
- `tests/README.md`: where each test suite runs; "a new check needs a real failure it would have caught"

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `build.sh`: called as is by `sbx-upgrade`; already runs from any folder.
- `base/sbx-start-lib.sh`: the name rule variables; a host script can read the pattern from it so the rule is not copied.
- `tests/host/lib-sandbox.sh` `compose_up` and `tests/host/lib-docker.sh` `build_images`: how the host tests start and build today.

### Established Patterns
- Banner layout (80-column rules, title line, at most two "why" lines, Main / Entry Point) for every script.
- `set -eu`, functions, camelCase locals, collection suffixes (`buildArgList`).
- BSD and macOS portable tools only; stock bash 3.2 (no associative arrays, no `mapfile`, no `${var,,}`).

### Integration Points
- New `bin/` folder at the repo root; `.dockerignore` already keeps it out of the build context (allowlist).
- `SANDBOX.md` sections that describe the manual flow get the script flow.
- `tests/guard/` rules that scan shell files and the host check list (`tests/host/run-all.sh`, `tests/host-checklist.md`).

</code_context>

<specifics>
## Specific Ideas

- The user accepts that upgrade kills open shells and Claude sessions in the sandbox it recreates.
- The version line should be short because it shows at every shell.

</specifics>

<deferred>
## Deferred Ideas

None. Discussion stayed within phase scope.

### Reviewed Todos (not folded)
All 11 pending todos matched on generic keywords only ("sandbox", "claude", "host"). They cover the bundle hook, the bundle wrappers and the host tests, not the registry, upgrade or version printout, so none were folded.

</deferred>

---

*Phase: 03-remembered-sandboxes-and-one-command-upgrade*
*Context gathered: 2026-11-06*
