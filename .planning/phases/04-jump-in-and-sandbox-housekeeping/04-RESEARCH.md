# Phase 4: Jump-In and Sandbox Housekeeping - Research

**Researched:** 2026-11-07
**Domain:** Plain bash host scripts (bash 3.2 and BSD tools on macOS) driving Docker Compose and `docker exec`
**Confidence:** HIGH for the code seams and test patterns (read this session); MEDIUM for Docker and macOS behaviour that cannot run in the dev sandbox (no Docker here)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Jump-in
- **D-01:** The command is `sbx-shell NAME`. It only opens a shell. A sandbox that is stopped or has no container goes through the same steps as `sbx-start` (name check, registry entry, folder check, image check, `compose up -d --wait`, wait for the start hooks), then `docker exec -it -w /home/sandbox/workspace/NAME sbx-NAME bash`. A running sandbox gets the `docker exec` only.
- **D-02:** No host command launches Claude. The flow is `sbx-shell demo`, then `sbx-claude` in that shell. SCR-04 in `.planning/REQUIREMENTS.md` and Phase 4 success criterion 2 in `.planning/ROADMAP.md` now say this.
- **D-03:** A running sandbox on an older build of `sbx-claude:local` (for example after `sbx-upgrade` of another sandbox) is entered as it is: no recreate, no message. Why: entering must never close the other shells and Claude sessions in that sandbox, and a message adds code for little value. The older image is shown by `sbx-list` instead (D-06).
- **D-04:** The start steps are shared with `sbx-start`, not copied (a function in `bin/sbx-lib.sh`, or `sbx-shell` calling `sbx-start`; the planner picks). `sbx-start`'s closing hint ("open a shell with: docker exec ...") becomes `sbx-shell NAME`.

