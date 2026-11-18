# Phase 9: sbx-init replaces the start hooks (Research)

**Researched:** 2026-11-16
**Domain:** In-image Python tooling (sbx-init), container start simplification, bundle-link and ownership handling, shell/guard/host-test cleanup
**Confidence:** HIGH for the repo inventory and the init design (everything below was read in this session); MEDIUM for the Docker Desktop ownership behaviour (INIT-06), which only a Mac run can confirm

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Claude's Discretion
- Folder names for the init steps and the agents folder; the marker path.
- How the step result type is shared with the self-check (shared module or a sibling).
- How the GSD step drives the installer (time limit, output only on failure, as today).
- How the ownership fix walks `state/` (skip the cache folders the self-check already skips).
- Which host checks and self-test files change or go once the entrypoint is gone (H-10, H-17, H-20, `tests/selftest/entrypoint/`), and how the host tests run `sbx-init` before `sbx-selfcheck`.
- Doc updates: `README.md`, `SANDBOX.md`, `tests/README.md`, `tests/host-checklist.md`, `bin/sbx-shell` usage text.

### Deferred Ideas (OUT OF SCOPE)

None; discussion stayed within phase scope.

Reviewed todos (not folded): `2026-10-24-bundle-clone-error-hint-and-option-guard.md`, `2026-10-26-sbx-gh-login-skip-when-logged-in.md`: future requirements, not this phase (D-11 only changes the relink text).
</user_constraints>

<phase_requirements>
## Phase Requirements

D-22 is already applied: REQUIREMENTS.md and ROADMAP.md carry the amended wording quoted below (read this session).

| ID | Description | Research Support |
|----|-------------|------------------|
| INIT-01 | User runs `sbx-init` (Python, in the image); it creates the state folders, syncs GSD and links the bundle, printing each step with OK or FAIL; all checking is left to `sbx-selfcheck`. | Init layout mirroring the self-check (Architecture Patterns 1 and 2), step list and order (Pattern 3), output format (Code Examples) |
| INIT-02 | A rerun redoes every step with the same result; a lock stops an overlapping second run. | `fcntl.flock` on a lock file in the container layer (Pattern 4, probe verified this session) |
| INIT-03 | A container start runs no hooks and no entrypoint: the container only sleeps; the entrypoint, the start-hook runner, `start.d/`, the readiness poll, their guard rules and the entrypoint self-test are gone. | Deletion and edit inventory (section "Inventory"), name-rule relocation (Pitfall 1), host test chain change (Pattern 7) |
| INIT-04 | `claude` and `cursor-agent` are not on the PATH; `sbx-claude` and `sbx-cursor` fail at once, without waiting or running anything, when init has not run in this container. | Link relocation in the agent Dockerfiles (Pattern 6, Pitfall 3), thin wrapper (Code Examples), self-check tool checks (Pattern 8) |
| INIT-05 | Init never deletes a user skill that shares a bundle skill's name; it touches only its own links into the bundle. | Own-link classification by where a link points (Pattern 5, Pitfall 12) |
| INIT-06 | After init, the files in `state/claude` are owned by `sandbox`, not root. | Ownership step reusing the self-check walker (Pattern 3, Pitfall 15), Docker Desktop caveat (Assumption A1) |
</phase_requirements>

## Summary

The phase is mostly a replacement and a deletion. Everything the entrypoint and the five start hooks do is small and already understood; the work is (a) a new Python `sbx-init` that copies the structure of `sbx-selfcheck`, (b) moving the real agent binaries off the PATH, (c) deleting the entrypoint, hooks, poll, guard rules and the whole `tests/selftest/entrypoint/` suite, and (d) rewriting the host checks and docs that leaned on the entrypoint's side effects. In the dev sandbox the suites are green today: 272 pytest tests (`uv run pytest`, about 3 s), 20 guard rules (`bash tests/guard/run-all.sh`, about 9 s), the sbx self-test (about 1 s) and the entrypoint self-test. Docker is not installed here, so every image and mount claim needs a Mac step.

Two findings change the plan shape and are not in CONTEXT.md. First, the host scripts read the sandbox name rule by sourcing `base/sbx-start-lib.sh` (`read_start_variable`, `load_name_rule` in `bin/sbx-lib.sh`), so deleting that file breaks every `sbx-*` host script until the rule is moved into `bin/sbx-lib.sh`. Second, many host checks depend on the entrypoint's side effects (state folders, GSD synced, bundle linked) through `compose_up`; the cheapest correct fix is to make `compose_up` run `sbx-init` in the test container where it used to wait for hooks, so most chain checks keep working unchanged. A third, smaller one: `npm install -g --prefix /opt/sbx/agents` would silently drop the extra root certificate (npm's global config moves with the prefix, probed locally), so the agent binaries should be relocated by moving the PATH link, not by reinstalling.

**Primary recommendation:** Build `sbx-init` first and additively (base `init/` library, shared steps, agent step files, pytest suite, self-check changes), then switch the images and wrappers, then delete the old start path and rewrite the host checks and docs in a last wave. Keep the init step runner a near copy of the self-check runner, reuse `check_result.py`, `paths.py`, `users.py`, `tree_walk.py` and `bundle_links.py` from the self-check folder, and extract the root-owned scan and the bundle skill listing into library modules that both tools import.

## Project Constraints (from CLAUDE.md)

Extracted from `./.claude/CLAUDE.md` and the user's global rules. Treat as locked.

- Logic is Python (`uv` on the host, the image's `python3` inside); shell only for thin `exec` wrappers and Dockerfile `RUN` lines. The wrappers `sbx-claude` and `sbx-cursor` stay shell and stay thin.
- Never use `get-shit-done-cc` or `gsd-build`; GSD comes only from `@opengsd/gsd-core` (guard rule `no_compromised_gsd_package` scans file globs, see Pitfall 4).
- Shell run on the Mac must be BSD/bash 3.2 portable; no `sed -i`, `readlink -f`, `mapfile`, `grep -P`. (The `readlink -f` in a Dockerfile `RUN` runs in the Ubuntu image, so it is fine there.)
- Python style seen in `base/selfcheck/`: type hints on public functions, no bare `except`, early return, full names, collection names with a suffix (`_list`, `_set`, `_map`), imperative loops over comprehension chains, blank lines around control flow, three-line banner comments, "The image puts this file in ..." header line.
- No internal IDs (phase numbers, D-xx) in committed source or fixtures; no "was X" comments; ASCII only in source; prose without dashes as punctuation.
- Tests: write automated tests for new behaviour; a fix starts with a failing test; prefer real files to mocks; never extend the stand-in docker in `tests/selftest/sbx`.
- Abstract numbered fixture names in tests (`skill1`, `config1`), as the existing selfcheck tests do.
- Docker is unavailable in the dev sandbox, so plans need host-side Mac steps; Mac validation always goes through `./host-test.sh` and `host-test.log`.
- Code, `.planning/` and `.claude/` never share a branch or PR. The `.claude/CLAUDE.md` lines about the entrypoint and hooks are stale after this phase; update them in their own PR (a pending todo already tracks the refresh).

## Architectural Responsibility Map

This is container tooling, not a web app, so the tiers are the ones this repo has.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Sandbox name rule and folder checks before `up` | Host scripts (`bin/sbx-lib.sh`) | Compose (`create_host_path: false`) | D-01: validation is 100% outside; the rule must live in the host lib once the start library is deleted |
| Keep the container alive | Compose (`init: true`, `command: ["sleep","infinity"]`) | Image `CMD ["bash"]` | D-02: no entrypoint; compose already sets both |
| Create state folders, GSD sync, bundle links, Cursor channel, ownership fix | In-container `sbx-init` (base image runner, agent step files) | None | D-01, D-06 |
| Verify any of the above | In-container `sbx-selfcheck` | Host check H-34 runs it | D-12, D-13: init only acts and reports |
| "Init has run" state | Container layer marker `/home/sandbox/.sbx-init-done` | Wrappers read it, self-check reports it | D-18: a recreate wipes it on purpose |
| Real agent binaries off the PATH | Agent Dockerfiles (link in a root-owned folder) | Wrappers prepend that folder | D-19, D-20 |
| Persistent agent state | `state/` bind mount (Mac folder) | None | Unchanged; ownership repair happens here |
| Mutual exclusion of two inits | Kernel `flock` on a file in the container layer | None | D-09; the layer is a normal filesystem, the bind mount is not guaranteed to honour locks [ASSUMED] |

## Standard Stack

No new packages. Everything is the Python 3.12 standard library plus the existing, already pinned tools.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python (system `python3`) | 3.12.3 in the dev sandbox; Ubuntu 24.04 image ships the same series | Runtime for `sbx-init`, launched as `#!/usr/bin/python3 -I` like `sbx-selfcheck` | Project rule: logic is Python; the launcher pattern already exists [VERIFIED: base/selfcheck/sbx-selfcheck:1] |
| `fcntl.flock` (stdlib) | n/a | The run lock (D-09) | Kernel releases it at process end; probed here: a second non-blocking lock raised `BlockingIOError` while the holder lived and succeeded after the holder was killed [VERIFIED: probe run this session] |
| `subprocess`, `json`, `os`, `pathlib`, `tempfile` (stdlib) | n/a | Installer run, `cli-config.json` edit, links, ownership | Nothing else needed |
| `gsd-core` (npm global in the image) | 1.15.0 | The GSD installer `sbx-init` drives | Pinned in `versions.env`; ran here offline in 0.3 s with exit 0 and wrote `gsd-core/VERSION` containing `1.15.0` [VERIFIED: probe run this session] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| pytest | 9.2.0 | Unit tests of init in the dev sandbox | `uv run pytest`; pinned in `pyproject.toml` [VERIFIED: pyproject.toml] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Moving the PATH link of the agent binaries | `npm install -g --prefix /opt/sbx/agents` | Rejected: with `--prefix` npm reads `{prefix}/etc/npmrc`, so the extra root certificate `cafile` set in `/usr/local/etc/npmrc` is not applied [VERIFIED: `npm config get globalconfig --prefix /tmp/xprefix` printed `/tmp/xprefix/etc/npmrc`, default printed `/usr/local/etc/npmrc`, npm 11.19.0] |
| Merging shared and agent step files by file name | Runner with fixed "before agent" and "after agent" shared groups | Merge by name is simpler to extend; either works. See Pattern 2 |
| Wrapper in shell | Wrapper in Python | Shell stays thin (marker test, PATH, exec); Python adds interpreter start time to every agent launch |

**Installation:** none. **Version verification:** no package is added; `pytest==9.2.0` is the existing pin. [VERIFIED: pyproject.toml]

## Package Legitimacy Audit

No external package is installed by this phase (standard library only; pytest and the npm packages are existing pins). The legitimacy gate does not apply.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none added) | | | | | | n/a |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
  Mac host                          Docker Desktop                    Container (user sandbox, uid 1000)
  --------                          --------------                    ----------------------------------
  sbx-start / sbx-upgrade
   check name + folders  ---------> compose up -d --wait
   (bin/sbx-lib.sh, owns the        init: true (tini) + sleep infinity   no entrypoint, no hooks, no poll
    name rule after phase 9)         bind mount $SBX_DIR -> workspace            |
                                                                                 | user: sbx-shell -> bash
                                                                                 v
                                     sbx-init (python3 -I launcher)
                                       lock: flock /home/sandbox/.sbx-init.lock  (held? FAIL, change nothing)
                                       remove old marker
                                       steps, sorted by file name across
                                         base steps + /etc/sbx/init.d/<agent>/ :
                                         010 state folders (mkdir)
                                         050 GSD sync     (gsd-core --<agent> --global --config-dir)
                                         060 Cursor only: cli-config.json channel = static
                                         800 state owner  (lchown root-owned paths -> sandbox)
                                         900 bundle links (rules link Claude only; skills both)
                                       first FAIL stops (clash FAILs after linking the rest)
                                       all OK -> touch /home/sandbox/.sbx-init-done
                                       last line: run sbx-selfcheck to verify
                                                                                 |
                  sbx-claude / sbx-cursor  <-----------------------------------+
                    marker missing -> stderr "run sbx-init", exit 1 (no wait, no init)
                    marker present -> PATH=/opt/sbx/agents/bin:$PATH ; exec claude | cursor-agent
                                                                                 |
                  sbx-selfcheck: marker, GSD VERSION, links, channel, no root-owned state, agent not on PATH
```

### Recommended Project Structure

Mirrors `base/selfcheck/`, `claude/selfcheck/`, `cursor/selfcheck/`. Names are discretion; these are the recommendation.

```
base/init/
  sbx-init                 # python3 -I launcher (copy of the sbx-selfcheck launcher; adds init, selfcheck and selfcheck/agents to sys.path)
  init_runner.py           # collect + run + print + lock + marker (must not be named runner.py: the self-check already has one)
  init_step.py             # Step dataclass(name, function) if CheckResult is reused
  gsd_sync.py              # run installer: tempfile output, 300 s limit, process group kill
  bundle_link.py           # classify skills/NAME, link, replace own, remove stale own, clash list
  state_folders.py         # make folders from BASE_STATE_DIR_LIST + SBX_STATE_DIRS
  state_owner.py           # walk state/, lchown root-owned entries (uses the extracted scan)
  steps/
    010_state_folders.py
    800_state_owner.py
claude/init/               # copied to /etc/sbx/init.d/claude/
  050_gsd_sync.py          # gsd_sync(CONFIG_DIR, "--claude")
  900_bundle_links.py      # bundle_link(CONFIG_DIR, BUNDLE_DIR, links_rules=True)
cursor/init/               # copied to /etc/sbx/init.d/cursor/
  050_gsd_sync.py          # "--cursor"
  060_self_update_off.py   # channel = static
  900_bundle_links.py      # links_rules=False
base/selfcheck/            # shared libraries extracted so both tools import them
  root_owned_scan.py       # scan_owned_state + SKIPPED_STATE_DIR_SET (moved out of checks/040_root_owned_state.py)
  paths.py                 # + AGENT_BIN_DIR, INIT_MARKER_FILE, INIT_LOCK_FILE, BASE_STATE_DIR_LIST
  bundle_links.py          # + public bundle_skill_name_list; drop the .best-practices-skills logic