### List
- **D-05:** `sbx-list` takes no arguments. It prints one row per registry entry: name, host path, status. Status is one of `running`, `stopped`, `no container`, read from Docker for the container `sbx-NAME`, so it matches `docker ps -a`.
- **D-06:** A running sandbox whose container image differs from the current `sbx-claude:local` is marked as on an older image (wording is the planner's). The comparison is the one `warn_if_older_image` in `bin/sbx-start` already does; it moves to `bin/sbx-lib.sh` so both use one copy.
- **D-07:** After the table, a second section lists containers that carry the `sbx.name` label but have no registry entry (for example a registry file deleted by hand, or the host test sandbox `sbx-hosttest`). It is printed only when there is at least one. Containers are found by the label, so the old `cc_*` containers never show up.

### Remove
- **D-08:** `sbx-rm NAME` runs `docker compose down` for that sandbox: container and network go. Never `-v` and never `--rmi`; the images stay for the other sandboxes.
- **D-09:** A running sandbox is removed without a prompt, after the `warn_sessions_close` line. Why: nothing on disk can be lost, and `sbx-upgrade` already recreates without asking.
- **D-10:** `--unregister` also deletes the registry file `~/.config/sbx/sandboxes/NAME`, and only after `compose down` succeeded. When `down` fails, the entry stays.
- **D-11:** `sbx-rm` never reads, writes or deletes anything under `SBX_DIR`. It always ends with one line saying nothing in `SBX_DIR` was changed (same style as `sbx-stop`).
- **D-12:** Re-registering the same path with `sbx-add NAME HOST_PATH` after `--unregister` brings back the login and history. `sbx-add` already accepts an existing folder; a host check proves the full round trip on the Mac.

### Claude's Discretion
- Exact output layout of `sbx-list` (columns, alignment, the older-image marker text) and the error wording of all three scripts.
- How `sbx-list` shows a registry entry it cannot read (an error in its row is preferred over failing the whole list).
- What `sbx-rm` does on a registered sandbox that has no container (succeed quietly is fine), and whether `sbx-list` prints a `docker rm` hint for unregistered leftovers.
- How the host checks prove the scripts (test registry via `SBX_CONFIG_DIR`, paths with spaces, bash 3.2), following the Phase 3 host checks.

### Deferred Ideas (OUT OF SCOPE)
None. Discussion stayed within phase scope.

Reviewed todos (not folded): six pending todos matched on generic keywords only (bundle hook, `sbx-bundle-clone`, `sbx-claude`'s wait, `sbx-gh-login`, the shell diet). None covers jump-in, list or remove.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCR-04 | One command jumps into a sandbox: it starts the sandbox if needed, then opens a shell. Claude is started from that shell with `sbx-claude` | `sbx-shell` design (Pattern 1), shared `bring_up_sandbox` in the lib, `docker exec -it` semantics, selftest group `shell.sh`, host check H-31 |
| SCR-05 | The user can list all registered sandboxes with their host path and running status | `sbx-list` design (Pattern 2), one `docker ps -a --filter label=sbx.name` call, shared `runs_older_image`, selftest group `list.sh`, host check H-31 |
| SCR-06 | The user can remove a sandbox's container (and optionally its registration) without touching its workspace or state | `sbx-rm` design (Pattern 3), guard rule rewrite (Pitfall 1), selftest group `rm.sh`, host check H-32 |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Sources read this session: `/home/sandbox/GetShitDoneContainer/.claude/CLAUDE.md`, `~/.claude/AGENTS.md`, `~/.claude/code-conventions.md`, and the memory index.

- GSD comes only from `@opengsd/gsd-core`; never `get-shit-done-cc` or `gsd-build` (a guard rule scans bin/ and the test trees for them).
- Docker is not available in the dev sandbox: every behaviour that touches Docker needs a host-side verification step on the Mac.
- Old layout stays untouched until Phase 5. The guard rule `old_layout_untouched` diffs `ClaudeCode`, `OpenCode` **and `README.md`** against a fixed commit, so Phase 4 must not edit `README.md`. Docs go in `SANDBOX.md`.
- Shell scripts: short, plain bash, stock bash 3.2 and BSD tools (the user's Mac). No GNU-only flags, no bash 4 features (`mapfile`, associative arrays, `${x,,}`).
- Script layout: 80-column banners, a title with at most two "why" lines, functions, a `Main / Entry Point` section, `set -eu`, camelCase locals, full names, collection suffixes (`xList`), braces always, blank line before and after every `if`/`for`/`while`/`case` block, imperative over pipeline chains.
- Comments: no planning IDs (`D-04`, `SCR-05`, phase numbers) in committed source, fixtures or READMEs; no "was X" history comments; ASCII only; no doc-comments unless asked (the repo's banner convention is the exception already in use).
- Prose in every artifact (SANDBOX.md, tests docs, PR text): no em/en dash, no ASCII `--` as a dash; use `;` `:` or parentheses. Literal flags such as `--unregister` stay. Punctuation goes outside closing quotes.
- Docs match their neighbours: short, schematic (tables), docs follow code.
- Git: branch from the updated target, feature branch per change, human merges, `git push` needs explicit approval; planning files, `.claude/` and code never share a branch or PR.
- New files created in the sandbox land as mode 644; `bin/sbx-shell`, `bin/sbx-list`, `bin/sbx-rm` must be 100755 in the git index (see Pitfall 6).

## Summary

Phase 4 adds three scripts next to the Phase 3 ones and moves two pieces into `bin/sbx-lib.sh`. Almost everything needed already exists in the lib: `sbx_init`, `check_name`, `read_registry_entry`, `check_sandbox_folders`, `require_images`, `run_compose`, `sandbox_is_running`, `warn_sessions_close`, `wait_until_ready`. The new work is (a) one lib function that bundles the start steps so `sbx-start` and `sbx-shell` share them, (b) one lib predicate for "running on an older image" so `sbx-start` and `sbx-list` share it, (c) the three scripts, (d) a rewrite of one guard rule that sbx-rm would otherwise break, (e) three selftest groups plus an extended stand-in docker, (f) two host checks and doc updates.

The single largest planning trap is the guard rule `host_scripts_keep_sandbox_data`. It greps every file in `bin/` for `\b(rm|rmdir|prune|kill|down)\b|--volumes`. That matches `sbx-rm` as plain text (`-` is a word boundary), `compose ... down`, and `rm -- "$entryFile"`. Verified this session by running the regex on sample lines; every one matched. The rule must be rewritten to exempt exactly `bin/sbx-rm` from the broad check and give that one file a narrower, stricter check, and the guard self-test must plant the new violations. No other `bin/` script may contain the words `rm`, `down`, `kill`, `prune` or `rmdir`, so the list hint for unregistered leftovers must not say "docker rm".

The second trap is the interactive `docker exec -it`. It must not read `</dev/null` (every other docker call in the lib does), and it should be the last command of `sbx-shell` via `exec`, so the shell's exit status and signals pass straight through. The sbx self-test harness closes stdin, so a terminal check inside `sbx-shell` would make the start path untestable; leave the TTY complaint to Docker.

**Primary recommendation:** Put `bring_up_sandbox NAME` (folders, image, older-image warning, `up -d --wait`, wait) and `runs_older_image NAME` in `sbx-lib.sh`; write `sbx-shell` as name check, registry read, "if not running then bring_up", then `exec docker exec -it -w ... bash`; write `sbx-list` from one `docker ps -a --filter label=sbx.name` call; write `sbx-rm` around `run_compose NAME down` with the `rm` of the registry entry as its only deletion; rewrite the guard rule before the first commit that adds `bin/sbx-rm`.

## Architectural Responsibility Map

The "tiers" here are the Mac shell, Docker, and the container; there is no web tier.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Registry of sandboxes (name, folder, agent) | Mac filesystem (`~/.config/sbx/sandboxes/NAME`) | none | Outside every mount on purpose, so no agent can change which folder a start mounts |
| Start steps (folder check, image check, up, wait) | Mac shell (lib function) | Docker Compose | Checks run before Docker so a bad entry never reaches it |
| Interactive shell | Docker CLI (`docker exec -it`) | Container (`bash`) | TTY allocation and exit status are the Docker CLI's job; the script only hands over with `exec` |
| Status of a sandbox (running, stopped, no container) | Docker (`docker ps -a`) | Mac shell formats it | Docker is the source of truth; no state is cached on the Mac |
| Older-image detection | Docker (`container inspect` vs `image inspect`) | Mac shell compares ids | Same comparison `sbx-start` already uses |
| Container removal | Docker Compose (`down`, project `sbx-NAME`) | Mac shell | Scoped by `-p`; never touches the bind-mounted folder |
| Unregister | Mac filesystem (`rm` of one registry file) | none | The only deletion in `bin/`, after `down` succeeded |
| Login and history persistence | Mac folder `SBX_DIR/state` via the bind mount | none | Untouched by `down`; a re-register points the next container at the same folder |

## Standard Stack

No packages are installed in this phase. The "stack" is what is already in the repo and on the Mac.

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | 3.2 on the Mac (`/bin/bash`), 5.3 in the dev sandbox [VERIFIED: `bash --version` this session: GNU bash 5.3.9] | Script language | Project constraint; scripts run with the Mac's stock bash |
| `docker` CLI, `docker compose` v2 | Docker Desktop; H-00 requires Compose major 2 or higher | Container lifecycle | The only runtime; `run_compose` already wraps it |
| `bin/sbx-lib.sh` | repo | Registry, name rule, scoped Compose, start wait | Every Phase 3 script sources it |
| `tests/selftest/lib-expect.sh` and `tests/selftest/sbx/lib.sh` | repo | `expect`, `has_text`, `lacks_text`, `run_sbx`, `make_scripted_docker`, `plant_entry` | The Phase 3 test pattern the new groups extend |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `script` (BSD, `/usr/bin/script` on macOS) | Gives `sbx-shell` a pty inside the unattended host check | Only in H-31; see Assumption A1 and Open Question 2 |
| `tests/host/lib-sbx.sh` (`sbx_test_setup`, `run_sbx`, `restore_test_sandbox`, `sandbox_field`) | Test registry in the run folder, `/bin/bash` on PATH, restore of the test sandbox | Both new host checks |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shared lib function for the start steps | `sbx-shell` calling `sbx-start` | `sbx-start` prints its "is running" lines and the hint, and its older-image warning would fire for nothing. A lib function keeps `sbx-shell` quiet and is the better design (D-04 allows either) |
| `column -t` for the table | `printf` with fixed widths | `column` is not guaranteed in minimal Linux images and splits on spaces in paths. Name is at most 31 characters, so fixed `%-31s` is exact |
| One `docker ps` call | One `docker container inspect` per sandbox | One call is faster, and the same call yields the unregistered leftovers (D-07) |

**Installation:** none. **Version verification:** not applicable (no registry packages).

## Package Legitimacy Audit

Not applicable: this phase installs no external packages (bash scripts and docs only). `gsd-tools query package-legitimacy check` was not run because there is nothing to check. **Packages removed due to SLOP:** none. **Packages flagged SUS:** none.

## Architecture Patterns

### System Architecture Diagram

```
                          ~/.config/sbx/sandboxes/NAME   (registry, outside every mount)
                                      |
   sbx-shell NAME ---> check_name ---> read_registry_entry ---> entryDir
        |                                                         |
        |  sandbox_is_running? (docker container inspect)         |
        |-- no --> bring_up_sandbox --------------------------+   |
        |            check_sandbox_folders (NAME/, state/)    |   |
        |            require_images (sbx-claude:local)        |   |
        |            warn_if_older_image  (no-op here)         |   |
        |            run_compose up -d --wait   ---> Docker   |   |
        |            wait_until_ready (pgrep -x sleep)         |   |
        |<---------------------------------------------------+   |
        '-- yes or after start --> exec docker exec -it -w /home/sandbox/workspace/NAME sbx-NAME bash
                                   (stdin is the terminal; exit status and signals pass through)

   sbx-list ---> docker ps -a --filter label=sbx.name --format '{{.Names}} {{.State}}'  (one call)
        |             |
        |             +--> for each registry entry: look up "sbx-NAME" -> running | stopped | no container
        |                    running? -> runs_older_image NAME -> mark
        '--> labelled containers with no registry file -> second section (only when any)

   sbx-rm NAME [--unregister] ---> check_name ---> read_registry_entry
        |-- running? --> warn_sessions_close line
        |-- run_compose NAME down   (no -v, no --rmi)  ---> Docker removes container + network
        |-- --unregister and down succeeded --> rm -- "$entryFile"   (the only deletion in bin/)
        '-- "nothing in SBX_DIR was changed"
```

### Recommended Project Structure
```
bin/
  sbx-lib.sh      # + runs_older_image, bring_up_sandbox (start_sandbox moves here)
  sbx-start       # uses bring_up_sandbox; hint line becomes: sbx-shell NAME
  sbx-shell       # new
  sbx-list        # new
  sbx-rm          # new
tests/selftest/sbx/
  lib.sh          # scripted docker gains: ps lines, exec -it status, compose failure knob
  shell.sh  list.sh  rm.sh      # new groups (run-all.sh picks up every *.sh)
tests/guard/isolation.sh        # host_scripts_keep_sandbox_data rewritten
tests/selftest/guard/sandbox-rules.sh   # new planted cases for the rewritten rule
tests/host/h31-sbx-shell-list.sh  h32-sbx-rm.sh   # new, chain after h29
tests/host/run-all.sh, tests/host-checklist.md, tests/README.md, host-test.sh (comment)
SANDBOX.md                      # command table, "Start, enter, stop", "What the scripts run"
```

### Pattern 1: shared start steps and `sbx-shell`

**What:** Move `start_sandbox` from `bin/sbx-start` into the lib and add one function that runs the whole sequence after the registry read. `sbx-start` and `sbx-shell` both call it.

**When to use:** every script that must leave a sandbox running and ready.

**Existing code this is built from** (quoted verbatim, read this session):

`[VERIFIED: bin/sbx-start:31-32]`
```bash
  runningImage=$(docker container inspect --format '{{.Image}}' "sbx-$1" 2>/dev/null </dev/null) || return 0
  currentImage=$(docker image inspect --format '{{.Id}}' "$claudeImage" 2>/dev/null </dev/null) || return 0
```

`[VERIFIED: bin/sbx-start:52-62]` the current Main block: `sbx_usage 'NAME'`, `sbx_init`, `check_name`, `read_registry_entry`, `check_sandbox_folders`, `require_images`, `warn_if_older_image`, `start_sandbox`, `wait_until_ready`, then the two `echo` lines, the second being `echo "sbx-start: open a shell with: docker exec -it -w /home/sandbox/workspace/$1 sbx-$1 bash"`.

**Example (sketch for the lib; follow banner style):**
```bash
# runs_older_image NAME: true when sbx-NAME runs on an image older than claudeImage
# A missing container, a stopped one, or a failed inspect is false (no marker, no warning).
runs_older_image() {
  local runningImage
  local currentImage

  if ! sandbox_is_running "$1"; then
    return 1
  fi

  runningImage=$(docker container inspect --format '{{.Image}}' "sbx-$1" 2>/dev/null </dev/null) || return 1
  currentImage=$(docker image inspect --format '{{.Id}}' "$claudeImage" 2>/dev/null </dev/null) || return 1

  [ "$runningImage" != "$currentImage" ]
}

# bring_up_sandbox NAME: folders, image, older-image warning, up, wait
bring_up_sandbox() {
  check_sandbox_folders "$1" || return 1
  require_images "$1" || return 1

  if runs_older_image "$1"; then
    warn_sessions_close "$1" "runs on an older image; recreating it on the new one"
  fi

  if ! run_compose "$1" up -d --wait; then
    sbx_error "docker compose up failed; docker logs sbx-$1 shows why"
    return 1
  fi

  wait_until_ready "$1"
}
```
Keep the warning text byte for byte: the existing selftest (`tests/selftest/sbx/start.sh`, `case_older_image`) asserts `sbx-older runs on an older image; recreating it on the new one will close its open shells and Claude sessions` and that the warning comes before `standin: compose`.

**`sbx-shell` Main (sketch):**
```bash
open_shell() {
  exec docker exec -it -w "/home/sandbox/workspace/$1" "sbx-$1" bash
}

[ "$#" -eq 1 ] || sbx_usage 'NAME'
sbx_init
check_name "$1"
read_registry_entry "$1"

if ! sandbox_is_running "$1"; then
  bring_up_sandbox "$1"
fi

open_shell "$1"
```
Notes the planner must carry into tasks:
- The `if ! sandbox_is_running` suspends `set -e` only for the test, not for `bring_up_sandbox` in the body, so a failure in the body still ends the script. Do not write `bring_up_sandbox "$1" || exit` and do not call it inside an `if` test: errexit is off inside functions called in a test context.
- `exec` makes the docker CLI the process: the exit status of the shell is the script's exit status and Ctrl-C reaches the CLI directly. No `</dev/null` on this line. The banner of `sbx-shell` should say why it differs from every other docker call.
- The name check and registry read run even when the sandbox is already running (recommended; see Open Question 1) so only registered sandboxes can be entered and a bad name never reaches `-w`.
- `sbx-start` Main then reads: `sbx_init`, `check_name`, `read_registry_entry`, `bring_up_sandbox`, the "is running" line, and the hint `echo "sbx-start: open a shell with: sbx-shell $1"`.

### Pattern 2: `sbx-list`

**What:** One Docker call, then a loop over the registry. Path goes last so spaces in a path never break alignment.

**Docker call** [CITED: docs.docker.com/reference/cli/docker/container/ls/]: `--filter label=sbx.name` matches any container that has the label, whatever its value; `-a` includes created and exited; `.Names`, `.State` are valid placeholders; states are `created`, `running`, `paused`, `restarting`, `exited`, `removing`, `dead`. `\t` and `\n` in a format string are expanded for every format type [CITED: github.com/docker/cli cli/command/formatter/formatter.go `strings.NewReplacer(`\t`, "\t", `\n`, "\n")`], but a plain space separator needs no such knowledge and is safe because names follow `^[a-z][a-z0-9-]{0,30}$`.

The label exists on every sandbox container: `[VERIFIED: compose.yml:28-29]`
```yaml
    labels:
      sbx.name: "${SBX_NAME}"
```
and the container name is `[VERIFIED: compose.yml:14]` `container_name: "sbx-${SBX_NAME}"`. The label has been in `compose.yml` since its first commit (`git log -S'sbx.name' -- compose.yml` ends at 38b9e6a), so a label filter cannot miss a registered sandbox's container.

**Sketch:**
```bash
read_container_states() {
  if ! containerStateText=$(docker ps -a --filter label=sbx.name --format '{{.Names}} {{.State}}' </dev/null 2>/dev/null); then
    sbx_error "cannot read the container list from Docker; is Docker running?"
    return 1
  fi
}

# state_of NAME: prints running, stopped or "no container"
state_of() {
  local containerName
  local containerState

  while read -r containerName containerState; do
    if [ "$containerName" = "sbx-$1" ]; then
      if [ "$containerState" = "running" ]; then echo running; else echo stopped; fi
      return 0
    fi
  done <<EOF
$containerStateText
EOF

  echo "no container"
}
```
(Use real braces and blank lines per the project style; the one-line `if` above is a sketch only.)

Planner points:
- A failed `docker ps` must fail the command (exit 1, message). Treating a failure as "empty list" would print every sandbox as `no container`, which is wrong and dangerous. With the refusing stand-in (exit 99) this is directly testable.
- Status mapping per D-05: `running` stays `running`; every other state (`exited`, `created`, `dead`, `removing`) is `stopped`; no match is `no container`. `paused` and `restarting` also fall to `stopped` unless the planner chooses to show the raw state (Open Question 3). `docker ps -a` shows the raw word, so criterion 3 ("matches `docker ps -a`") holds for `running` vs `Exited`, which is what the host check compares.
- Older image: for a running sandbox call `runs_older_image NAME` (two inspect calls per running sandbox; fine for a handful). Append a marker to the status text; since PATH is the last column the status column can have a fixed width such as `%-26s`.
- Registry loop uses the pattern `sbx-add` already uses: `for entryPath in "$registryDir"/*; do if [ ! -f "$entryPath" ]; then continue; fi`. With an empty or missing registry folder the glob stays literal and the `-f` test skips it; print `no sandboxes registered; run: sbx-add NAME HOST_PATH` and exit 0.
- Unreadable entry: `read_registry_entry` writes its error to stderr and returns 1. Call it as `if read_registry_entry "$entryName" 2>/dev/null; then pathText=$entryDir; else pathText="(unreadable entry: $entryPath)"; fi`. Do not wrap it in `$(...)`: a subshell would lose `entryDir`. An entry file whose name breaks the name rule (hand-made file) gets the same row treatment via `check_name "$entryName" 2>/dev/null`.
- Leftovers (D-07): from the same `containerStateText`, every `sbx-X` whose registry file `$registryDir/X` does not exist. Print the section header only when at least one. Do not put the words `rm`, `down`, `kill` or `prune` in any `bin/sbx-list` text (Pitfall 1); a neutral header such as `containers with the sbx.name label and no registry entry (register one with sbx-add, or remove it with docker)` is fine.
- `sbx-list` takes no arguments: `[ "$#" -eq 0 ] || sbx_usage ''` (prints `Usage: sbx-list ` with a trailing space; a self-test `has_text` on `Usage: sbx-list` still matches. Planner may special-case to avoid the space).
- `sbx_init` must run before anything that uses `registryDir`; `sbx_usage` runs before `sbx_init` and uses `${scriptName:-${0##*/}}` already.

### Pattern 3: `sbx-rm`

**What:** `run_compose NAME down`, then optionally one `rm` of the registry file.

The call shape is fixed by the lib: `[VERIFIED: bin/sbx-lib.sh:188]`
```bash
  SBX_NAME="$sandboxName" SBX_DIR="$entryDir" docker compose --env-file /dev/null -p "sbx-$sandboxName" -f "$repoDir/compose.yml" "$@" </dev/null
```
So `run_compose "$1" down` scopes by project name `sbx-NAME`, takes `SBX_DIR` from the registry, and ignores any ambient `COMPOSE_*`/`SBX_*` (sbx_init unsets the former; the command line sets the latter).

`docker compose down` removes the service containers and the networks defined for the project, keeps anonymous volumes by default, removes named/anonymous volumes only with `-v` and images only with `--rmi` [CITED: docs.docker.com/reference/cli/docker/compose/down/]. This layout has no volumes, so plain `down` is exactly D-08.

**Sketch:**
```bash
parse_arguments "$@"                      # NAME, optional --unregister, either order; else usage exit 2
sbx_init
check_name "$sandboxName"
read_registry_entry "$sandboxName"

if sandbox_is_running "$sandboxName"; then
  warn_sessions_close "$sandboxName" "is running; removing it"
fi

remove_container "$sandboxName"           # if ! run_compose "$1" down; then sbx_error ...; return 1; fi

if [ "$unregister" = "yes" ]; then
  unregister_sandbox                      # rm -- "$entryFile" ; error + return 1 on failure
fi

echo "sbx-rm: ..."                        # one closing line: nothing in $entryDir was changed
```
Planner points:
- Do not call `check_sandbox_folders` or `require_images` in `sbx-rm`: removing a sandbox whose folder was moved or whose image was never built must still work. `down` only needs `SBX_DIR` non-empty for interpolation; earlier research recorded that it need not exist [CITED: .planning/phases/01-two-mount-claude-sandbox/01-RESEARCH.md:441, "For `down`, `SBX_DIR` need not exist"]; the host check should still prove it once (Assumption A3).
- Argument forms: `NAME`, `NAME --unregister`, `--unregister NAME`. Anything else is usage (exit 2). A name that starts with `-` is refused by `check_name`. Avoid arrays in the parser: with `set -u`, bash 3.2 treats `"${emptyArray[@]}"` as unbound.
- D-10 ordering is the point of the host check and a selftest: stand-in `compose` fails, `--unregister` given, expect exit 1, entry file still present, no "unregistered" line.
- D-11 closing line follows the `sbx-stop` style: `[VERIFIED: bin/sbx-stop:33]` `echo "sbx-stop: sbx-$1 is stopped; nothing in $entryDir was changed"`. For `--unregister` add a separate short line saying the registry entry file was deleted (it lives in the config folder, not in SBX_DIR).
- A registered sandbox with no container: `down` has nothing to do; the expectation is exit 0 (Assumption A2) and the same closing line, so a second `sbx-rm` is harmless.
- Unregistered leftover containers cannot be removed with `sbx-rm` (it needs the registry entry for `SBX_DIR`). That is acceptable: the list section tells the user to `sbx-add` it again or use docker directly (Open Question 4).

### Anti-Patterns to Avoid
- **`</dev/null` on the interactive exec:** it would make Docker refuse the TTY. Every other docker call in the lib keeps it.
- **A `[ -t 0 ]` check in `sbx-shell`:** the sbx selftest closes stdin for every script run (`run_sbx` in `tests/selftest/sbx/lib.sh` redirects `</dev/null`), so the start path could never be tested.
- **Treating a failed `docker ps` as an empty list** in `sbx-list`.
- **`down -v`, `--volumes`, `--rmi`, `--remove-orphans`** anywhere. `-v` is how the old layout lost data.
- **Reading or writing `entryDir` in `sbx-rm`** beyond printing it.
- **Calling `sbx-start` from `sbx-shell`:** double output, wrong hint, spurious warning.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Name validation | a new regex | `check_name` | The rule lives once in `base/sbx-start-lib.sh` and is read by `load_name_rule` |
| Registry parsing | `source` the entry or `cut` it | `read_registry_entry` | Reads text line by line; a value like `$(cmd)` is only a path that does not exist (selftest `case_read_as_data`) |
| Compose scoping | a direct `docker compose` call | `run_compose NAME ...` | `-p`, `--env-file /dev/null`, `SBX_NAME`/`SBX_DIR` on the one command, `</dev/null` |
| Running check | parsing `docker ps` for one name | `sandbox_is_running` | Missing container is false, not an error |
| Sessions warning | a new sentence | `warn_sessions_close NAME LEAD` | One wording for every recreate or removal |
| Start wait | a sleep loop | `wait_until_ready` | Already polls `pgrep -x sleep` and reports a container that died |
| Interactive exit status | a wrapper that captures `$?` | `exec docker exec -it ...` | The CLI returns the command's exit status [CITED: github.com/docker/cli cli/command/container/exec.go, `getExecExitStatus` returns `cli.StatusError{StatusCode: status}` for a non-zero status] |
| Table alignment | `column -t` | `printf` with fixed widths | Name max is 31 characters; path last needs no alignment |
| Fake docker in tests | a new harness | `make_scripted_docker` in `tests/selftest/sbx/lib.sh`, extended | The scripted stand-in already logs calls to `standin-calls` and follows files in `standin-state` |

**Key insight:** the phase is small because the lib already carries the hard parts (name rule, registry reading, scoped Compose, start wait). New code should be glue; anything that looks like new parsing or new Docker flags deserves a second look.

## Common Pitfalls

### Pitfall 1: the data guard rule rejects `sbx-rm` and every mention of it
**What goes wrong:** `bash tests/guard/run-all.sh` fails `host_scripts_keep_sandbox_data` as soon as `bin/sbx-rm` exists, and also if `bin/sbx-shell`, `sbx-list` or `sbx-lib.sh` contain the text `sbx-rm`, `rm`, or `down`.
**Why it happens:** `[VERIFIED: tests/guard/isolation.sh:38-40]`
```bash
host_scripts_keep_sandbox_data() {
  nowhere_matches '\b(rm|rmdir|prune|kill|down)\b|--volumes' bin/*
}
```
Run this session on sample lines, all matched: `Usage: sbx-rm NAME`, `rm -- "$entryFile"`, `run_compose "$1" down`, `# take down the box`, `remove with docker rm`.
**How to avoid:** Rewrite the rule in the same plan that adds `bin/sbx-rm`, before the commit that adds the file:
1. Every file in `bin/` except `bin/sbx-rm` keeps the current broad regex, so the rule still protects `sbx-stop`, `sbx-upgrade` and the lib. Those files must therefore never say `sbx-rm`, `rm`, `down` as words (including comments and error text). This is the reason the leftover hint in `sbx-list` and the `sbx-start` hint must be worded without them. If a mention is wanted later, widen the exemption deliberately.
2. `bin/sbx-rm` gets a narrower rule: no `rmdir`, `prune`, `kill`, `--volumes`, `--rmi`, `--remove-orphans`, no `down` followed by `-v`; and every command `rm` in it must be exactly `rm -- "$entryFile"` (match `(^|[^A-Za-z-])rm[[:space:]]` and require the `"$entryFile"` operand). The `(^|[^A-Za-z-])` prefix keeps `sbx-rm` in usage text from matching.
3. Keep the report style of `nowhere_matches` (prints hits, returns 1) and keep the rule count at 19 (modify in place, not a new rule) so `tests/README.md`'s "19 rules" stays true; if a second function is added, update that number.
4. Extend `tests/selftest/guard/sandbox-rules.sh` `case_host_script_rule`. Existing planted cases stay: `plant_case ... "bin/sbx-stop" append_scratch_line bin/sbx-stop 'run_compose "$1" down -v'` and `... bin/sbx-upgrade 'rm -rf "$entryDir"'` [VERIFIED: tests/selftest/guard/sandbox-rules.sh:148-149]. Add: clean copy passes with `bin/sbx-rm` present; `down -v` in sbx-rm fails; `--rmi` in sbx-rm fails; `rm -rf "$entryDir"` in sbx-rm fails; `rm -- "$entryDir"` in sbx-rm fails; the word `rm` planted in `bin/sbx-list` fails; `down` planted in `bin/sbx-shell` fails.
**Warning signs:** guard output `FAIL: host_scripts_keep_sandbox_data` listing `bin/sbx-...:NN:` hits.

### Pitfall 2: `README.md` is guarded
**What goes wrong:** editing `README.md` for the new commands fails `old_layout_untouched` (`git diff --quiet $OLD_LAYOUT_COMMIT -- ClaudeCode OpenCode README.md`) [VERIFIED: tests/guard/isolation.sh:45-48 and constant at :17].
**How to avoid:** document in `SANDBOX.md` only; README is rewritten in Phase 5 (DOC-01).

### Pitfall 3: `docker exec -it` without a terminal
**What goes wrong:** run from a pipe, cron, a CI job or the test runner, the Docker CLI refuses: `cannot attach stdin to a TTY-enabled container because stdin is not a terminal` [CITED: github.com/docker/cli cli/streams/in.go `CheckTty`]. Older CLIs word it `the input device is not a TTY`. A piped run of `sbx-shell` therefore starts the sandbox and then fails at the exec (exit 1).
**How to avoid:** accept it (documented, not guarded). Unit tests use the scripted stand-in, which does not care. The host check needs a pty (Pitfall 7).

### Pitfall 4: running is not ready
**What goes wrong:** a sandbox that is `running` for two seconds may still be inside its start hooks (GSD sync, bundle links). D-01 says a running sandbox gets only the exec, so a user entering immediately after another terminal's `sbx-start` could see an unfinished sync. `sbx-start` always waits, so this only affects a start made by plain `docker compose up` (which returns before the hooks finish; Phase 7 "Start readiness" addresses it).
**How to avoid:** follow D-01; note it in Open Question 5. Do not add a wait to the running path without the user's say.

### Pitfall 5: bash 3.2 and `set -u`
- `"${list[@]}"` on an empty array is an unbound-variable error in bash 3.2; use no arrays or guard them.
- No `mapfile`/`readarray`, associative arrays, `${var,,}`, `&>>`, `|&`, `coproc`.
- `local var=$(cmd)` hides the status of `cmd`; assign on a separate line.
- Here-strings and here-documents are fine; a `case` with unbalanced `)` inside `$( ... )` mis-parses on 3.2 (STATE records the same trap for H-27); keep `case` out of command substitutions.
- `printf '%-31s'` with a fixed number is fine; avoid `%-*s`.
- BSD tools: no `sed -i`, no `grep -P`, no `stat -c`, no `date -d`, `sort -V`.
- `[[ ... =~ $var ]]` with the pattern in a variable is already used by `check_name`.
Because this sandbox has bash 5.3 only, the Phase 3 practice stays: `./host-test.sh` runs the sbx selftest under the Mac's `/bin/bash` (tests/README.md says so).

### Pitfall 6: execute bit and `PATH`
**What goes wrong:** a file made with the Write tool is mode 644. `bin/` is on the user's PATH, so `sbx-shell` would answer `permission denied`, and the selftest (`bash "$BIN/script"`) would not notice. `[VERIFIED: git ls-files -s bin]` shows 100755 for `sbx-add`, `sbx-start`, `sbx-stop`, `sbx-upgrade` and 100644 for `sbx-lib.sh`.
**How to avoid:** `chmod +x bin/sbx-shell bin/sbx-list bin/sbx-rm`, then confirm `git ls-files -s bin` shows 100755 for all three before commit. H-28's `check_lookup` (`command -v sbx-add`) is the model; the new host checks should do the same for the three names. `sbx-lib.sh` stays 644.

### Pitfall 7: the host check cannot give `sbx-shell` a terminal
**What goes wrong:** `run-all.sh` runs every check with `</dev/null` and `run_timeout` starts its command with `"$@" &`, so a piped input cannot be attached at the call site.
**How to avoid:** let the pipe live inside the command: `run_timeout 120 env PATH="$sbxPath" bash -c 'printf "%s\n" "pwd > FILE" "exit" | script -q /dev/null "$0" "$@"' sbx-shell hosttest` (details to the planner). Assert on a file the shell writes into the project folder on the Mac (for example the output of `pwd`), not on the exit status or screen output: BSD `script` exit-status behaviour is version dependent (Assumption A1). Back it with a manual helper `tests/host/manual/h31-jump-in.sh` (needs a terminal, `require_terminal`) so the interactive path is also proven by a person. If `script` fails in the runner, the check should say so in its FAIL text rather than pass.

### Pitfall 8: the older-image id comparison
Compare `container inspect {{.Image}}` with `image inspect {{.Id}}` exactly as `warn_if_older_image` does. These ids were comparable on the user's Docker: H-28's `check_start_running` asserts "no older-image warning for a sandbox on the current image" with the comment "a false warning here would mean the ids are not comparable on this Docker" [VERIFIED: tests/host/h28-sbx-add-start-stop.sh, `check_start_running`], and Phase 3 closed with the Mac run green [CITED: .planning/STATE.md, Phase 3 entries]. `sbx-list` must therefore never mark a current-image sandbox; add that assertion to H-31 so list and start cannot disagree.

### Pitfall 9: planning IDs in committed text
Banners, comments, fixtures and the new host checks must not contain `D-04`, `SCR-05`, `Phase 4` and similar. State the reason self-contained, e.g. "the interactive exec keeps stdin; a closed stdin makes Docker refuse the terminal".

## Code Examples

### Extending the scripted stand-in (tests/selftest/sbx/lib.sh)
The existing stand-in is written line by line with `printf` into `$WORK/scripted/docker` and answers from `standin-state` files [VERIFIED: tests/selftest/sbx/lib.sh, `make_scripted_docker`]. Its `exec)` branch is `[ -f "$state/exec-ok" ]; exit $?` and its `compose)` branch always succeeds. Additions the three groups need:

| Need | Knob (file in `standin-state`) | Behaviour |
|------|-------------------------------|-----------|
| `docker ps -a ...` | `ps-lines` | `cat` the file; absent file means empty output; `ps-fail` present means exit 1 |
| `docker exec -it ...` exit status | `shell-status` | args containing `-it` exit with the file's number (default 0); the existing `exec-ok` still governs `pgrep` |
| `compose down` / `up` failing | `compose-fail` | compose branch exits 1 when present |
| per-call assertions | none | `standin-calls` already holds every call as `docker <args>` |

`set_standin_state` does `rm -f "$WORK/standin-state"/*` first, so a case sets extra knobs after calling it (a plain `echo 3 >"$WORK/standin-state/shell-status"`). `lib_eval`, `plant_entry`, `refused_cleanly`, `usage_printed`, `no_docker_call` and `appears_before` (currently local to `start.sh`; move to `lib.sh` when a second group needs it) are reused as they are.

### A selftest group skeleton (tests/selftest/sbx/shell.sh)
```bash
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-shell: refusals before Docker, the start path, the exec line
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

case_shell_start_paths() {
  SBX_CONFIG_DIR=$WORK/cfg-shell
  export SBX_CONFIG_DIR

  run_sbx demo sbx-add demo "$WORK/shell dir/demo"

  set_standin_state sha256:new "" "" yes            # no container
  run_sbx_scripted nocontainer sbx-shell demo
  expect "sbx-shell: no container starts it, then opens the shell" appears_before "$WORK/standin-calls" "compose" "exec -it -w /home/sandbox/workspace/demo sbx-demo bash"

  set_standin_state sha256:new sha256:old true yes  # running, older image
  : >"$WORK/standin-calls"
  run_sbx_scripted running sbx-shell demo
  expect "sbx-shell: a running sandbox gets the exec only" lacks_text "$WORK/standin-calls" "compose"
  expect "sbx-shell: an older image is entered without a message" lacks_text "$WORK/running.out" "older image"
}
```
Assertions to include: usage on 0 and 2 arguments (exit 2); path as name, uppercase name, unregistered name, missing project folder, missing `state/`, missing image (stand-in with `image` failing): all exit 1 with no `docker exec -it` line; `shell-status` 3 gives script exit 3; failing `compose up` gives no `exec -it`; a container that dies during the wait gives the existing "stopped during its start" error and no `exec -it`; the standing last assertion `no_docker_call` for the refusing fence.

### `sbx-list` self-test data
Stand-in `ps-lines`:
```text
sbx-alpha running
sbx-beta exited
sbx-stray running
```
with registry entries `alpha`, `beta`, `gamma` (no container), and one broken entry; expect rows `running`, `stopped`, `no container`, an error row, and a leftover section naming `sbx-stray`; with `sbx-stray` removed expect no leftover header. Paths with spaces round-trip. `ps-fail` gives exit 1 and no table.

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json` [VERIFIED: config read this session], so this section is required.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Plain bash harness: `expect NAME COMMAND...` printing `PASS:`/`FAIL:` lines, groups run by `run_groups`, no external framework |
| Config file | none; `tests/selftest/lib-expect.sh` and `tests/selftest/sbx/lib.sh` |
| Quick run command | `bash tests/selftest/sbx/run-all.sh` (about 1 s here; runs every `tests/selftest/sbx/*.sh` except `lib.sh` and `run-all.sh`) |
| Guard | `bash tests/guard/run-all.sh` (all rules pass here except the two linter rules, which FAIL as "not installed" in this sandbox; they pass on the Mac through `./host-test.sh`) |
| Guard self-test | `bash tests/selftest/guard/run-all.sh` (Linux sandbox only) |
| Full suite command | `./host-test.sh` on the Mac (host checks, guard with shellcheck and hadolint, sbx self-test under `/bin/bash`, log in `host-test.log`) |

Baseline measured this session: sbx selftest "All cases pass.", guard selftest "All cases pass.", guard 17 of 19 rules pass (shellcheck and hadolint absent).

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCR-04 | Usage (0 or 2 args, exit 2); bad name, unregistered, missing folders, missing image refused before any `docker exec -it` | selftest | `bash tests/selftest/sbx/run-all.sh` | Wave 0: `shell.sh` |
| SCR-04 | No container or stopped: compose up, wait, then `docker exec -it -w /home/sandbox/workspace/NAME sbx-NAME bash`; running: exec only, no compose, no older-image message | selftest | same | Wave 0 |
| SCR-04 | Exit status of the shell is the script's exit status; failed up or dead container means no exec | selftest | same | Wave 0 |
| SCR-04 | `sbx-start` prints `sbx-shell NAME` as the hint; its warning wording and order unchanged | selftest | same | extend `start.sh` |
| SCR-04 | Real stopped sandbox starts and a real bash opens in `/home/sandbox/workspace/hosttest`; running one is entered without recreate (same container id) | host | `bash tests/host/h31-sbx-shell-list.sh` (via `./host-test.sh`) | Wave 0 |
| SCR-04 | Interactive terminal path by a person | manual | `bash tests/host/manual/h31-jump-in.sh` | Wave 0 (diagnostic, not a gate) |
| SCR-05 | Three statuses from a scripted `docker ps -a`, path with spaces, header, empty registry message | selftest | `bash tests/selftest/sbx/run-all.sh` | Wave 0: `list.sh` |
| SCR-05 | Older-image marker only for a running container on a different image id; none for current, stopped, none | selftest | same | Wave 0 |
| SCR-05 | Unreadable entry becomes an error row; leftover section only when a labelled container has no entry; `docker ps` failure exits 1 and prints no table; arguments give usage exit 2 | selftest | same | Wave 0 |
| SCR-05 | Status equals `docker ps -a` for the test sandbox in all three states; current image is not marked; a labelled container with no entry is listed | host | `h31-sbx-shell-list.sh` | Wave 0 |
| SCR-06 | Usage and refusals; `down` called with the exact project scope and no `-v`, `--volumes`, `--rmi`; running warns first; folder files byte-identical before and after; closing line | selftest | `bash tests/selftest/sbx/run-all.sh` | Wave 0: `rm.sh` |
| SCR-06 | `--unregister` deletes only `NAME` in the registry folder, only after a successful down; failing down keeps the entry and exits 1; no container still succeeds; a second run succeeds | selftest | same | Wave 0 |
| SCR-06 | Rewritten data rule passes on the clean tree and fails on each planted violation | guard + guard selftest | `bash tests/guard/run-all.sh`, `bash tests/selftest/guard/run-all.sh` | modify `isolation.sh`, `sandbox-rules.sh` |
| SCR-06 | Real container and network gone; no volume appears or vanishes; sentinels in `NAME/` and `state/claude` intact; `sbx-add` of the same path, `sbx-start`, sentinels visible in the new container (login and history return) | host | `bash tests/host/h32-sbx-rm.sh` | Wave 0 |
| docs | New rows in `tests/host-checklist.md` and `tests/README.md`; `SANDBOX.md` command table lists seven scripts | review | n/a | modify |

### Sampling Rate
- **Per task commit:** `bash tests/selftest/sbx/run-all.sh` and `bash tests/guard/run-all.sh` (expect only the two linter FAILs here).
- **Per wave merge:** add `bash tests/selftest/guard/run-all.sh`, and `shellcheck --rcfile .shellcheckrc -S warning` on the new `bin/` files when a shell with shellcheck is available.
- **Phase gate:** `./host-test.sh` green on the Mac (it also runs the guard with both linters and the sbx selftest under `/bin/bash`), then `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `tests/selftest/sbx/shell.sh`, `list.sh`, `rm.sh`: new groups for SCR-04, SCR-05, SCR-06
- [ ] `tests/selftest/sbx/lib.sh`: scripted docker gains `ps`, `exec -it` status and compose-failure knobs; `appears_before` moves here from `start.sh`
- [ ] `tests/guard/isolation.sh` and `tests/selftest/guard/sandbox-rules.sh`: rule rewrite and planted cases (must land with, or before, `bin/sbx-rm`)
- [ ] `tests/host/h31-sbx-shell-list.sh`, `tests/host/h32-sbx-rm.sh`, `tests/host/manual/h31-jump-in.sh`
- [ ] `tests/host/run-all.sh` `chainCheckList`: insert both after `h29-sbx-upgrade.sh` (before `h20-mistyped-name-refused.sh`); they take the test sandbox down and must call `restore_test_sandbox` at the end, like H-28 and H-29
- [ ] Docs that count checks: `tests/host-checklist.md` (title and intro say H-00..H-30; table rows; the "chain" sentence in "Reading a failure"), `tests/README.md` (two places say H-30), `host-test.sh` comment "H-00 to H-30"
- Framework install: none.

### Host check design notes (for the plan)
- Reuse `sbx_test_setup H-31 h31` (registry inside `$RUN`, folder with a space, `/bin/bash` link first on PATH) and `run_sbx`, which exports bogus `SBX_DIR`, `SBX_NAME`, `COMPOSE_PROJECT_NAME` to prove the scripts ignore ambient values.
- The test sandbox `sbx-hosttest` already exists when the chain starts, and the user's real sandboxes also exist on the Mac. `sbx-list` output on a real machine therefore contains other lines; assert only on lines for `hosttest`, never on the whole output.
- State walk for H-31 (reuses the H-28 pattern): before `sbx-add` the test registry is empty, so `sbx-hosttest` shows in the leftover section; `compose_down`, `sbx-add`, list says `no container`; `sbx-shell` through `script` creates it and writes a marker file from inside the shell (`pwd`, plus the shell's own `exit`); list says `running`; `sbx-stop`, list says `stopped`; compare each with `docker ps -a --filter name=sbx-hosttest --format '{{.State}}'`; `sbx-shell` again on the running container and assert the container id is unchanged; finally `restore_test_sandbox h31`.
- H-32: register, start, plant sentinels in `NAME/` and `state/claude`, snapshot `docker volume ls` and other `sbx-` containers (copy `list_project_volumes` and `list_other_containers` from `h29-sbx-upgrade.sh`), `sbx-rm hosttest` (container gone, entry present, sentinels intact), `sbx-rm hosttest` again (exit 0), `sbx-rm hosttest --unregister` (entry gone, sentinels intact), `sbx-add hosttest <same path>`, `sbx-start`, read the sentinels from inside the container, then `restore_test_sandbox h32`. A failing `down` cannot be provoked on real Docker; D-10's failure branch is a selftest case.
- The host tests do not delete files (HT-02); do not use `rm` to reset the registry between steps. Order the steps so no reset is needed, or use a fresh `sbx_test_setup` prefix per scenario.

## Security Domain

`security_enforcement` is enabled (absent or true); `security_asvs_level` is 1 [VERIFIED: .planning/config.json].

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | none (local CLI) |
| V3 Session Management | no | none |
| V4 Access Control | yes | The container sees one mount; `sbx-rm` never touches it; the registry sits outside every mount and `sbx-add` refuses folders that overlap it |
| V5 Input Validation | yes | `check_name` (anchored regex, reserved names, multi-line names fail) before any path, container name or `-w` argument is built; the flag parser accepts exactly `--unregister` |
| V6 Cryptography | no | none |
| V12 Files and Resources | yes | `rm` only of `"$registryDir/$name"` with a validated name and `--`; guard rule pins the only `rm` operand to `"$entryFile"` |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command or path injection through the sandbox name (`../x`, spaces, `;`) | Tampering | `check_name` first in every script; names are interpolated only after it passes (selftest has "a path as a name is refused" for start, stop, upgrade; add it for the three new scripts) |
| Registry value executed (`SBX_DIR=$(cmd)`) | Elevation | Entries are read as text, never sourced; new scripts only call `read_registry_entry` |
| Deleting user data: `down -v`, `rm -rf` of the sandbox folder, `--rmi` | Tampering, Denial of service | No such flag in `bin/`; rewritten guard rule plus planted cases; D-11 closing line; host check compares sentinels before and after |
| `rm` follows a symlinked registry entry | Tampering | `rm` removes the link itself, never the target; the entry is a file in the user-owned config folder |
| Agent changes which folder a sandbox mounts | Elevation | Registry outside every mount (existing `sbx-add` overlap checks); unchanged here |
| Terminal escape sequences in a registry path printed by `sbx-list` | Spoofing | Not reachable by an agent (the registry is outside every mount); noted, no control added |
| Entering the wrong container because of a name collision | Spoofing | Name rule plus `sbx-` prefix; the registry gate (registered names only) before the exec |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `cc-bash.sh`: `docker exec -it cc_gsd_NAME /bin/bash`, no start step, no cwd | `sbx-shell NAME`: start if needed, `-w` project folder | this phase | Old layout stays until Phase 5 |
| Closing hint in `sbx-start` printing a raw `docker exec` line | Hint names `sbx-shell NAME` | this phase | SANDBOX.md "Start, enter, stop" text changes with it |
| One broad `bin/` delete rule | Broad rule for every script but `sbx-rm`, strict rule for `sbx-rm` | this phase | Needed to allow the one sanctioned deletion |

## Runtime State Inventory

Not a rename or migration phase; omitted. (The one runtime-state concern, that removing a container must leave login and history, is covered by H-32 and D-12.)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | BSD `script -q /dev/null CMD` on the user's macOS accepts piped stdin and gives the command a pty, so H-31 can drive `sbx-shell` unattended; its exit status is not relied on [ASSUMED] | Pitfall 7, Host check design notes | H-31 cannot reach the exec; fall back to the manual helper only, or have the check report "needs a terminal" and let the helper carry SCR-04 |
| A2 | `docker compose down` on a project with no container exits 0 [ASSUMED; the docs page does not state exit codes for missing resources] | Pattern 3 | `sbx-rm` of a never-started sandbox would error; fix by checking existence first (`docker container inspect`) and skipping `down`; the H-32 second `sbx-rm` run proves it |
| A3 | `docker compose down` does not require the registered `SBX_DIR` folder to exist [CITED: earlier phase research 01-RESEARCH.md:441, not re-run on Docker] | Pattern 3 | Cannot remove a sandbox whose folder was moved; add a host step that moves the folder aside before `sbx-rm` |
| A4 | Every non-`running` state shown by `docker ps -a` (`exited`, `created`, `dead`, `removing`, and the rare `paused`, `restarting`) should print as `stopped` | Pattern 2 | A paused sandbox reads "stopped" while `docker ps` says `paused`; planner may show the raw word (Open Question 3) |
| A5 | The Mac's `/bin/bash` 3.2 accepts every construct sketched here (here-document into `while read`, `printf '%-31s'`, `[[ =~ ]]`, `exec` in a function) [ASSUMED; only bash 5.3 ran here] | Pitfall 5 | Caught by the selftest run under `/bin/bash` in `./host-test.sh` |
| A6 | Docker Desktop on the user's Mac keeps `docker ps -a --filter label=sbx.name` output stable (one line per container, name without a leading slash) [ASSUMED from the docs; format fields verified, output not run] | Pattern 2 | Lookup by `sbx-NAME` fails; H-31's comparison with `docker ps -a` would show it at once |

## Open Questions

1. **Should `sbx-shell` read the registry when the sandbox is already running?**
   - What we know: D-01 says a running sandbox "gets the `docker exec` only"; the name check and registry entry are listed among the start steps.
   - What is unclear: whether "only" includes skipping the registry read.
   - Recommendation: always run `check_name` and `read_registry_entry` (cheap, no Docker call), so only registered sandboxes can be entered and the behaviour matches `sbx-stop`. Skip folder, image, compose and wait for a running sandbox. Say so in the plan so the discuss-phase owner can object.

2. **How hard should the host check try to cover the interactive exec?**
   - Recommendation: H-31 drives `sbx-shell` through `script` (marker file proves the working directory); the manual helper proves a real terminal. If A1 fails on the Mac, keep only the helper for the exec and let H-31 cover start-if-needed through `sbx-list` state changes plus a direct assertion that the container is running after a `script`-driven attempt.

3. **Show `paused` and `restarting` raw, or fold into `stopped`?**
   - Recommendation: fold into `stopped` (D-05 lists three values). Both states are rare for a `sleep infinity` container.

4. **Remove an unregistered leftover container?**
   - Recommendation: out of scope (`sbx-rm` needs a registry entry for `SBX_DIR`). The leftover section says to register it again with `sbx-add` or use docker directly, phrased without the guarded words.

5. **Wait for the start hooks when entering a running sandbox?**
   - Recommendation: no, per D-01; Phase 7 covers readiness. One sentence in SANDBOX.md is enough.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| docker / docker compose | all runtime behaviour, host checks | no, in the dev sandbox [VERIFIED: `docker: command not found`] | Mac only | Selftests with the stand-in docker; host checks on the Mac via `./host-test.sh` |
| bash | scripts, tests | yes | 5.3.9 here; 3.2 on the Mac [VERIFIED: `bash --version`] | Mac `/bin/bash` run through `./host-test.sh` |
| shellcheck, hadolint | guard linter rules | no here [VERIFIED: `command -v shellcheck` empty; guard prints "not installed"] | in `sbx-base` image | Run through `./host-test.sh` on the Mac |
| `script` (BSD) | H-31 pty | Mac only (assumed present at `/usr/bin/script`) | unknown | Manual helper (A1) |
| git | commits, mode check | yes | `git ls-files -s` works | none needed |

**Missing dependencies with no fallback:** none for planning. **With fallback:** Docker, linters, BSD `script` (all Mac-side).

## Sources

### Primary (HIGH confidence)
- Repo files read this session: `bin/sbx-lib.sh`, `bin/sbx-start`, `bin/sbx-stop`, `bin/sbx-add`, `bin/sbx-upgrade`, `compose.yml`, `claude/bin/sbx-claude`, `tests/guard/{run-all,lib,isolation,supply-chain,linters}.sh`, `tests/selftest/lib-expect.sh`, `tests/selftest/sbx/{lib,run-all,entry,start,upgrade}.sh`, `tests/selftest/guard/sandbox-rules.sh`, `tests/host/{lib,lib-sbx,lib-sandbox,run-all,h28,h29,h30}*.sh`, `tests/host/manual/{lib-manual,h29-upgrade-resume}.sh`, `tests/README.md`, `tests/host-checklist.md`, `SANDBOX.md`, `.planning/{REQUIREMENTS,STATE,config}`, 04-CONTEXT.md.
- Baselines run this session: `bash tests/selftest/sbx/run-all.sh`, `bash tests/selftest/guard/run-all.sh`, `bash tests/guard/run-all.sh`, and the guard regex against sample lines.
- docs.docker.com/reference/cli/docker/compose/down/ (what down removes; `-v`, `--rmi`, `--remove-orphans`)
- docs.docker.com/reference/cli/docker/container/ls/ (`--filter label=`, `--format` fields, states)
- docs.docker.com/reference/cli/docker/compose/up/ (`--wait` implies detached; recreate on changed config or image)
- github.com/docker/cli: `cli/streams/in.go` (`CheckTty` message), `cli/command/container/exec.go` (`getExecExitStatus`), `cli/command/formatter/formatter.go` (`\t` and `\n` expansion)

### Secondary (MEDIUM confidence)
- docs.docker.com/reference/cli/docker/container/exec/ (`-w`, `-i`, `-t`; silent on exit codes and non-terminal stdin)
- WebSearch: "the input device is not a TTY" reports (github.com/docker/docker issue 13052 and community write-ups) agree the failure is exit 1

### Tertiary (LOW confidence)
- BSD `script` behaviour on macOS with piped stdin and exit status: not looked up; Assumption A1.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, no new dependencies; everything is repo code read this session.
- Architecture: HIGH for the lib seams, scripts and test harness; MEDIUM for Docker runtime details that run only on the Mac.
- Pitfalls: HIGH for the guard conflict (reproduced), README guard, exec bit and TTY behaviour (source cited); MEDIUM for BSD `script`.

**Research date:** 2026-11-07
**Valid until:** 2026-12-07 (stable; Docker CLI behaviour cited is long-standing)