tests/selftest/init/       # pytest; unique module and test file names (Pitfall 8)
```

The Dockerfile block for init copies `base/selfcheck`'s pattern: `mkdir -p /usr/local/lib/sbx-init/steps /etc/sbx/init.d`, `COPY --chmod=755` the launcher, `COPY --chmod=644` the modules and steps, `ln -s ... /usr/local/bin/sbx-init`, then `python3 -m py_compile` of every file so a syntax error stops the build (as `base/Dockerfile:256-262` does for the self-check).

### Pattern 1: Reuse the self-check's result type and helpers
**What:** `check_result.py` already holds `CheckResult(passed, detail, hint)`, `passed()`, `failed()` (which refuses an empty hint), `one_line()`. Step functions return a `CheckResult`; the init runner prints `OK:` instead of `PASS:`. `paths.py`, `users.py`, `tree_walk.py`, `bundle_links.py`, `hints.py` are imported through the launcher's `sys.path`, exactly as the agent self-check files import `claude_shared`. [VERIFIED: base/selfcheck/check_result.py, sbx-selfcheck]
**When to use:** always; this is the D-05 "may share its result module" option.
**Why not copy:** the result type is 30 lines but the walk and the link logic are not; sharing them keeps init and self-check agreeing on what "a link into the bundle" and "root-owned" mean.

### Pattern 2: Step discovery and order
**What:** Shared step files live in `base/init/steps/`, agent step files in `/etc/sbx/init.d/<agent>/`, all named with a three-digit prefix and exposing `STEP_LIST`. The runner loads every file from both folders and sorts by file stem, so the order is visible in file names. Loading code can be the same `importlib.util.spec_from_file_location` loader the self-check runner uses (`runner.load_check_module`, `_module_check_list`), with a load failure turned into a FAIL step. [VERIFIED: base/selfcheck/runner.py:34-81]
**Difference from the self-check, to flag:** the self-check runs shared then agent checks and runs all of them; init needs the ownership fix after the GSD sync (an agent step) and stops at the first FAIL. Merging by prefix solves the ordering without the base naming an agent. The cost is one small asymmetry with `runner.collect_checks`, justified by the ordering requirement.
**Guard against drift:** a pytest inventory test (like `tests/selftest/selfcheck/test_inventory.py`) pins the step names in order for each agent and checks the three-digit prefix.

### Pattern 3: The steps, order and what each reports
Recommended order, a refinement of D-06's list (order was not locked; see Open Question 3):

| Order | Step name (example) | Scope | Action | OK detail | FAIL when |
|-------|--------------------|-------|--------|-----------|-----------|
| 010 | `state-folders` | shared | `mkdir(parents=True, exist_ok=True)` for `shell gh git` plus `SBX_STATE_DIRS` split on whitespace | folders made or present | a name is absolute or has `..` (defense in depth), or `mkdir` raises `OSError` |
| 050 | `claude-gsd-sync` / `cursor-gsd-sync` | agent | make config dir, run `gsd-core --claude\|--cursor --global --config-dir DIR` with stdin closed, 300 s limit, output kept in a temp file | `GSD installer finished` (no version compare, that is the self-check's) | config dir cannot be created; installer exit non-zero or timeout. Print the installer output after the FAIL line |
| 060 | `cursor-self-update-off` | Cursor only | read `cli-config.json`, set `channel` to `"static"`, keep other keys, write via temp file and `os.replace`; new file when missing or empty | `channel set to static` | the file is not valid JSON or not a JSON object; leave it untouched |
| 800 | `state-owner` | shared | scan `STATE_DIR` for uid 0 entries, skipping `cache/npm`, `cache/uv`, `m2`; `os.lchown(path, 1000, 1000)` each | `N paths given back to sandbox` (0 is fine) | any `lchown` raises (collect them, report the first few) |
| 900 | `claude-bundle-links` / `cursor-bundle-links` | agent | Pattern 5 | `N skills linked` (and `rules linked` for Claude) | no clone (missing `rules/` for Claude, `skills/` for Cursor), a clash, or a link that cannot be made |

Putting the bundle step last (after ownership) means a user-caused FAIL (clash, no clone) cannot skip the mechanical steps, and INIT-06 holds even while the user sorts out a clash. If the planner prefers D-06's literal order, only the numeric prefixes change.

### Pattern 4: The lock, the marker and exit codes
- Lock file `/home/sandbox/.sbx-init.lock` in the container layer, opened `a+`, `fcntl.flock(fd, LOCK_EX | LOCK_NB)`. On `BlockingIOError` print `FAIL: lock: another sbx-init is running` plus a fix line, return 1, and touch nothing (no marker removal, no step). Keep the fd open for the whole run; the kernel drops the lock at process end. Do not put the lock in `state/`: that is a bind mount on the Mac, and lock semantics there are not guaranteed [ASSUMED].
- Marker `/home/sandbox/.sbx-init-done`: remove it right after taking the lock, create it (`Path.touch()`) only after every step passed. Removing it first means "marker present" always equals "the last complete run passed". Without that, a rerun that FAILs midway would leave the old marker and the wrappers would let an agent start on a half-updated state. D-18 does not say this; it is a recommendation (Open Question 4).
- Exit codes follow the project rule: 0 all passed, 1 a FAIL (including the lock), 2 usage error (`sbx-init` takes no arguments; one `Usage:` line on stderr).
- Output flushes per line so a slow GSD sync shows the earlier steps at once.

### Pattern 5: Own-link classification (INIT-05, D-14, D-15)
For each skill directory name in the clone (directories only, names not starting with `.`, same filter as `_bundle_skill_name_list` in `base/selfcheck/bundle_links.py:122-133`), look at `config/skills/NAME`:

| State of `skills/NAME` | Action |
|------------------------|--------|
| nothing there (not even a dangling link) | create the link with text `../../../best-practices/skills/NAME` |
| a symlink whose target, joined to the link's folder and normalised lexically, lies under `BUNDLE_DIR/skills/` | own link: replace it |
| anything else: a real folder or file, a symlink elsewhere, a GSD skill | leave it, remember the name, continue |

After the loop: every symlink in `config/skills/` that points into `BUNDLE_DIR/skills/` but whose name the clone no longer has is removed (`unlink`, never `rmtree`). If the remembered clash list is not empty, return `failed("skills/NAME ... not links into the bundle", "rename or move <path>, then run sbx-init again")` naming every clash. Never call `shutil.rmtree` or `rm -rf` anywhere in init; the old hook's `rm -rf` on `skills/NAME` is the bug this fixes. [VERIFIED: base/bin/sbx-link-bundle:70,109]
Use `os.path.normpath(link.parent / link_text)` (lexical) and `path.is_symlink()`; do not use `Path.resolve()` or `exists()`, which would make a dropped skill's dangling link look like "something else" (Pitfall 12).
Claude's `rules` link follows the same three-way rule (link text `../../best-practices/rules`), not an unconditional replace (Open Question 1). Both agents run the same function with `links_rules` as the only difference, as `bundle_links_result(config_dir, bundle_dir, links_rules)` already does for the check. [VERIFIED: base/selfcheck/bundle_links.py:201]

### Pattern 6: Moving the agents off the PATH (INIT-04, D-19)
Keep each real install where it is and move only the PATH link into a root-owned folder:
- Claude: after the existing `npm install -g` RUN, `mkdir -p /opt/sbx/agents/bin && ln -s "$(readlink -f /usr/local/bin/claude)" /opt/sbx/agents/bin/claude && rm /usr/local/bin/claude`. The package declares `bin = { claude: 'bin/claude.exe' }` and a `postinstall` of `node install.cjs` [VERIFIED: `npm view @anthropic-ai/claude-code@2.1.285 bin scripts` this session], so `/usr/local/bin/claude` is a symlink to a regular file.
- Cursor: change the existing link target, `ln -s /usr/local/lib/cursor-agent/cursor-agent /usr/local/bin/cursor-agent` becomes the same link inside `/opt/sbx/agents/bin/` (`cursor/Dockerfile:31`). The launcher already runs through a symlink today; the same resolution is assumed from the new folder (A3).
- Both smoke-test RUNs call the agent by full path (`/opt/sbx/agents/bin/claude --version`, and for Cursor the `env -u CURSOR_CONFIG_DIR HOME="$smokeHome" /opt/sbx/agents/bin/cursor-agent --version`) and add `! command -v claude` or `! command -v cursor-agent` to prove it is off the PATH. [VERIFIED: claude/Dockerfile:91, cursor/Dockerfile:97 hold the bare names today]
- Add `/opt/sbx/agents` to each agent library's `IMAGE_ROOT_LIST` so the ownership and protected-paths checks cover it. `/opt/sbx/best-practices` is the one forbidden path under `/opt/sbx` (`no-bundle-copy` check), and `agents` does not clash with it. [VERIFIED: base/selfcheck/checks/270_no_bundle_copy.py:278]

### Pattern 7: Host test chain after the entrypoint is gone
`tests/host/lib-sandbox.sh` `compose_up` starts the test sandbox and waits for hooks; the chain checks H-08, H-09, H-10, H-16, H-23 and the restore in `lib-sbx.sh` all go through it. Replace the wait with `docker exec sbx-hosttest sbx-init` (exit 0 required, output into `compose-up.log`). Then every check that expects state folders, a synced GSD or linked bundle after a start keeps working, and a recreate re-runs init the way a user would. The three `pgrep -x sleep` assertions in H-28, H-29 and H-31 ("start hooks are done") become meaningless; remove them, and let H-28 assert `docker inspect -f '{{.Config.Entrypoint}}'` prints `[]`. H-34 runs `sbx-init` in both the Claude and the Cursor test sandbox before `sbx-selfcheck`; the Cursor clone must exist first (it does, `start_cursor_sandbox` clones before start).

### Pattern 8: Self-check changes (D-13)
- New shared check: init marker present (file `base/selfcheck/checks/035_init_marker.py` fits the numbering gap after `030_state_folders.py`); fix text "run sbx-init".
- New per-agent check: the agent is not on a plain PATH (`shutil.which("claude")` with the image's default PATH returns `None`), one in each agent folder for symmetry.
- Existing agent tool checks pass an `environment_map` whose `PATH` starts with `AGENT_BIN_DIR`; `tool_result` already takes `environment_map` and calls `shutil.which(..., path=environment_map.get("PATH", ""))`. [VERIFIED: base/selfcheck/tools.py:83-91] The Cursor check already builds its own environment copy (`cursor_version_result`), so it only needs the PATH change.
- `040_root_owned_state.py`: delete `_GSD_SYNC_FOLDER_SET`, `_is_tolerated_path`, the `tolerated_*` plumbing and the "(N tolerated)" text; update `test_root_owned_state.py`.
- Hints: `restart_hint() + "; the start makes the state folders"` (030), `"; the start syncs GSD"` (`agent_config.gsd_synced_result`), `"; the start sets the static channel"` (cursor `050`) and the bundle hint naming `/etc/sbx/start.d/10-best-practices` (`bundle_links.py:104`) all change to a new `init_hint()` that says to run `sbx-init` in the sandbox shell (it is not a Mac command, so not `mac_hint`).
- `bundle_links.py`: remove the `.best-practices-skills` list logic and its constants; keep the exact link text checks. Update `test_bundle_links.py`.
- `image_roots.py`: remove `HOOK_DIR`; replace `/usr/local/lib/sbx` in `BASE_FOLDER_LIST` with `/usr/local/lib/sbx-init` (the old folder will not exist, so leaving it makes `wrappers-root-owned` and `image-paths-protected` FAIL as "missing", Pitfall 2). `image_ownership.py`: drop `hook_dir`, and make the init launcher executable-required like `LAUNCHER_FILE` (a list of launcher files). [VERIFIED: base/selfcheck/image_roots.py:13-15, image_ownership.py:32-46]
- Counts: shared 41 + 1 = 42; Claude 12 + 1 = 13; Cursor 10 + 1 = 11; totals 55 and 53 (were 53 and 51). Update `SHARED_CHECK_COUNT`, `CLAUDE_CHECK_COUNT`, `CURSOR_CHECK_COUNT` in `test_inventory.py`, the name-order tests there, and `expectedClaudeCount` and `expectedCursorCount` in `tests/host/h34-selfcheck.sh` (the inventory test cross-checks them). [VERIFIED: tests/selftest/selfcheck/test_inventory.py:20-22, tests/host/h34-selfcheck.sh:27-28]
- Managed settings: drop the `Edit(//home/sandbox/workspace/state/claude/.best-practices-skills)` deny entry from `claude/managed-settings.json`, the expected list in `claude/selfcheck/090_managed_settings.py:56`, `tests/selftest/selfcheck/test_claude_managed_settings.py:29` and the loop in `tests/guard/isolation.sh:59`. Keep the `skills/**` entry.

### Anti-Patterns to Avoid
- **Verifying inside init:** no GSD version compare, no resolves-to-clone precheck, no self-check call (D-12). A step's OK is only its own outcome.
- **`rm -rf` or `shutil.rmtree` on anything under `state/`:** init only unlinks symlinks it recognises as its own.
- **Reinstalling an agent under a new npm prefix:** loses the extra root certificate; move the link.
- **Entrypoint-shaped leftovers:** a compose `entrypoint:` key, a Dockerfile `ENTRYPOINT`, a readiness `pgrep -x sleep`. After this phase `docker run IMAGE` runs `bash`, and `--entrypoint` flags in tests and README become unnecessary (harmless but stale).
- **Lock or marker under `/home/sandbox/workspace`:** that is the bind mount; a marker there would survive a recreate and lie (D-18).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Mutual exclusion of two `sbx-init` runs | A pid file, a mkdir lock, polling | `fcntl.flock(LOCK_EX \| LOCK_NB)` | No stale lock after a crash or Ctrl-C; verified by probe |
| Folder walk that skips caches and does not follow links | A new `os.walk` loop | `tree_walk.walk_tree` with a hook | Already handles permission errors, links, vanished entries [VERIFIED: base/selfcheck/tree_walk.py] |
| Result type, FAIL needs a fix text | New dataclass and printer | `check_result.CheckResult`, `passed`, `failed`, `one_line` | One shape for init and self-check |
| "Is this a link into the bundle" | A second implementation in init | One function in `bundle_links.py` used by init and the check | Both must agree, or init links what the check rejects |
| JSON edit of `cli-config.json` | `jq` or `sed` | `json.load` / `json.dump` plus `os.replace` | Python rule; keeps other keys; invalid JSON is a clean FAIL |
| Running the installer with a hard time limit | `subprocess.run(capture_output=True, timeout=300)` | `subprocess.run(..., stdout=<temp file>, stderr=STDOUT, start_new_session=True)` and kill the process group on timeout | With pipes, a grandchild holding the pipe keeps `communicate()` blocked after the kill (Pitfall 9) |
| Subprocess flags (stdin closed, env) | Ad hoc calls | `commands.run_command`, extended with a `timeout_seconds` parameter (default stays 60) | The module hard-codes a 60 s limit today; GSD needs 300 [VERIFIED: base/selfcheck/commands.py:12,19-31] |

**Key insight:** every piece of init has a self-check twin that already encodes the rule (links, ownership, state folders, channel). Sharing those functions is the main protection against init and the check drifting apart.

## Runtime State Inventory

This phase changes how existing, already-running sandboxes behave after their next `sbx-upgrade`, so the question "what keeps the old shape" applies.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Existing `state/claude` and `state/cursor` hold links from the old hook (`rules`, `skills/NAME`) and the list file `.best-practices-skills`. The links point into the bundle, so init recognises them as its own and replaces them. The list file stays behind unused. | Code edit only; no data migration. Leave the stale list file (D-15 says init deletes only its own links) and say so in the README, or let init remove it (Open Question 6). A v1 sandbox that holds real copies (not links) in `skills/` gets a clash FAIL once, which is the intended safe behaviour |
| Live service config | None. The registry (`~/.config/sbx/sandboxes/NAME`) is untouched in this phase (Phase 10 changes its format) | None, verified by reading `bin/sbx-lib.sh` |
| OS-registered state | Running containers on the old image keep their old entrypoint until recreated; `sbx-upgrade` recreates them. The marker lives in the container layer, so every recreate needs one `sbx-init` | Document: after `sbx-upgrade`, run `sbx-init` before the agent. `sbx-stop` then `sbx-start` keeps the layer, so the marker survives that |
| Secrets and env vars | None renamed. New optional env names (marker and agents folder overrides for tests) are not secrets | None |
| Build artifacts | Images `sbx-base`, `sbx-claude`, `sbx-cursor` (both tags) carry `/usr/local/bin/sbx-entrypoint`, `/etc/sbx/start.d` and `claude` on the PATH until rebuilt | Rebuild with `./build.sh`; `./host-test.sh` rebuilds the `test` tag itself |

## Inventory: what to delete, replace or edit

Line numbers were read this session.

**Delete outright**

| Path | What it is |
|------|------------|
| `base/sbx-entrypoint`, `base/sbx-start-lib.sh` | Entrypoint and its library (also the source of the name rule, see Pitfall 1) |
| `base/bin/sbx-link-bundle` | Bash linker, replaced by the Python bundle step |
| `claude/start.d/05-gsd`, `claude/start.d/10-best-practices` | Claude hooks |
| `cursor/start.d/02-no-self-update`, `cursor/start.d/05-gsd`, `cursor/start.d/10-best-practices` | Cursor hooks |
| `tests/selftest/entrypoint/` (`bundle-hook.sh`, `gsd-hook.sh`, `lib.sh`, `run-all.sh`, `start-folders.sh`, `start-hooks.sh`, `update-hook.sh`, `support/fake-gsd`, 758 lines) | Entrypoint self-test; the fake GSD is replaced by a small Python stub in the pytest fixtures |
| `tests/host/h12-plain-run-refused.sh` | D-03 |
| `tests/host/h17-start-offline-and-failing-hook.sh` | All of it is hook behaviour; the "starts offline, GSD synced at the pin, no npx" parts move into the H-27 in-container script (offline `docker run`) |
| `tests/host/h20-mistyped-name-refused.sh` | Tested the entrypoint's project-folder refusal; coverage stays in the sbx self-test (`sbx-start`, `sbx-shell`, `sbx-upgrade` refuse a missing project or state folder before Docker) [VERIFIED: tests/selftest/sbx/entry.sh:134, shell.sh:53-58, upgrade.sh:45-50] |

**Replace or edit**

| File | Lines | Change |
|------|-------|--------|
| `base/Dockerfile` | 188-191, 199, comments near 167-170 and 203-206, 291 | Remove the entrypoint COPY, the `/etc/sbx/start.d` mkdir and the `ENTRYPOINT`; keep `CMD ["bash"]` (292). Add the init install block next to the self-check block (256-262). Update the "docker exec shells never run the entrypoint" and "synced at each start" comments, and the "Shared helpers" comment that names the bundle linker |
| `claude/Dockerfile` | 20-23, 47-58, 91 | Relocate the PATH link; COPY init steps instead of `start.d`; smoke test by full path plus `! command -v claude` |
| `cursor/Dockerfile` | 27-31, 37-49, 97 | Same for Cursor |
| `compose.yml` | 18-19 | Already `init: true` and `command: ["sleep", "infinity"]`; only comments change |
| `base/bin/sbx-bundle-clone` | 16-27 | Error text names `sbx-init` for relink; last line runs `sbx-init` (D-11) |
| `claude/bin/sbx-claude`, `cursor/bin/sbx-cursor` | whole | Marker test, PATH prepend, exec; drop the warning and `sleep 5` |
| `bin/sbx-lib.sh` | 9-11 (`startLimitSeconds`), 31-54 (`read_start_variable`, `load_name_rule`), 118, 313-343 (`wait_until_ready`), 346-367 | Define the name rule inline in the host lib; drop the poll; `bring_up_sandbox` ends after `up -d --wait` |
| `bin/sbx-upgrade` | 102 and header | Drop `wait_until_ready`; keep `--wait` in `recreate_sandbox` |
| `bin/sbx-start`, `bin/sbx-shell` | header comments, usage text | Say the container only keeps running; mention `sbx-init` |
| `tests/selftest/sbx/add.sh` | 218 | Stop copying `base/sbx-start-lib.sh` into the fake repo |
| `host-test.sh` | 119-141, 239 | `sandbox_suites` runs only the guard; rename the step |
| `tests/host/lib-sandbox.sh` | 141-205 | Delete `wait_for_start_hooks`; `compose_up` runs `sbx-init` |
| `tests/host/run-all.sh` | check lists | Remove h12, h17, h20 (and `h20` from the chain list) |
| `tests/host/lib-bundle.sh` | `check_bundle_links` | Drop the `.best-practices-skills` comparison |
| `tests/host/h16`, `h27`, `h34`, `h28`, `h29`, `h31`, `h10`, `h23` | see "Host check fates" | |
| `tests/guard/lib.sh` | 21, 23, 25-26 | Drop `ENTRY`, `HOOK_DIRS` and the deleted paths from `SANDBOX_FILES` and `SHELL_FILES` |
| `tests/guard/supply-chain.sh` | 19, 44 | Drop `claude/start.d/*`, `cursor/start.d/*`; optionally add the new Python init files to the GSD-package scan |
| `tests/guard/start.sh` | whole | Delete `start_hooks_have_two_digit_names` and `gsd_sync_runs_before_the_bundle`; the file still holds `compose_image_follows_agent_and_tag`, so keep it under a name that says so (for example `compose.sh`) |
| `tests/guard/isolation.sh` | 59 | One deny entry fewer |
| `claude/managed-settings.json`, `claude/selfcheck/090_managed_settings.py`, `tests/selftest/selfcheck/test_claude_managed_settings.py` | | Drop the `.best-practices-skills` deny |
| `pyproject.toml` | pythonpath | Add `base/init` and the new test folder to `testpaths` |
| Docs | | `README.md` (lines 35, 118-119, 123, 185-205, 273-333, 360, 420-465, 490-507), `MIGRATION.md:143`, `ZSCALER.md:65-110` (first run needs `sbx-init`; Cursor login becomes `sbx-cursor login`), `prompts/consolidate-memories.md:20` (list file reference), `tests/README.md`, `tests/host-checklist.md` (rows for H-12, H-17, H-20, H-16, H-34, the chain line 63, line 75), `.claude/CLAUDE.md` in its own PR |

**Host check fates**

| Check | Old assertion | New fate |
|-------|---------------|----------|
| H-10 | Missing folder refused | Keep; Compose's `create_host_path: false` still refuses. Reword the one message that says "the entrypoint still refused" (`h10-missing-folder-refused.sh:71`) |
| H-12 | Plain `docker run` refused | Delete (D-03) |
| H-16 | Restart relinks, drops removed skill and stale copies, spares user files | Rewrite: a restart changes nothing; `sbx-init` relinks, removes the link of a dropped skill, FAILs and keeps a planted user folder named like a bundle skill, and spares memories, sessions, settings key, `CLAUDE.md`. Remove the `.best-practices-skills` and the stale real `rules` folder plants (a real `rules` folder is now a clash FAIL) |
| H-17 | Offline start, bad hooks | Delete; offline GSD sync and links move into H-27 |
| H-20 | Mistyped name refused by the entrypoint | Delete; sbx self-test covers the host refusal |
| H-23 | Caches live in `state/`; message says the entrypoint made them | Works through `compose_up`; reword the message (`h23:25,32`) |
| H-27 | Wrapper warns, `sbx-bundle-clone` links, offline push | Rewrite the in-container script: before init, `sbx-claude --version` exits non-zero and names `sbx-init`; `claude` is not found on a plain PATH; `sbx-init` with no clone FAILs at the bundle step; `sbx-bundle-clone` then clones and runs init; links resolve; `sbx-claude --version` now prints the pin; second `sbx-bundle-clone` refused; push works; missing origin names `sbx-gh-login`. Also asserts GSD synced at the pin and no `npx` or `@latest` in init output (moved from H-17) |
| H-28, H-29, H-31 | `pgrep -x sleep` "hooks done" | Remove those assertions |
| H-34 | Self-check passes in both sandboxes | Run `sbx-init` first in each; update the two count constants |
| new H-35 | n/a | Plants a root-owned file in `state/claude` with `chown root:root` as the sandbox user (works only where Docker Desktop's ownership emulation allows it), runs `sbx-init`, asserts the owner is `sandbox` again. See Validation Architecture and A1 |

### Plan slicing guidance

Order matters because deleting the entrypoint before init exists, or before the name rule moves, leaves a broken tree. A workable split:

1. Self-check library extraction (root-owned scan, bundle skill list, constants in `paths.py`) and the self-check changes of D-13, with their tests. Green before anything else changes.
2. `sbx-init` library, runner, shared steps, agent step files and pytest suite (additive; nothing calls it yet).
3. Host lib: move the name rule into `bin/sbx-lib.sh`; drop the poll; update the sbx self-test.
4. Images: init install block, link relocation, wrappers, `sbx-bundle-clone`, remove `ENTRYPOINT`, `start.d`, entrypoint COPY.
5. Deletions: entrypoint, hooks, `sbx-link-bundle`, `tests/selftest/entrypoint/`, guard edits, managed-settings edit.
6. Host checks and `host-test.sh` (Pattern 7, fates table, H-35).
7. Docs (README, ZSCALER, MIGRATION, tests docs, `bin/` header text).

## Common Pitfalls

### Pitfall 1: Deleting `sbx-start-lib.sh` breaks every host script
**What goes wrong:** `bin/sbx-lib.sh` `read_start_variable` sources `$repoDir/base/sbx-start-lib.sh` to read `sandboxNamePattern`, `sandboxNameRuleText` and `sandboxReservedNameList`; `sbx_init` calls `load_name_rule` and returns failure with "cannot read the sandbox name rule" when the file is gone. [VERIFIED: bin/sbx-lib.sh:35-54,118] The sbx self-test copies the same file into a fake repo (`tests/selftest/sbx/add.sh:218`).
**How to avoid:** first move the three values into `bin/sbx-lib.sh`, verbatim: pattern `'^[a-z][a-z0-9-]{0,30}$'`, text `'starts with a lowercase letter, then lowercase letters, digits or hyphens, 31 characters at most'`, reserved list `"state best-practices"` [VERIFIED: base/sbx-start-lib.sh:14-18]. Run `bash tests/selftest/sbx/run-all.sh` before deleting the file.
**Warning signs:** every `sbx-*` host script printing "cannot read the sandbox name rule".

### Pitfall 2: `/usr/local/lib/sbx` stops existing
**What goes wrong:** that folder only exists because `base/Dockerfile:189` copies the start library into it. `BASE_FOLDER_LIST` names it, so `wrappers-root-owned` and `image-paths-protected` would FAIL as "missing" in the image (only visible on the Mac, `test_image_roots.py` will not notice).
**How to avoid:** replace it with `/usr/local/lib/sbx-init` in `image_roots.py` and its test in the same plan that changes the Dockerfile.

### Pitfall 3: `npm --prefix` drops the extra root certificate
**What goes wrong:** relocating Claude by installing under `/opt/sbx/agents` makes npm read `/opt/sbx/agents/etc/npmrc` instead of `/usr/local/etc/npmrc`, where `base/Dockerfile` writes `cafile=...` for a corporate proxy. The install then fails behind a TLS-intercepting proxy, on the one machine class this project supports. [VERIFIED: local npm probe above; the npmrc write is in base/Dockerfile near "Optional extra root certificate: the tools that keep their own store"]
**How to avoid:** Pattern 6 (move the link).

### Pitfall 4: Deleted paths left in guard globs
**What goes wrong:** `tests/guard/lib.sh` `SHELL_FILES` lists `claude/start.d/* cursor/start.d/*` and `tests/selftest/*/support/fake-gsd`; `supply-chain.sh:19,44` list the hook globs. An unmatched glob stays literal and `nowhere_matches` reports "grep could not read every file", and shellcheck fails on a missing file.
**How to avoid:** edit the globs in the same commit that deletes the files; run `bash tests/guard/run-all.sh` after each deletion commit.

### Pitfall 5: Things that call a bare `claude` or `cursor-agent`
**What goes wrong:** after the move, `claude` and `cursor-agent` are not on the PATH. Callers: the self-check tool checks (`tool_result("claude", ...)`), both Dockerfile smoke tests, H-27's `claude_pin` expectation, README "Image-only smoke tests" (`docker run --rm --entrypoint claude sbx-claude:local --version`), `ZSCALER.md` (`cursor-agent login`), README ("Plain `claude` works too", "Log in once with `cursor-agent login`"). The wrapper passes arguments through, so `sbx-cursor login` replaces `cursor-agent login`.
**How to avoid:** grep the repo for `claude --version`, `cursor-agent` and `plain` after the change; the host-side smoke test becomes `docker run --rm sbx-claude:local /opt/sbx/agents/bin/claude --version`.

### Pitfall 6: State folders no longer exist before init
**What goes wrong:** the entrypoint made `state/shell gh git cache/npm cache/uv m2 claude`. Before `sbx-init`, `sbx-gh-login` runs `git config --global`, which writes `GIT_CONFIG_GLOBAL=state/git/config` in a folder that does not exist yet (git cannot create the lock file), bash cannot write `HISTFILE`, and `~/.m2` dangles. [VERIFIED env values: base/Dockerfile:171-179 `GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL`, `HISTFILE`, `SBX_STATE_DIRS`; the `git config` failure mode is [ASSUMED] from git behaviour, not run here]
**How to avoid:** the first-run order in the docs becomes `sbx-init`, `sbx-gh-login`, `sbx-bundle-clone` (which runs init again), then the agent. Add a one-line precondition to `sbx-gh-login` ("run sbx-init first" when `$GH_CONFIG_DIR` is missing) so a wrong order gives a message, not a git error (Open Question 5).

### Pitfall 7: Host chain checks lean on entrypoint side effects
**What goes wrong:** H-08, H-09, H-16, H-23 and the restore step expect state folders, a synced GSD and a linked bundle after `compose_up`. Without the entrypoint nothing makes them.
**How to avoid:** `compose_up` runs `sbx-init` (Pattern 7). Do not add `sbx-init` calls to each check.

### Pitfall 8: pytest name collisions between the two suites
**What goes wrong:** the existing suite relies on `pythonpath` entries and the default import mode with no `__init__.py`, so module basenames are global. A second `conftest.py` is fine, but a second `helpers.py`, a second `runner` module, or a test file with the same basename (`test_bundle_links.py` already exists) clashes ("import file mismatch" or the wrong module). [VERIFIED: pyproject.toml pythonpath and tests/selftest/selfcheck/ have no `__init__.py`; the collision behaviour is [CITED: docs.pytest.org good integration practices, from memory] and was not reproduced]
**How to avoid:** unique names: `init_runner.py`, `init_helpers.py`, `test_init_*.py`. Agent step files are loaded by path with a directory-qualified module name (as `runner.load_check_module` does) and are not put on `pythonpath`.

### Pitfall 9: Installer output through pipes can hang after a timeout
**What goes wrong:** `subprocess.run(capture_output=True, timeout=...)` kills the direct child on timeout but then waits for the pipes to close; a grandchild that inherited them keeps it blocked. The old hook avoided this by redirecting to a temp file (`>"$logFile" 2>&1`). [VERIFIED: claude/start.d/05-gsd:47-60]
**How to avoid:** write installer output to a `tempfile`, run in its own session, kill the process group on timeout, print the file only on failure. Also keep the "make the config folder first" guard: the installer waits forever on a folder it cannot create. [VERIFIED: claude/start.d/05-gsd:21-32]

### Pitfall 10: Lock or marker placed on the bind mount
See Pattern 4. A marker in `state/` survives `sbx-upgrade` and claims init ran against a newer image; a lock there may not be honoured by the Mac file sharing layer.

### Pitfall 11: Marker left from an earlier successful run
A rerun that FAILs must not leave "initialised" behind. Remove the marker after taking the lock, write it only at the end (Pattern 4).

### Pitfall 12: Recognising own links with `resolve()` or `exists()`
**What goes wrong:** a dropped skill leaves a link whose target is gone; `exists()` is False and `resolve()` points nowhere, so the link would be treated as foreign and the stale link never removed (this is what H-16's dropped skill exercises).
**How to avoid:** `is_symlink()`, read the link text, `os.path.normpath` of `link.parent / text`, compare as a string prefix with `BUNDLE_DIR / "skills"`. Both relative and absolute link texts work this way.

### Pitfall 13: Check-count constants in two places
`test_inventory.py` and `h34-selfcheck.sh` both hold the counts, and a test cross-checks them. Add the checks, then update both in the same commit or the dev-sandbox suite goes red (the host check goes red later, on the Mac only).

### Pitfall 14: `chown` back to the sandbox user works only on some filesystems
**What goes wrong:** on a real Linux bind mount a non-root user cannot change the owner of a root-owned file (`os.chown(path, 0, 0)` as uid 1000 raised `PermissionError` in a probe here). On Docker Desktop the todo records that `sandbox` could set a file's owner to root and back, because ownership there is an attribute (`user.containers.override_stat`). [CITED: .planning/todos/pending/2026-11-08-gsd-sync-leaves-root-owned-files.md; the Linux half VERIFIED by probe]
**How to avoid:** use `os.lchown`; on `PermissionError` the step FAILs with the existing Mac fix (`docker run --rm --network none -u root --entrypoint chown ...`) from the self-check hint. Confirm the Docker Desktop behaviour on the Mac (A1, H-35).

### Pitfall 15: Image launchers and mode bits
`image_ownership` requires `sbx-*` commands under `/usr/local/bin` and the one `LAUNCHER_FILE` to be executable; the init launcher in `/usr/local/lib/sbx-init/` is not covered unless the rule is extended. Copy with `COPY --chmod=755` for launchers and wrappers, `--chmod=644` for modules. Scripts committed from the dev sandbox lose the exec bit on the Mac; set it in git (`git update-index --chmod=+x`) for any new shell script the repo runs from the checkout.

### Pitfall 16: Existing state with a real folder where a link belongs
A v1 sandbox that holds copies of bundle skills (or a real `rules` folder) gets a clash FAIL on its first init. That is the safe, intended outcome; the fix line says rename or move it. Mention it in MIGRATION.md.

## Code Examples

Sketches that show the shape, not final code. Names follow the self-check's conventions.

### Output of a run (format, ASCII only)
```
OK: state-folders: shell, gh, git, cache/npm, cache/uv, m2, claude exist under /home/sandbox/workspace/state
OK: claude-gsd-sync: the GSD installer finished into /home/sandbox/workspace/state/claude
OK: state-owner: 313 paths given back to sandbox
FAIL: claude-bundle-links: skills/pr-reply is a folder, not a link into the bundle
      fix: rename or move /home/sandbox/workspace/state/claude/skills/pr-reply, then run sbx-init again
sbx-init: stopped at claude-bundle-links
```
All passed: `sbx-init: 5 steps passed; run sbx-selfcheck to check the sandbox`.
Second run while a first holds the lock: `FAIL: lock: another sbx-init is running` with `      fix: wait for it to finish, then run sbx-init again`, exit 1, nothing changed.

### Lock (stdlib; behaviour probed this session)
```python
# Source: stdlib fcntl; behaviour verified by a local two-process probe
import fcntl

def take_lock(lock_file: Path):
    handle = lock_file.open("a+")

    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()
        return None

    return handle   # keep it referenced for the whole run
```

### Ownership step (reuses the extracted scan; lchown never follows links)
```python
# state_owner.py
def give_back_state(state_dir: Path, from_uid: int, to_uid: int, to_gid: int,
                    chown_function=os.lchown) -> CheckResult:
    path_list, _ = scan_owned_state(state_dir, from_uid, SKIPPED_STATE_DIR_SET, set())
    failure_list = []

    for relative_name in path_list:
        try:
            chown_function(state_dir / relative_name, to_uid, to_gid)
        except OSError as e:
            failure_list.append(f"{relative_name}: {e.strerror}")

    if failure_list:
        return failed(capped_problem_detail(failure_list), _owner_fix_hint())

    return passed(f"{len(path_list)} paths given back to sandbox")
```
The `owner_uid` argument is already injectable in `scan_owned_state`, and the existing tests use `os.getuid()` as the stand-in for root. [VERIFIED: tests/selftest/selfcheck/test_root_owned_state.py:57]

### Wrapper (thin shell, testable through two env overrides)
```bash
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Runs Claude once sbx-init has run in this container
# ------------------------------------------------------------------------------
# Usage: sbx-claude [claude arguments]
# ------------------------------------------------------------------------------
set -eu

marker=${SBX_INIT_MARKER:-/home/sandbox/.sbx-init-done}
agentBinDir=${SBX_AGENT_BIN_DIR:-/opt/sbx/agents/bin}

if [ ! -e "$marker" ]; then
  echo "sbx-claude: sbx-init has not run in this container; run sbx-init first" >&2
  exit 1
fi

PATH=$agentBinDir:$PATH
export PATH
exec claude "$@"
```
A pytest test asserts both wrapper files contain the same literal marker path as `paths.INIT_MARKER_FILE` so they cannot drift. `sbx-cursor` is the same with `cursor-agent`.

### Bundle step core (INIT-05)
```python
def own_bundle_link(link: Path, bundle_skills_dir: Path) -> bool:
    if not link.is_symlink():
        return False

    target_text = os.path.normpath(link.parent / link.readlink())

    return target_text.startswith(str(bundle_skills_dir) + "/")
```
Create with `link.symlink_to(f"../../../best-practices/skills/{name}")`; replace an own link with `link.unlink()` then `symlink_to`; remove stale own links with `unlink()`. [Link text constants: base/selfcheck/bundle_links.py:13-14, `"../../best-practices/rules"` and `"../../../best-practices/skills/{name}"`]

### Dockerfile link relocation
```dockerfile
# claude/Dockerfile, in the same RUN after npm install -g
&& mkdir -p /opt/sbx/agents/bin \
&& ln -s "$(readlink -f /usr/local/bin/claude)" /opt/sbx/agents/bin/claude \
&& rm /usr/local/bin/claude
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Entrypoint runs checks and hooks at every start; host polls `pgrep -x sleep` | Container only sleeps; user runs `sbx-init`; `up -d --wait` returns at running | This phase | No wait, no poll, no stuck-start failure mode. Compose docs describe `--wait` as "Wait for services to be running\|healthy" [CITED: docs.docker.com/reference/cli/docker/compose/up] |
| Bash hooks with `rm -rf` on skill names and a list file | Python step that replaces only own links, recognised by target | This phase | Fixes the user-skill deletion bug |
| `claude` and `cursor-agent` on the PATH, wrapper warns | Agents off the PATH, wrapper refuses without the marker and prepends the folder | This phase | A sandbox cannot run an agent uninitialised |
| Self-check tolerates GSD-owned root files | Init gives them back; the tolerance is removed | This phase | `no-root-owned-state` becomes strict |

**Deprecated/outdated after this phase:** README sections on start hooks and "Safety checks at start", the "Image-only smoke tests" recipe, the `[sbx] ERROR: start hook` troubleshooting rows, `tests/host-checklist.md` rows for H-12, H-17, H-20.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | On Docker Desktop the sandbox user can `lchown` a root-owned file back to itself, so the ownership step succeeds there. Source is a 2026-11-08 todo that records the opposite direction working ("set a file's owner to root and back") | Pattern 3, Pitfall 14, INIT-06 | The step would FAIL on the Mac and INIT-06 could not be met by init alone; fallback is the existing Mac-side `docker run -u root ... chown` hint |
| A2 | `docker compose up -d --wait` returns once the container is running when no healthcheck exists (docs say "running\|healthy"; the repo already relies on it) | Pattern 7 | `sbx-start` could return a moment early; low impact because nothing waits on hooks any more |
| A3 | The Cursor launcher and the Claude native binary behave the same when started through a symlink in `/opt/sbx/agents/bin` as through one in `/usr/local/bin` (both resolve through a symlink today) | Pattern 6 | Smoke test in the Dockerfile fails at build time; easy to see, no silent breakage |
| A4 | Claude Code does not warn or change behaviour because `claude` is not on the shell PATH (it runs via the wrapper with the folder prepended) | Pattern 6 | A cosmetic warning (for example from `claude doctor`); LOW risk |
| A5 | A missing bundle clone makes the bundle step FAIL, so no marker is written and the wrappers refuse, i.e. an agent cannot start in a sandbox with no clone | Pattern 3, Open Question 2 | If the user wants agents usable without a clone, the step must SKIP or pass with a note instead; this changes the first-run flow and success criterion 3 reading |
| A6 | `flock` is reliable on the container's own filesystem and not guaranteed on the Mac bind mount | Pattern 4 | Only affects where the lock file may live; the recommendation already avoids the mount |
| A7 | `git config --global` fails when `state/git/` does not exist (so `sbx-gh-login` before `sbx-init` breaks) | Pitfall 6 | If git creates the folder, the extra precondition in `sbx-gh-login` is unnecessary but harmless |
| A8 | pytest basename collision behaviour in prepend import mode (from memory of pytest docs, not reproduced) | Pitfall 8 | Worst case the unique-name rule is stricter than needed |

## Open Questions

1. **A real folder (or other foreign entry) where Claude's `rules` link belongs.**
   - What we know: D-14 specifies the skills; D-15 says init never deletes anything that is not its own link; D-17 says Claude gets rules and skills linked. The old hook did `rm -rf "$configDir/rules"` unconditionally. [VERIFIED: base/bin/sbx-link-bundle:58]
   - What is unclear: whether `rules` follows the same leave-and-FAIL rule.
   - Recommendation: yes, same rule, so INIT-05's "touches only its own links" holds for rules too. Update H-16's stale-rules plant accordingly.

2. **Missing clone.**
   - What we know: D-21 moves the no-clone report into init's bundle step and the self-check; D-18 writes the marker only when every step passes; D-20 makes the wrappers refuse without it.
   - What is unclear: a literal reading makes a clone mandatory before any agent runs. That matches the "the user cannot run an agent in a sandbox that was not initialised" intent in CONTEXT, but also blocks a sandbox with no bundle at all.
   - Recommendation: FAIL (A5), with the fix naming `sbx-gh-login` and `sbx-bundle-clone`; confirm with the user in plan review.

3. **Step order.**
   - D-06 lists folders, GSD, bundle, Cursor channel, ownership but does not lock an order. Recommendation: folders, GSD, Cursor channel, ownership, bundle last (Pattern 3), so a clash or missing clone cannot skip the mechanical steps.

4. **Marker removal at run start.**
   - D-18 says the marker is written on success. Recommendation: also remove it at the start of every run after the lock is taken (Pattern 4). Confirm.

5. **`sbx-gh-login` before `sbx-init`.**
   - Recommendation: add a one-line precondition to `sbx-gh-login` that points at `sbx-init`. It is a small edit to a shell helper that is not otherwise in scope; the alternative is documentation only.

6. **The stale `.best-practices-skills` file in existing sandboxes.**
   - Recommendation: leave it (strict D-15) and note it in MIGRATION.md; it is inert. If the user prefers a tidy state, init may remove that one named file as its own artefact.

7. **Folder and marker names.** Discretion. Recommended: `/etc/sbx/init.d/<agent>/` (symmetry with `selfcheck.d`), `/opt/sbx/agents/bin`, `/home/sandbox/.sbx-init-done`, `/home/sandbox/.sbx-init.lock`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| python3 | init code, pytest | yes | 3.12.3 | none needed |
| uv | `uv run pytest` | yes | on PATH (`/usr/local/bin/uv`); suite ran, 272 passed | none needed |
| node and npm | probes of npm behaviour; `gsd-core` | yes | node v24.21.0, npm 11.19.0 | none needed |
| `gsd-core`, `gsd-tools` | real-installer probe | yes | 1.15.0 | the pytest suite uses a Python stub on a temp PATH |
| shellcheck, hadolint | guard rules `shellcheck_passes`, `hadolint_passes` | yes | on PATH; guard: all 20 rules pass | none needed |
| docker, docker compose | image build, `./host-test.sh`, H-checks | NO in the dev sandbox | n/a | Mac only: `./host-test.sh`, read `host-test.log` |
| Docker Desktop on the Mac | INIT-04 image behaviour, INIT-06 ownership (A1), H-27, H-34, H-35 | Mac only | n/a | none; plans need host-side verification steps |

**Missing dependencies with no fallback:** Docker in the dev sandbox. Every image and mount claim in this phase is checked on the Mac.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest 9.2.0 through `uv run pytest` (Python), bash guard rules, bash sbx self-test, bash host checks |
| Config file | `pyproject.toml` (`testpaths`, `pythonpath`, `-p no:cacheprovider`); add `base/init` to `pythonpath` and `tests/selftest/init` to `testpaths` |
| Quick run command | `uv run pytest tests/selftest/init tests/selftest/selfcheck -q` (about 3 s today for the self-check part) |
| Full suite command (dev sandbox) | `uv run pytest -q && bash tests/guard/run-all.sh && bash tests/selftest/sbx/run-all.sh` |
| Full suite command (Mac) | `./host-test.sh`, then read `host-test.log` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INIT-01 | Runner prints one `OK:` or `FAIL:` line (plus a `fix:` line) per step in prefix order, stops at the first FAIL, prints the closing line, exits 0, 1 or 2 | unit (pytest, real files in `tmp_path`) | `uv run pytest tests/selftest/init -k runner -q` | Wave 0 |
| INIT-01 | State folders are made from `shell gh git` plus `SBX_STATE_DIRS`; a hostile name (`..`, absolute) FAILs | unit | `uv run pytest tests/selftest/init -k state_folders -q` | Wave 0 |
| INIT-01 | GSD step runs a stub `gsd-core` from a temp PATH with the exact arguments `--claude --global --config-dir DIR` (and `--cursor`), prints installer output only on failure, times out and kills the group, refuses an uncreatable config folder | unit with a Python stub script | `uv run pytest tests/selftest/init -k gsd -q` | Wave 0 |
| INIT-01 | Cursor channel step sets `channel` to `static`, keeps other keys, handles a missing or empty file, FAILs on invalid JSON and leaves the file as it was | unit | `uv run pytest tests/selftest/init -k self_update -q` | Wave 0 |
| INIT-01 | Real installer in the dev sandbox: `gsd-core --claude --global --config-dir <tmp>` then `gsd-core/VERSION` equals `GSD_CORE_VERSION` | integration (uses the installed 1.15.0; skip when `gsd-core` is absent) | `uv run pytest tests/selftest/init -k real_gsd -q` | Wave 0 |
| INIT-01 | Inventory: step names and order per agent, three-digit prefixes, every file ends in `STEP_LIST`, launcher refuses arguments with exit 2 | unit | `uv run pytest tests/selftest/init -k inventory -q` | Wave 0 |
| INIT-02 | A rerun on the same tree gives the same output and state | unit | `uv run pytest tests/selftest/init -k rerun -q` | Wave 0 |
| INIT-02 | A subprocess holding the flock makes `sbx-init` print `FAIL: lock: another sbx-init is running`, exit 1 and change nothing (no marker removed, no folder made); after the holder is killed the next run passes | unit with `subprocess` holder | `uv run pytest tests/selftest/init -k lock -q` | Wave 0 |
| INIT-02 | Marker: absent after a FAIL, present after all OK, removed at the start of a rerun that then FAILs | unit | `uv run pytest tests/selftest/init -k marker -q` | Wave 0 |
| INIT-03 | The deleted files are gone and nothing names them | shell | `test ! -e base/sbx-entrypoint && test ! -e base/sbx-start-lib.sh && test ! -e base/bin/sbx-link-bundle && test ! -d claude/start.d && test ! -d cursor/start.d && test ! -d tests/selftest/entrypoint && ! grep -rIn 'sbx-entrypoint\|start\.d\|wait_until_ready\|wait_for_start_hooks\|sbx-start-lib\|sbx-link-bundle' base claude cursor bin build.sh host-test.sh compose.yml tests` | Wave 0 (as a guard rule) |
| INIT-03 | Guard rules: no `ENTRYPOINT` in the three Dockerfiles; compose has no `entrypoint:` key; the remaining 18 or so rules pass with the new globs | guard | `bash tests/guard/run-all.sh` | partly Wave 0 (new rules) |
| INIT-03 | Host scripts work without the start library: name rule refusals, folder refusals | sbx self-test | `bash tests/selftest/sbx/run-all.sh` | exists |
| INIT-03 | Mac: the test container has an empty entrypoint and runs only tini and `sleep infinity` | host (H-28 assertion) | `./host-test.sh` (checks `docker inspect -f '{{.Config.Entrypoint}}'` prints `[]`) | Wave 0 edit |
| INIT-04 | Wrapper without marker: exit 1, message names `sbx-init`, the stand-in agent never runs, returns at once (no sleep) | unit (subprocess, `SBX_INIT_MARKER` and `SBX_AGENT_BIN_DIR` pointed into `tmp_path`, a stand-in `claude` that writes a file) | `uv run pytest tests/selftest/init -k wrapper -q` | Wave 0 |
| INIT-04 | Wrapper with marker: passes arguments, the child sees `command -v claude` succeed, the parent shell PATH is not changed; both wrappers name the same marker literal as `paths.INIT_MARKER_FILE` | unit | same | Wave 0 |
| INIT-04 | Self-check: agent-not-on-path and tool checks with the agents folder on a scoped PATH; marker check; counts 55 and 53 | pytest | `uv run pytest tests/selftest/selfcheck -q` | edits to existing files |
| INIT-04 | Mac, real image: `claude` and `cursor-agent` not found in a plain `docker exec ... bash -c 'command -v claude'`; `sbx-claude --version` before init exits non-zero naming `sbx-init`; after init it prints the pin | host (H-27 in-container script, H-34) | `./host-test.sh` | Wave 0 edit |
| INIT-05 | A user folder named like a bundle skill survives with its content; the step FAILs naming it and the fix; every other skill is still linked; an own link is replaced; a stale own link (dangling) is removed; a link elsewhere, a copied folder and a `gsd-*` real folder are left; no call to a recursive delete | unit | `uv run pytest tests/selftest/init -k bundle -q` | Wave 0 |
| INIT-05 | Rules link follows the same rule; Cursor never touches `rules` | unit | same | Wave 0 |
| INIT-05 | Mac: H-16 plants a user skill with a bundle name, runs `sbx-init`, asserts FAIL and the planted file intact | host | `./host-test.sh` | Wave 0 edit |
| INIT-06 | Scan finds entries of the stand-in owner uid, skips `cache/npm`, `cache/uv`, `m2`, never follows links; `lchown` called on each; a failing `lchown` FAILs with the Mac fix hint; a real `chown` to uid 0 as non-root raises `PermissionError` and surfaces as FAIL | unit (injected chown plus one real-syscall failure case) | `uv run pytest tests/selftest/init -k owner -q` | Wave 0 |
| INIT-06 | Self-check no longer tolerates `gsd-core`, `hooks`, `scripts` | pytest | `uv run pytest tests/selftest/selfcheck -k root_owned -q` | edit |
| INIT-06 | Mac: after `sbx-init` every path under `state/claude` is owned by `sandbox` (self-check `no-root-owned-state` passes); H-35 plants a root-owned file first | host | `./host-test.sh` | Wave 0 (new H-35) |

### Manual host-side steps (Mac, Docker Desktop, cannot run in the dev sandbox)

1. `./host-test.sh`, then read `host-test.log`. The summary ends with one OK or FAIL line per step; every step must be OK (success criterion 5). It builds `sbx-base:test`, `sbx-claude:test`, `sbx-cursor:test` and never touches the `:local` images.
2. In the host-test run, confirm in the log: H-27 shows the refusal before init and the pin printed after; H-34 shows `sbx-init` output with all OK lines and the self-check counts 55 and 53 with no FAIL; H-35 shows the owner back to `sandbox`.
3. By hand on a real sandbox after `sbx-upgrade NAME`: `sbx-shell NAME`; `claude` prints `command not found`; `sbx-claude` prints `run sbx-init`; `sbx-init` prints OK lines and the verify hint; run `sbx-init` again and compare the output; `sbx-selfcheck` shows no FAIL; `sbx-claude` starts and `/gsd-review` finds `claude`; `ls -ln ~/workspace/state/claude | awk '$3 == 0'` prints nothing. Open a second shell and run `sbx-init` in both at once: one prints the lock FAIL. `sbx-stop` then `sbx-start` keeps the marker; `sbx-upgrade` wipes it.
4. A1 specifically: on the Mac, after init, `docker exec sbx-NAME find /home/sandbox/workspace/state -user root` prints nothing.

### Sampling Rate
- **Per task commit:** `uv run pytest tests/selftest/init tests/selftest/selfcheck -q` (seconds) plus `bash tests/guard/run-all.sh` when a Dockerfile, shell file, glob or managed setting changed (about 9 s)
- **Per wave merge:** `uv run pytest -q && bash tests/guard/run-all.sh && bash tests/selftest/sbx/run-all.sh`
- **Phase gate:** the full dev-sandbox suite green, then `./host-test.sh` green on the Mac, before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `tests/selftest/init/` with `conftest.py`, `init_helpers.py` (stub `gsd-core`, stub agent, tree builders; unique names, Pitfall 8)
- [ ] One test file per library and per step file (`test_init_runner.py`, `test_init_state_folders.py`, `test_init_gsd_sync.py`, `test_init_bundle_link.py`, `test_init_state_owner.py`, `test_init_self_update.py`, `test_init_wrappers.py`, `test_init_inventory.py`, `test_init_launcher.py`)
- [ ] `pyproject.toml`: `pythonpath` gains `base/init`; `testpaths` gains `tests/selftest/init`
- [ ] New guard rules: no `ENTRYPOINT` in the Dockerfiles, no `entrypoint:` in compose, agents not linked into `/usr/local/bin` (optional; tests/README.md asks for a real failure each rule would catch, and the PATH rule would have caught a regression of D-19)
- [ ] New host check H-35 and edits to H-16, H-27, H-28, H-34, `compose_up`
- [ ] Framework install: none (pytest 9.2.0 already locked in `uv.lock`)

## Security Domain

`security_enforcement` is enabled (key absent in `.planning/config.json` workflow block means enabled; `security_asvs_level` is 1).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Not touched; logins stay in `state/` |
| V3 Session Management | no | Not touched |
| V4 Access Control | yes | Agent binaries and init code are root-owned and not writable by the sandbox user (`/opt/sbx/agents`, `/usr/local/lib/sbx-init`, `/etc/sbx/init.d`), enforced by the self-check ownership and protected-paths checks; `cap_drop: ALL`, `no-new-privileges` unchanged in `compose.yml` [VERIFIED: compose.yml:27-30] |
| V5 Input Validation | yes | `SBX_STATE_DIRS` names rejected when absolute or containing `..`; skill names from directory listings filtered like the self-check (no leading dot); `cli-config.json` parsed with `json`, non-objects refused; no shell string building (argument lists only) |
| V6 Cryptography | no | The extra root certificate path is unchanged (Pitfall 3 exists to keep it working) |
| V12 Files and Resources | yes | `lchown` and `unlink` never follow links; no recursive delete; links created with fixed relative text |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Agent plants a symlink in `state/` aimed outside to make init chown or delete a target | Tampering | `walk_tree` does not follow links, `os.lchown`, `Path.unlink` on the link itself only |
| Agent tampers with the marker or the lock to skip init | Spoofing | Not a security boundary (D-20 says so); the marker only gates a convenience wrapper |
| A user or agent replaces `claude` ahead of the wrapper | Tampering | The agents folder is root-owned; `tool-claude` check reports a copy under `/home` and the not-on-path check reports a plain-PATH `claude` |
| Compromised GSD package | Tampering, supply chain | `@opengsd/gsd-core` pin only; guard `no_compromised_gsd_package` and `gsd_installs_only_the_official_package` stay; init calls the installed `gsd-core`, never `npx` or `@latest` |
| Two inits racing on the same state | Tampering (own data) | `flock` (INIT-02) |

## Sources

### Primary (HIGH confidence)
- This repository, read in full this session: `09-CONTEXT.md`, `09-DISCUSSION-LOG.md`, REQUIREMENTS.md, ROADMAP.md, STATE.md, `.claude/CLAUDE.md`, `base/sbx-entrypoint`, `base/sbx-start-lib.sh`, `claude/start.d/*`, `cursor/start.d/*`, `base/bin/sbx-link-bundle`, `base/bin/sbx-bundle-clone`, `claude/bin/sbx-claude`, `cursor/bin/sbx-cursor`, the three Dockerfiles, `compose.yml`, `bin/sbx-lib.sh`, `bin/sbx-start`, `bin/sbx-upgrade`, `bin/sbx-shell`, `host-test.sh`, `tests/host/*` (lib-sandbox, run-all, h10, h12, h16, h17, h20, h27, h34, lib-bundle, host-checklist), `tests/guard/*`, `tests/selftest/*`, `tests/README.md`, `base/selfcheck/*` (runner, check_result, launcher, paths, users, tree_walk, bundle_links, agent_config, hints, image_roots, image_ownership, protected_paths, commands, tools, checks 010-070, 110-120, 140, 210, 250-270), `claude/selfcheck/*`, `cursor/selfcheck/*`, pending todos for the four folded items, README.md sections.
- Local probes this session: `uv run pytest` (272 passed), guard (all 20 rules pass), sbx and entrypoint self-tests (pass), `gsd-core --claude --global --config-dir` (exit 0, offline, VERSION 1.15.0), two-process `flock` probe, `os.lchown` on a dangling link, `os.chown` to uid 0 as non-root (`PermissionError`), `npm config get globalconfig` with and without `--prefix`, `npm view @anthropic-ai/claude-code@2.1.285 bin scripts optionalDependencies`.
- `$HOME/workspace/state/claude/gsd-core/workflows/review.md` (the `command -v claude` and `command -v cursor-agent` lines in the CLI detection block).

### Secondary (MEDIUM confidence)
- docs.docker.com compose up reference, fetched this session: `--wait` text "Wait for services to be running|healthy. Implies detached mode." The behaviour with no healthcheck is not spelled out there.
- `.planning/todos/pending/2026-11-08-gsd-sync-leaves-root-owned-files.md` for the Docker Desktop ownership mechanism (recorded observation, not re-run).

### Tertiary (LOW confidence)
- pytest import-mode collision behaviour, from memory (A8). Claude Code behaviour with an off-PATH binary (A4).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, stdlib only and probed
- Architecture: HIGH for init, steps, wrappers and the deletion inventory (all read from the repo); MEDIUM for A1 (Docker Desktop ownership) and A3
- Pitfalls: HIGH for 1, 2, 3, 4, 5, 7, 9, 12, 13 (found by reading or probing); MEDIUM for 6, 8

**Research date:** 2026-11-16
**Valid until:** 2026-12-16 (stable; revisit only if `versions.env` pins for GSD, Claude Code or Cursor change the install layout)
