# Phase 3: Remembered Sandboxes and One-Command Upgrade: Research

**Researched:** 2026-11-06
**Domain:** Host-side bash tooling (macOS stock bash 3.2) wrapping Docker Compose, plus a build-time version file in two Dockerfiles
**Confidence:** HIGH for the repo facts and the design; MEDIUM for Docker/Compose behaviour that only the Mac can prove (marked `[ASSUMED]` and covered by host checks)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Claude's Discretion
- Exact output and error wording of the scripts, and the usage lines.
- Where the version file sits in the image and how the shell prints it (`.bashrc` or `/etc/bash.bashrc` hook, interactive check).
- Whether `sbx-start` also waits for the start hooks (the host tests poll `pgrep -x sleep`), given Phase 7 later makes `up --wait` mean ready.
- How `sbx-upgrade` passes extra options (for example `--no-cache`) through to `build.sh`.
- How the host checks prove the scripts on the Mac (a test registry folder so the user's `~/.config/sbx` is never touched, spaces in the path, bash 3.2).

### Deferred Ideas (OUT OF SCOPE)
None. Discussion stayed within phase scope.

Reviewed todos (not folded): all 11 pending todos matched on generic keywords only ("sandbox", "claude", "host"). They cover the bundle hook, the bundle wrappers and the host tests, not the registry, upgrade or version printout, so none were folded.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCR-01 | Register a sandbox once with `sbx-add <name> <host_path>`; the registry records an agent field defaulting to `claude`; every other script takes only `<name>` | Registry format and parsing, name rule reuse, path validation, `sbx-add` order of operations, docker-free self-test |
| SCR-02 | Start and stop a sandbox by name | `run_compose` wrapper with explicit `-p`/`-f`, folder pre-check, `stop` semantics, host check H-28 |
| SCR-03 | One command rebuilds base and agent images and recreates the sandbox, keeping login and history | Upgrade flow ordering, `up -d --force-recreate --wait`, failed-build behaviour, host check H-29 and the attended helper |
| SCR-07 | Tool versions printed after a rebuild and on shell entry | Version file written at build time, `/etc/bash.bashrc` hook, `sbx-upgrade` prints it from the image, host check H-30 |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Sources: `./.claude/CLAUDE.md` (project), `~/.claude/CLAUDE.md` with `AGENTS.md` and `code-conventions.md` (user global), and the memory index.

- **Isolation:** agents never run on the host; each container sees only its own mount. Nothing in this phase may add a mount, mount the Docker socket, or widen what a sandbox sees.
- **GSD source:** only `@opengsd/gsd-core`. Never `get-shit-done-cc` or `gsd-build` (a guard rule scans for both names).
- **Platform:** macOS with Docker Desktop (arm64). Host scripts run under stock bash 3.2 with BSD tools (no `sed -i`, `stat -c`, `readlink -f`, `mapfile`, associative arrays, `${var,,}`).
- **Simplicity:** short, plain bash; no CLI framework.
- **Verification:** Docker is not available in the dev sandbox; every Docker behaviour is proven on the Mac with `./host-test.sh` (log in `host-test.log`).
- **Coexistence:** `ClaudeCode/`, `OpenCode/` and the root `README.md` stay untouched until Phase 5. The guard rule `old_layout_untouched` fails on any diff there. Document the new scripts in `SANDBOX.md` only.
- **Code style:** `set -eu` scripts with the 80-column banner layout (title, at most two "why" lines, Main / Entry Point), functions, camelCase locals, collection suffix (`fooList`), full variable names, braces on every `if`/`for`/`while`, blank line before and after each control-flow block, ASCII only in source, no planning IDs or "was X" comments in committed source, no doc-comments unless asked.
- **Prose:** no dashes as punctuation (use `;`, `:`, parentheses) and punctuation outside closing quotes, in code comments, docs and PR text.
- **Docs:** match the neighbouring docs in `SANDBOX.md`: short, schematic, tables where they carry structure.
- **Git:** branch from the updated target, never commit to the integration branch, code, `.planning/` and `.claude/` never share a branch or PR, no push without a per-branch go, never merge a PR, stage explicit paths, no AI attribution in the code PR beyond what the harness adds.
- **File modes:** edits made in a sandbox drop the exec bit on the Mac. New scripts must be committed as mode 100755 (`git add --chmod=+x`) and checked with `git ls-files -s bin`.

## Summary

Phase 3 adds four host scripts and one library in a new `bin/` folder, a registry of two-line files outside every mount, and a one-line version file baked into the images and printed by interactive shells. There is no external dependency to install: everything is bash, Docker Compose (already required), `build.sh` and `compose.yml` as they are. The design risk is not the mechanics but three failure classes that are cheap to prevent in the plan: (1) host scripts that quietly use bash 4+ features and break on the Mac's 3.2, (2) Compose picking the wrong project or sandbox because of ambient environment (`COMPOSE_PROJECT_NAME`, a stale exported `SBX_DIR`), and (3) a name or path reaching the filesystem or Compose before it is validated.

Everything that touches Docker can only be proven on the Mac. The plan should therefore split verification three ways. A docker-free self-test of `sbx-add` and the library runs in the dev sandbox (bash 5, fast feedback) and again on the Mac under `/bin/bash` through a new `host-test.sh` step, the same way the guard already runs in the Mac shell. Three new host checks (H-28 lifecycle, H-29 upgrade, H-30 version line) run against real Docker inside `tests/host/run-all.sh`, reusing the test sandbox name `hosttest` so cleanup, `clean.sh` and the identity assertions need no change. One attended helper covers what only a human can see (still logged in, `claude --continue` resumes after `sbx-upgrade`).

**Primary recommendation:** Build `bin/sbx-lib.sh` around two functions (`read_registry_entry`, `run_compose` with explicit `-p "sbx-$name"` and `-f`), make `sbx-upgrade` validate everything before the long build, then `up -d --force-recreate --wait`, then print `/etc/sbx/tool-versions` read from the image; write that file in the Dockerfiles from the build ARGs plus two tool queries, and print it from an appended `/etc/bash.bashrc` line.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Remember name to host path and agent | Mac host (registry file in `~/.config/sbx/sandboxes/`) | none | Must live outside every sandbox mount so an agent cannot edit it (D-02) |
| Validate name and path | Mac host script (`bin/sbx-lib.sh`) | Container entrypoint (second, independent check of the name) | Host refuses early; the entrypoint check stays as the last line of defence |
| Create `<name>/` and `state/` | Mac host script | none | The container only creates `state/` subfolders; it refuses a missing `<name>/` |
| Start, stop, recreate a sandbox | Docker Compose, driven by the host script | Docker daemon | The scripts only set variables and call `docker compose`; `compose.yml` stays the one definition |
| Rebuild images | `build.sh` (host) | Docker BuildKit | The only build path; options pass through |
| Record tool versions | Image build (both Dockerfiles) | none | Written once at build time, proven by the existing smoke tests (D-15) |
| Print versions at shell open | Image (`/etc/bash.bashrc` line) | none | Runs inside the container for interactive shells only |
| Print versions after upgrade | Mac host script | Image (`docker run --entrypoint cat`) | Reads the same file the shell prints, without needing a running container |

## Standard Stack

No package is installed in this phase.

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | 3.2 (macOS `/bin/bash`) on the Mac; 5.3.9 in the dev sandbox | Language of every `sbx-*` script | Project constraint; the user's Mac only has stock bash `[VERIFIED: ran bash --version in this sandbox, GNU bash 5.3.9; 3.2 is the CONTEXT/ROADMAP requirement]` |
| Docker Compose v2 | 2.40.0-desktop.1 seen on the Mac | `up`, `stop`, project handling | Already required (H-00); `compose.yml` is the single sandbox definition `[CITED: STATE.md, Plan 01.1-01 and H-10 notes]` |
| `build.sh` | repo | Builds `sbx-base:local` then `sbx-claude:local` | The only build path; takes extra options `[VERIFIED: build.sh:72-78]` |

Verbatim from `build.sh:72-78`: `cd "$(dirname "$0")"`, then `check_versions_file`, `load_versions`, `collect_build_args`, `build_image base/Dockerfile sbx-base:local "$@"`, `build_image claude/Dockerfile sbx-claude:local "$@"`. So `build.sh` runs from any folder and forwards `"$@"` to both builds.

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `tests/selftest/lib-expect.sh` (`expect`, `equals`, `has_text`, `make_work_folder`, `run_groups`) | Case helpers for the docker-free suite | New `tests/selftest/sbx/` suite `[VERIFIED: read in this session]` |
| `tests/host/lib*.sh` (`compose_down`, `compose_up`, `require_test_sandbox`, `add_problem`, `report_check`, `pin_of`, `run_timeout`) | Helpers for the new host checks | H-28 to H-30 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Registry env var `SBX_CONFIG_DIR` | `XDG_CONFIG_HOME` | XDG would silently move the registry for a Mac user who sets it, which breaks D-01's literal path. A dedicated variable defaults to `$HOME/.config/sbx` and is only set by tests |
| One version file prepended by each image | Two files joined by a helper script | One file is simpler; each future agent image prepends its own tools |
| Fake `docker` on PATH to test start/stop/upgrade in the dev sandbox | Real Docker on the Mac | The diet phase deleted the fake docker on purpose; the Mac run covers success paths and a real failed build covers the failure path |

**Installation:** none. **Package Legitimacy Audit:** not applicable, this phase installs no external package (the Dockerfile additions only call `printf`, `sed`, `cat` and tools already in the image).

## Architecture Patterns

### System Architecture Diagram

```
Mac shell (zsh), PATH has <repo>/bin
   |
   |  sbx-add <name> <abs path>
   |      validate name (rule read from base/sbx-start-lib.sh) and path
   |      mkdir -p <path>/<name> <path>/state
   |      write ~/.config/sbx/sandboxes/<name>   (SBX_DIR=..., SBX_AGENT=claude)
   |
   |  sbx-start | sbx-stop | sbx-upgrade <name> [build options]
   |      read registry file line by line (never sourced)  --> name, dir, agent
   |      pre-check: dir absolute, <dir>/<name> and <dir>/state exist
   |      run_compose: SBX_NAME= SBX_DIR= docker compose --env-file /dev/null
   |                    -p sbx-<name> -f <repo>/compose.yml  <subcommand>
   |
   +--> start:   up -d --wait            --> (optional) poll pgrep -x sleep in container
   +--> stop:    stop                    --> container kept, folders untouched
   +--> upgrade: validate all first
                 build.sh [options]      --> sbx-base:local, sbx-claude:local
                    fail? exit, old container untouched
                 up -d --force-recreate --wait  --> new container, same mount
                 docker run --rm --entrypoint cat sbx-claude:local
                          /etc/sbx/tool-versions --> one line on stdout

Image build (base/Dockerfile, claude/Dockerfile)
   base:   root RUN writes /etc/sbx/tool-versions  ("node | jdk | mvn | python")
           root RUN appends one line to /etc/bash.bashrc (print the file)
   claude: root RUN prepends "claude | gsd | ccusage | " to the same file
           smoke test (existing) proves the pins before the image exists

docker exec -it -w <project> sbx-<name> bash
   --> /etc/bash.bashrc (interactive only) --> prints the version line once
docker exec sbx-<name> bash -c ...   --> silent
```

### Recommended Project Structure
```
bin/
├── sbx-lib.sh        # sourced: registry read, name/path checks, run_compose, folder pre-check (mode 644)
├── sbx-add           # mode 755
├── sbx-start         # mode 755
├── sbx-stop          # mode 755
└── sbx-upgrade       # mode 755
tests/
├── selftest/sbx/     # docker-free: sbx-add, library, refusals, spaces (run-all.sh + group files)
├── host/h28-*.sh     # lifecycle on real Docker
├── host/h29-*.sh     # upgrade on real Docker
├── host/h30-*.sh     # version line
└── host/manual/h29-upgrade-resume.sh   # attended: still logged in, claude --continue
```
`claude/bin/` (image wrappers copied to `/usr/local/bin` in the image) is a different folder from the new repo-root `bin/` (host scripts); keep the two apart in docs and in guard globs.

### Pattern 1: Read the registry as data
**What:** `while IFS= read -r line || [ -n "$line" ]` with `case` on the key prefix; never `source`, never `eval`.
**When:** every script except `sbx-add` (which only checks that the file does not exist).
**Verified here (bash 5.3.9, not 3.2):** the loop returned `dir=[/tmp/tmp.zqwAPtVXg6/sp ace] agent=[claude]` for a path with a space and a file with no trailing newline `[VERIFIED: ran in this sandbox]`.
```bash
# Sketch; adapt to the banner layout. entryDir and entryAgent are globals set here.
read_registry_entry() {
  local entryFile="$registryDir/$1"
  local line

  entryDir=""
  entryAgent=""

  if [ ! -f "$entryFile" ]; then
    echo "sbx: '$1' is not registered; run: sbx-add $1 <host_path>" >&2
    return 1
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      SBX_DIR=*) entryDir=${line#SBX_DIR=} ;;
      SBX_AGENT=*) entryAgent=${line#SBX_AGENT=} ;;
    esac
  done < "$entryFile"

  case "$entryDir" in
    /*) ;;
    *) echo "sbx: the entry for '$1' has no absolute SBX_DIR" >&2; return 1 ;;
  esac

  if [ "$entryAgent" != "claude" ]; then
    echo "sbx: the entry for '$1' names agent '$entryAgent'; only claude exists" >&2
    return 1
  fi
}
```

### Pattern 2: One Compose wrapper with explicit flags
**What:** every Compose call goes through one function that sets `SBX_NAME`, `SBX_DIR` on that command only and passes `-p`, `-f` and `--env-file /dev/null`.
**Why:** the project name precedence is `-p` flag, then `COMPOSE_PROJECT_NAME`, then the compose file's `name:` `[CITED: docs.docker.com/compose/how-tos/project-name/]`. Without `-p`, a user who exported `COMPOSE_PROJECT_NAME` for another project would make `sbx-stop` stop that other project's `sandbox` service. `compose.yml:7` names the project `sbx-${SBX_NAME:?...}`, so `-p "sbx-$name"` gives the same value on purpose. Stop and up both need `SBX_DIR` because `compose.yml:34` has `source: "${SBX_DIR:?SBX_DIR is required ...}"` and Compose interpolates the whole file for every subcommand. `--env-file /dev/null` is what `tests/host/lib-sandbox.sh` already proves on the Mac `[VERIFIED: tests/host/lib-sandbox.sh:24-31 comment "--env-file /dev/null: a .env file in the repo never reaches the test sandbox."]`.
```bash
run_compose() {
  local sandboxName=$1
  local sandboxDir=$2

  shift 2
  SBX_NAME=$sandboxName SBX_DIR=$sandboxDir docker compose --env-file /dev/null \
    -p "sbx-$sandboxName" -f "$repoDir/compose.yml" "$@"
}
```
`"$@"` after `shift 2` is safe on bash 3.2 even when empty under `set -u`; a possibly empty array is not (see Pitfalls).

### Pattern 3: Upgrade = validate, build, recreate, report
**What:** fail fast on everything that can be checked cheaply, then the slow build, then recreate.
1. `read_registry_entry`, folder pre-check, `docker` reachable (all before the build).
2. If `docker container inspect -f '{{.State.Running}}' "sbx-$name"` prints `true`, print the one-line warning (D-13).
3. `"$repoDir/build.sh" "$@" || exit 1` (the `shift` already removed `<name>`; extra options such as `--no-cache` pass through, as `build.sh` forwards `"$@"`). The build runs while the old container keeps running; if it fails nothing else has happened (D-12).
4. `run_compose ... up -d --force-recreate --wait`. `--force-recreate` is `[CITED: docs.docker.com/reference/cli/docker/compose/up/]`: "Recreate containers even if their configuration and image haven't changed". Plain `up` already recreates when the image changed `[CITED: same page: "docker compose up picks up the changes by stopping and recreating the containers (preserving mounted volumes)"]`, but a cached rebuild yields the same image id and would leave the old container running, which breaks "recreate" in SC3. Force it.
5. Print `docker run --rm --entrypoint cat sbx-claude:local /etc/sbx/tool-versions` (the same file the shell prints). `--entrypoint cat` bypasses the entrypoint's mount refusal exactly as H-25 already does `[VERIFIED: tests/host/h25-images-match-versions.sh uses "docker run --rm --entrypoint cat sbx-claude:local /etc/sbx/versions.env"]`.

### Pattern 4: Version file at build time, printed by `/etc/bash.bashrc`
**Base image** (root section, after the `/etc/sbx/start.d` RUN at `base/Dockerfile:149`, so `NODE_VERSION` and `MAVEN_VERSION` ARGs declared earlier are in scope):
```dockerfile
# Sketch. jdk and python are not pinned by a variable, so they are asked once, here.
RUN printf 'node %s | jdk %s | mvn %s | python %s\n' \
      "${NODE_VERSION}" \
      "$(java -version 2>&1 | sed -n '1s/.*"\(.*\)".*/\1/p')" \
      "${MAVEN_VERSION}" \
      "$(python3 --version | sed 's/^Python //')" > /etc/sbx/tool-versions \
    && chmod 644 /etc/sbx/tool-versions \
    && printf '%s\n' 'cat /etc/sbx/tool-versions' >> /etc/bash.bashrc
```
**Claude image** (root section before `USER sandbox` at `claude/Dockerfile:77`, ARGs for the three pins are in scope):
```dockerfile
RUN { printf 'claude %s | gsd %s | ccusage %s | ' "${CLAUDE_CODE_VERSION}" "${GSD_CORE_VERSION}" "${CCUSAGE_VERSION}"; \
      cat /etc/sbx/tool-versions; } > /tmp/tool-versions \
    && mv /tmp/tool-versions /etc/sbx/tool-versions \
    && chmod 644 /etc/sbx/tool-versions
```
- The existing smoke tests (`base/Dockerfile:166-174`, `claude/Dockerfile:84-87`) assert each pinned version equals what the tool reports, and a failing smoke test means no image, so a line built from the same ARGs cannot disagree with the tools. Quote of the claude test: `test "$(claude --version)" = "${CLAUDE_CODE_VERSION} (Claude Code)"`.
- The append lands after `[ -z "${PS1-}" ] && return`, the first guard line of Ubuntu's `/etc/bash.bashrc`, so non-interactive shells never reach it `[VERIFIED: head of /etc/bash.bashrc read in this sandbox, Ubuntu 26.04; the 24.04 file is assumed identical and H-30 proves it on the real image]`.
- Behaviour with a system rc file, shown with a stand-in `~/.bashrc` (same interactive rule): `bash -i </dev/null` and `bash -ic true` printed the marker line; `bash -c true` and `bash -lc true` printed nothing `[VERIFIED: ran in this sandbox, bash 5.3.9]`. `/etc/profile` sources `/etc/bash.bashrc` only inside `if [ "${PS1-}" ]`, so `bash -lc` (what H-22 uses) stays quiet and a login interactive shell prints once `[VERIFIED: /etc/profile read in this sandbox]`.
- A non-tty interactive shell (`docker exec -i c bash -i </dev/null`) is the test handle: stdout carries the version line, stderr carries bash's "cannot set terminal process group" noise `[VERIFIED: ran in this sandbox]`. Read stdout only.

### Pattern 5: `sbx-add` order of operations
Validate everything, then create folders, then write the registry last, so a failure never leaves a registered name pointing at nothing.
1. Usage: exactly two arguments, else usage on stderr, exit 2 (the host-test convention).
2. Name: matches the rule read from the base library, is not `state` or `best-practices`.
3. Path: absolute, no newline, no `.` or `..` component, trailing slashes stripped, does not contain the registry folder (so an agent in that sandbox can never reach it; this also refuses `/` and `$HOME`).
4. Registry file `$registryDir/<name>` must not exist.
5. `mkdir -p "$hostPath/$name" "$hostPath/state"`.
6. Write the entry to a temp file inside `$registryDir`, then `mv` it into place (same-folder rename is atomic and avoids a half-written entry).

### Anti-Patterns to Avoid
- **`source` on the registry or `eval` on anything from it:** violates D-03.
- **Copying the name regex into `bin/`:** the rule must stay defined once. Extract it from `base/sbx-start-lib.sh` in a subshell (`$( . file && printf '%s' "$sandboxNamePattern" )`), which keeps that file's globals `ws`, `state` and `hookDir` out of the script. Verbatim rule: `sandboxNamePattern='^[a-z][a-z0-9-]{0,30}$'` `[VERIFIED: base/sbx-start-lib.sh:14]`.
- **`docker stop`/`docker rm`/`docker kill` by name:** go through Compose so labels and project stay consistent.
- **Any `down -v`, `--volumes`, `rm -rf` or `prune` in the four scripts:** stop and upgrade must never delete data (SC2, LAY-04).
- **Reading `$SBX_DIR`/`$SBX_NAME` from the caller's environment:** the SANDBOX.md manual flow tells users to `export` both, so they will often be set to something else; the scripts must always set them from the registry on the command itself.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sandbox name rule | A second regex in `bin/` | Read `sandboxNamePattern` and `sandboxNameRuleText` from `base/sbx-start-lib.sh` | One definition; the entrypoint and H-21 already enforce it |
| Reserved names | A second list in `sbx-add` | Factor the `state | best-practices` case at `base/sbx-start-lib.sh:60-65` into a variable (for example `sandboxReservedNameList="state best-practices"`) used by both `check_sandbox_name` and `sbx-add` | The list is currently only a `case`; copying it creates the drift D-04 forbids. Touches the image, so the entrypoint self-test and H-21 must still pass |
| Project/stack lifecycle | Container bookkeeping with raw `docker` commands | `docker compose -p -f` with `up`/`stop` | Labels, networks and the `name-check` service stay correct |
| Image build | A second build path | `build.sh` with option pass-through | The only place pins become build args |
| Absolute-path resolution | `realpath` or `readlink -f` | `case "$path" in /*)` plus the string checks above | Not reliably present in old macOS userland; only needed to reject relative input |
| Atomic registry write | Writing straight to the final name | Temp file in the same folder, then `mv` | No half-written entry on interrupt |
| Waiting for the start hooks | A new mechanism | The proven probe `docker exec sbx-<name> pgrep -x sleep` (as `wait_for_start_hooks` in `tests/host/lib-sandbox.sh`) | Phase 7 replaces it with a healthcheck; keep it small and self-contained |
| Version strings | Parsing tool output at every shell open | The build-time file (D-15) | 2 to 3 s per shell for Java and Maven |

**Key insight:** every behaviour here already exists as a proven pattern in this repo (`compose_cmd`, `build_images`, `wait_for_start_hooks`, the name rule, H-25's `docker run --entrypoint cat`). The scripts are thin glue; the new risk is bash 3.2 portability and input validation, not design.

## Common Pitfalls

### Pitfall 1: Ambient Compose or sbx variables pick the wrong project
**What goes wrong:** `COMPOSE_PROJECT_NAME`, a leftover exported `SBX_DIR`/`SBX_NAME` from the manual flow, or `COMPOSE_FILE` in the user's shell redirects `stop`/`up` to another project or folder.
**How to avoid:** `run_compose` passes `-p`, `-f`, `--env-file /dev/null` and sets both sandbox variables on the command. Precedence is documented (`-p` wins). Prove it in H-28 by running the scripts with a bogus exported `SBX_DIR` and `SBX_NAME`.
**Warning signs:** a script works only in a clean terminal.

### Pitfall 2: A name or path reaches the filesystem unvalidated
**What goes wrong:** `sbx-start ../x` reads or writes outside the registry; a path with a newline corrupts the two-line format; a path containing the registry exposes it to the agent (D-02).
**How to avoid:** validate the name before building any path from it, in every script. Use `[[ "$name" =~ $nameRulePattern ]]` with a regex variable and `LC_ALL=C`, never `grep`: `grep` treats a multi-line argument as several lines and `^...$` can match one of them, so a name like `$'ok\n../x'` would pass. Refuse newline, `.`/`..` components and a registry-containing path in `sbx-add`.

### Pitfall 3: bash 4+ features that break on the Mac's 3.2
**What goes wrong:** the executor writes on Linux (bash 5.3.9 here) and the script fails or misbehaves on macOS 3.2, which the dev sandbox cannot show (no bash 3.2, no compiler to build one: `gcc`, `make` absent).
**Avoid:** `mapfile`/`readarray`, `declare -A`/`local -A`, `${var,,}`/`${var^^}`, `&>>`, `|&`, `;&`/`;;&`, `[[ -v var ]]`, `local -n`, `wait -n`, negative array indices, fractional `read -t`, `printf -v` with arrays, `$EPOCHSECONDS`.
**Bash 3.2 traps that look fine on 5:**
- With `set -u`, expanding an empty array (`"${list[@]}"`) is an "unbound variable" error. Test the count first, as `tests/host/lib-report.sh` `report_result` does. `"$@"` is exempt.
- A `case` with `)` patterns inside `$( ... )` mis-parses on 3.2; and a heredoc inside `$( )` likewise. Put such code in a function or a quoted variable (STATE.md notes the H-27 `read -d` workaround).
- `[[ $x =~ "quoted" ]]` treats the right side as a literal; keep the regex in a variable.
- `local v=$(cmd)` hides the command's status; split declaration and assignment when the status matters.
- `read` returns non-zero for a last line without a newline; use `|| [ -n "$line" ]`.
**Mitigation:** the Mac host check must run the scripts as `/bin/bash script`, because `#!/usr/bin/env bash` may resolve to a Homebrew bash 5 on the user's PATH. Print `$BASH_VERSION` in the check output. A static grep for the forbidden list is possible but goes against the diet that cut the guard to security rules; recommend no new portability grep rule and rely on the real Mac run.

### Pitfall 4: Build failure must leave the sandbox alone, and `set -e` can hide it
**What goes wrong:** the build is wrapped in `if`/`||`/`&&` contexts or a function called in an `if`, which disables `set -e`, and the script goes on to recreate the container.
**How to avoid:** call `build.sh` as its own statement with an explicit `|| exit 1`, and cover it in H-29 with a real failing build (a bogus option such as `--no-such-option` makes `docker build` fail at once): the exit status is non-zero, the container id and start time are unchanged, and it is still running.

### Pitfall 5: `up -d --wait` returns before the start hooks finish
**What goes wrong:** the GSD sync (seconds) is still running when the script reports success, and a failing hook only shows as an exited container afterwards. `SANDBOX.md` already states it: "`up` returns before the start hooks (the GSD sync and the bundle links) finish, so it does not report a failing hook: the container exits afterwards." The compose reference is silent on `--wait` without a healthcheck `[CITED: docs.docker.com/reference/cli/docker/compose/up/ says only "Wait for services to be running|healthy"]`.
**How to avoid (recommended):** after `up`, poll `docker exec sbx-<name> pgrep -x sleep` up to 120 s, and if the container stopped running, print `docker logs sbx-<name>` as the hint and exit 1. Keep it in `sbx-lib.sh` as one small function with a self-contained comment saying a compose healthcheck should replace it. Without it, `sbx-start && docker exec ...` can race the sync.

### Pitfall 6: Upgrading a stopped or never-started sandbox
`up -d --force-recreate` starts it. Recommend: upgrade always leaves the sandbox running (simple, and a first run after `sbx-add` is `sbx-upgrade <name>`: it builds the images and starts the sandbox). State it in the usage text. If the images do not exist, `sbx-start` fails with Compose's missing-image error (`pull_policy: never`, `compose.yml:13`); check `docker image inspect sbx-claude:local` first and print "run sbx-upgrade <name>".

### Pitfall 7: Exec bit and file mode
Sandbox edits reach the Mac as 644. Commit `bin/sbx-add`, `sbx-start`, `sbx-stop`, `sbx-upgrade` as 100755 and `bin/sbx-lib.sh` as 100644 (`git add --chmod=+x`), and have H-28 invoke them through `PATH` so a lost exec bit or a bad shebang fails the check.

### Pitfall 8: The new checks run on committed code only
`host-test.sh` runs the guard and self-tests inside the container on a clone of the commit under test (`sandbox_suites`: "uncommitted edits are left out"). New files must be committed before the Mac run, and `bin/*` must be in the guard's `SHELL_FILES` or shellcheck never sees the scripts.

### Pitfall 9: Space in the path
Quote every expansion, never `cd $dir`, never word-split a path. `docker compose` receives the path through the environment (no splitting). Docker Desktop must share the parent folder; "mounts denied" is the symptom (already in SANDBOX.md troubleshooting).

### Pitfall 10: Image build leaves dangling images
Each `sbx-upgrade` re-tags `sbx-base:local` and `sbx-claude:local`, leaving the old ones untagged. Mention `./clean.sh` in the SANDBOX.md upgrade section.

## Code Examples

### Name check against the one rule (sketch)
```bash
# Pulls the rule out of the base library in a subshell; the library's globals stay out.
load_name_rule() {
  nameRulePattern=$(. "$repoDir/base/sbx-start-lib.sh" && printf '%s' "$sandboxNamePattern")
  nameRuleText=$(. "$repoDir/base/sbx-start-lib.sh" && printf '%s' "$sandboxNameRuleText")
}

check_name() {
  local LC_ALL=C

  if [[ ! "${1:-}" =~ $nameRulePattern ]]; then
    echo "sbx: '${1:-}' breaks the sandbox name rule: $nameRuleText" >&2
    return 1
  fi
}
```
Source for the shape: the same `[[ ... =~ $sandboxNamePattern ]]` with `local LC_ALL=C` at `base/sbx-start-lib.sh:52-58` `[VERIFIED: read this session]`.

### Folder pre-check (replaces the paste-by-hand block in SANDBOX.md)
```bash
check_sandbox_folders() {
  local folderName

  for folderName in "$1" state; do
    if [ ! -d "$entryDir/$folderName" ]; then
      echo "sbx: missing $entryDir/$folderName; create it with mkdir -p, then try again" >&2
      return 1
    fi
  done
}
```
`entryDir` is already proven absolute by `read_registry_entry`.

### Interactive probe for H-30 (host side)
```bash
# stdout only: bash -i without a tty writes its job-control warning to stderr.
shellOutput=$(docker exec -i "$CONTAINER" bash -i </dev/null 2>/dev/null)
quietOutput=$(docker exec "$CONTAINER" bash -c 'true' </dev/null 2>&1)
loginOutput=$(docker exec "$CONTAINER" bash -lc 'true' </dev/null 2>&1)
```
Expected: `shellOutput` equals the file's single line; the other two are empty. The expected line is built from `pin_of CLAUDE_CODE_VERSION`, `GSD_CORE_VERSION`, `CCUSAGE_VERSION`, `NODE_VERSION`, `MAVEN_VERSION`, the JDK from the `TEMURIN_IMAGE` tag (`eclipse-temurin:21.0.12_8-jdk-noble@...` gives `21.0.12`, the text before `_`) `[VERIFIED: versions.env:10]` and Python read from the container.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Paste `export SBX_NAME/SBX_DIR` and `docker compose` by hand (SANDBOX.md today) | Registry plus four scripts | This phase | The manual flow stays as a "what the scripts run" reference |
| `docker compose down`, `./build.sh`, `docker compose up` (SANDBOX.md "Rebuild without losing login") | `sbx-upgrade <name>` | This phase | Build happens first, while the old container still runs; downtime is only the recreate |

**Deprecated/outdated:** `ClaudeCode/cc-*.sh` stay until Phase 5; do not touch.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `docker compose stop` on a project with no containers exits 0 quietly (docs silent) | Pattern 3, sbx-stop | `sbx-stop` of a never-started sandbox errors; handle by inspecting first or tolerate non-zero. H-28 observes it |
| A2 | Ubuntu 24.04's `/etc/bash.bashrc` and `/etc/profile` match the 26.04 files read here (PS1 guard at the top; profile sources it only when `PS1` is set) | Pattern 4 | Hook prints in the wrong shells. H-30 proves it on the real image |
| A3 | `java -version` prints `openjdk version "21.0.12" ...` on its first line for Temurin 21, so the sed yields `21.0.12` | Pattern 4 | Wrong jdk field; H-30 compares to the `TEMURIN_IMAGE` tag |
| A4 | `python3 --version` on noble prints `Python 3.12.x`; the apt patch level moves with a rebuild | Open question 6 | Cosmetic |
| A5 | `up -d --force-recreate --wait` on the Mac's Compose 2.40 recreates and returns once the container is running (no healthcheck) | Pattern 3 | Upgrade appears to hang or not recreate; H-29 compares container ids before and after |
| A6 | A bogus `docker build` option makes `build.sh` exit non-zero quickly without touching the running container | Pitfall 4 | H-29 negative case needs another trigger (for example a temporary bad versions copy is NOT acceptable; prefer another bogus flag) |
| A7 | `/bin/bash` on the user's Mac is 3.2.x | Pitfall 3 | If a newer one is installed as `/bin/bash`, the "3.2" evidence is weaker; the check prints the version |
| A8 | A path with a space under `$TMPDIR` is bind-mountable by Docker Desktop without extra sharing | Validation | Mount denied; the run folder is already under the shared temp folder, so a subfolder with a space is expected to work |
| A9 | Refusing a host path that contains the registry folder (and so `/` and `$HOME`) is wanted | Security | Not in CONTEXT; it is a small extra refusal that protects D-02. Confirm with the user |

## Open Questions

1. **Upgrade of a stopped or never-created sandbox**
   - Known: `up -d --force-recreate` starts it.
   - Recommendation: always leave it running; say so in the usage line. Confirm with the user when presenting the plan.
2. **Does `sbx-start` wait for the start hooks?**
   - Known: Phase 7 will make `--wait` mean ready; the host tests already poll `pgrep -x sleep`.
   - Recommendation: yes, a bounded 120 s poll in `sbx-lib.sh` (also used by `sbx-upgrade`), with a hint to read `docker logs sbx-<name>` when the container died. Delete it in Phase 7.
3. **Reserved names:** factor `state | best-practices` into a variable in `base/sbx-start-lib.sh`? Recommend yes (touches `base/`, so the entrypoint self-test case for the name rule and H-21 must stay green). The alternative, a second list in `sbx-add`, is the drift D-04 wants to avoid.
4. **Separator in the version line:** recommend ` | ` (ASCII, scannable). A middle dot is not ASCII in source.
5. **Python field:** recommend the full patch version (`3.12.3`) rather than `3.12`: apt moves it at each rebuild, and the line is how the user notices.
6. **Environment override name for the registry folder:** recommend `SBX_CONFIG_DIR` (default `$HOME/.config/sbx`), set only by tests. Document it in one sentence in SANDBOX.md.
7. **Duplicate host paths:** two names registered on the same folder would share one `state/`. Recommend `sbx-add` refuses a path another entry already uses (a loop over the registry, a few lines). Not in CONTEXT, so confirm.
8. **Does a `.dockerignore`/build-context change matter?** No: `.dockerignore` is `*` with `!base`, `!claude`, `!versions.env` `[VERIFIED: .dockerignore]`, so `bin/` stays out of the build context. The Dockerfile changes need no new COPY.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash 5.x | Dev-sandbox self-test and guard | yes | 5.3.9 | none needed |
| bash 3.2 | SC5 proof | no (dev sandbox); yes on the Mac as `/bin/bash` | n/a | New `host-test.sh` step and H-28 run on the Mac under `/bin/bash` |
| C compiler / make | Building bash 3.2 locally | no | n/a | not needed; do not try |
| Docker / Compose | `sbx-start`, `-stop`, `-upgrade`, host checks | no (dev sandbox) | n/a | `./host-test.sh` on the Mac |
| shellcheck, hadolint | Guard linter rules | no (dev sandbox); run via `sbx-base` stand-ins on the Mac | n/a | The two linter rules FAIL as "not installed" here by design; `./host-test.sh` makes them pass |
| node, python3, curl | helpers | yes | present | n/a |

**Missing with no fallback:** none for planning. **Baseline recorded this session:** `bash tests/guard/run-all.sh` ended "2 rule(s) broken" (only `shellcheck_passes` and `hadolint_passes`, "not installed"); `tests/selftest/entrypoint/run-all.sh` and `tests/selftest/guard/run-all.sh` ended "All cases pass." `[VERIFIED: ran in this sandbox]`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Plain bash suites: `tests/guard/`, `tests/selftest/*` (helpers in `tests/selftest/lib-expect.sh`), `tests/host/` (helpers in `tests/host/lib*.sh`) |
| Config file | none; `.shellcheckrc` and `.hadolint.yaml` for the linters |
| Quick run command | `bash tests/selftest/sbx/run-all.sh && bash tests/guard/run-all.sh` (dev sandbox; the two linter rules fail here only as "not installed") |
| Full suite command | `./host-test.sh` on the Mac (writes `host-test.log`); it already runs the host checks, the guard and both self-tests in `sbx-hosttest`, and the guard in the Mac shell |

### Phase Requirements to Test Map
| Req / Success criterion | Behavior | Test type | Automated command | Where | File exists? |
|---|---|---|---|---|---|
| SCR-01 / SC1 | `sbx-add` records `SBX_DIR` and `SBX_AGENT=claude`, creates `<name>/` and `state/`; refuses a duplicate, a bad name, `state`, `best-practices`, a relative path, a path containing the registry; nothing is written on a refusal | docker-free self-test | `bash tests/selftest/sbx/run-all.sh` | dev sandbox, then Mac shell under `/bin/bash` via a new `host-test.sh` step | Wave 0 |
| SCR-01 / SC1 | Registry file is exactly the two lines and is read, never sourced (a planted `$(touch x)` or `; touch x` in a value runs nothing) | docker-free self-test | same | same | Wave 0 |
| SCR-02 / SC2 | Start by name only (ambient `SBX_DIR`/`SBX_NAME` ignored); stop keeps the container, `State.Running` false, sentinels in `<name>/` and `state/` intact; start again keeps the container id | host check H-28 | `bash tests/host/h28-sbx-add-start-stop.sh` (part of `run-all.sh`) | Mac | Wave 0 |
| SC5 | Host path with a space works end to end; scripts run under `/bin/bash` (version printed) | H-28 plus the self-test | as above | Mac | Wave 0 |
| SCR-03 / SC3 | `sbx-upgrade` builds, recreates (container id changes), sentinels (including one in `state/claude`) survive, no volume appears, same single bind mount | host check H-29 | `bash tests/host/h29-sbx-upgrade.sh` | Mac | Wave 0 |
| SCR-03 / SC3 | A failed build leaves the container id, start time and running state unchanged | H-29 negative case | same | Mac | Wave 0 |
| SCR-03 / SC3 | Still logged in and `claude --continue` resumes after `sbx-upgrade` | attended helper | `bash tests/host/manual/h29-upgrade-resume.sh` | Mac, needs a login (helper only, like H-09's second half) | Wave 0 |
| SCR-07 / SC4 | The file equals the line built from `versions.env`; an interactive shell prints it once; `bash -c` and `bash -lc` print nothing; `sbx-upgrade`'s last output line equals it | host check H-30 plus H-29 | `bash tests/host/h30-version-line.sh` | Mac | Wave 0 |
| Guard | `bin/*` is shellchecked; `bin/*` never sources a registry or runs `down -v`/`rm`/`prune` (optional rules, see below) | guard + guard self-test | `bash tests/guard/run-all.sh`, `bash tests/selftest/guard/run-all.sh` | dev sandbox and Mac | edit existing |

Notes for the planner:
- **H-28 and H-29 reuse the test sandbox name `hosttest`.** The check does `compose_down` first (like H-20 and H-10), registers `hosttest` in a throwaway registry (`SBX_CONFIG_DIR="$RUN/sbxcfg"`) on a folder with a space (`"$RUN/spaced dir"`), runs the scripts, and ends by `compose_down` then `compose_up` on the normal `$RUN`, so later checks still pass `require_test_sandbox`. While the sandbox mounts the spaced folder the loose test-sandbox rule still matches (its parent is `sbx-hosttest-*`); the strict rule (`assert_this_run_sandbox`) does not, so these checks must not call `require_test_sandbox` after starting the spaced sandbox and must restore before any other check. `clean.sh` removes the container by the same verdict (mount path contains `sbx-hosttest-`), so no cleanup code changes.
- **Place them in the chain after H-09** (`chainCheckList` at `tests/host/run-all.sh:24`: `h08 h16 h23 h11 h09 h20 h10`) and before `h20`. H-30 (read-only against the running sandbox) goes in `sandboxCheckList`.
- **Safety for the user's real registry:** the check must `fail` if `SBX_CONFIG_DIR` is empty or not under `$RUN` before calling any script. A forgotten variable would otherwise write into `~/.config/sbx`.
- **Docker-free suite:** `tests/selftest/sbx/` with `run-all.sh` and group files, using `lib-expect.sh`; every case sets `SBX_CONFIG_DIR` to the work folder. Add one `host-test.sh` step `mac_sbx_selftest` that runs it with `/bin/bash`, next to `mac_guard`, so the 3.2 proof is in `host-test.log`. The suite's own `run_groups` starts children with `bash` from PATH; print `BASH_VERSION` in a case so the log shows which one ran.
- **Guard changes (small):** add `bin/*` to `SHELL_FILES` (`tests/guard/lib.sh:22`), and to the file lists of `no_compromised_gsd_package` and `no_pipe_to_shell_installers` in `tests/guard/supply-chain.sh`. Optional rules, each needs a planted case in `tests/selftest/guard/sandbox-rules.sh`: (a) `bin/*` sources only `sbx-lib.sh` and `base/sbx-start-lib.sh` (enforces D-03), (b) the four scripts contain no `down -v`, `--volumes`, `rm -rf`, `docker rm`, `prune` (enforces LAY-04/SC2). Recommend both: each is one `nowhere_matches` line and each names a real past failure class (the old layout lost data with `down -v`). Keep the additions small; the guard plus its self-test is already about 911 lines (the 900-line cap was a Phase 2.1 gate, not a standing rule).
- **Docs and counts to update with the checks:** `tests/README.md` (suite table "H-00 to H-27", self-test table), `tests/host-checklist.md` (title "H-00..H-27", check table, manual helper table), `host-test.sh` comment "H-00 to H-27". `SANDBOX.md`: replace the manual flow sections ("Create a sandbox folder", "Start, enter, stop", "Rebuild without losing login", "Before every start") with the script flow, keep the raw Compose commands as a short "what the scripts run" note, add the one-time `PATH` line for the repo's `bin/`. Do not edit `README.md` (guard `old_layout_untouched`).

### Sampling Rate
- **Per task commit:** `bash tests/selftest/sbx/run-all.sh`, `bash tests/guard/run-all.sh`; also `bash tests/selftest/entrypoint/run-all.sh` and `bash tests/selftest/guard/run-all.sh` when `base/` or `tests/guard/` changes.
- **Per wave merge:** all four dev-sandbox suites.
- **Phase gate:** `./host-test.sh` green on the Mac from the committed code, plus the attended `h29-upgrade-resume.sh` helper once, before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `tests/selftest/sbx/` (`run-all.sh`, `lib.sh`, `add.sh` and `lib-functions.sh` groups): covers SCR-01, SC5
- [ ] `tests/host/h28-*.sh`, `h29-*.sh`, `h30-*.sh` and `tests/host/manual/h29-upgrade-resume.sh`: SCR-02, SCR-03, SCR-07
- [ ] `host-test.sh` step for the Mac-shell self-test; `tests/host/run-all.sh` list edits
- [ ] Guard constant and rule edits plus planted cases
- [ ] No framework install needed

## Security Domain

`security_enforcement` is enabled (absent in `.planning/config.json`'s sense means on; `security_asvs_level: 1`).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | none; no credentials handled by the scripts |
| V3 Session Management | no | none |
| V4 Access Control | yes | Registry outside every sandbox mount; refuse a host path that contains the registry (also stops `/` and `$HOME`); the entrypoint still refuses a bad name |
| V5 Input Validation | yes | Name regex from the one rule via `[[ =~ ]]` with `LC_ALL=C`; absolute path; no newline; no `.`/`..` component; always quoted; no `eval`; no `source` of data |
| V6 Cryptography | no | none |
| V12 Files and Resources | yes | Atomic `mv` of the registry entry; `mkdir -p` only after validation; no deletion anywhere in the four scripts |

### Known Threat Patterns for host bash plus Compose
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal through the sandbox name (`../x`) | Tampering | Validate the name before building `$registryDir/$name` |
| Registry value turned into code | Elevation of privilege | Line-by-line `read` with `case`, never `source`/`eval` (D-03); a self-test plants `$(...)` in a value |
| Agent edits the registry to mount the Mac home | Elevation of privilege | Registry outside mounts (D-02) plus the "path contains registry" refusal in `sbx-add` |
| Ambient `COMPOSE_*` or exported `SBX_*` steering Compose to another project | Tampering | `-p`, `-f`, `--env-file /dev/null`, variables set on the command |
| Data loss through `down -v`, `rm`, prune | Denial of service | `stop` for stop, `up --force-recreate` for upgrade (recreate keeps the bind mount), guard rule on the four scripts |
| `bin/` on the user's `PATH` is agent-writable when the repo lives in a sandbox mount | Elevation of privilege | Inherent to running repo scripts on the Mac (same trust as `build.sh` and `host-test.sh`); record it for the threat-model README section (DOC-03), do not try to solve it here |

## Sources

### Primary (HIGH confidence)
- Repo files read this session: `compose.yml`, `build.sh`, `versions.env`, `base/Dockerfile`, `claude/Dockerfile`, `base/sbx-start-lib.sh`, `base/sbx-entrypoint`, `tests/guard/*`, `tests/selftest/*`, `tests/host/*` (libs, h09, h10, h11, h20, h21, h22, h25, run-all), `host-test.sh`, `clean.sh`, `SANDBOX.md`, `tests/README.md`, `tests/host-checklist.md`, `.planning/{ROADMAP,REQUIREMENTS,STATE,PROJECT}.md`
- Experiments run in the dev sandbox (bash 5.3.9, Ubuntu 26.04): interactive versus non-interactive rc loading; line-by-line registry read with a spaced path; `/etc/profile` and `/etc/bash.bashrc` contents; baseline of all three suites

### Secondary (MEDIUM confidence)
- [Docker Compose `up` reference](https://docs.docker.com/reference/cli/docker/compose/up/): `--force-recreate`, recreate on changed image, `--wait`
- [Docker Compose `stop` reference](https://docs.docker.com/reference/cli/docker/compose/stop/): stops without removing
- [Compose project name](https://docs.docker.com/compose/how-tos/project-name/): precedence `-p`, `COMPOSE_PROJECT_NAME`, `name:`

### Tertiary (LOW confidence)
- Training knowledge for tool output formats (`java -version`, `python3 --version`) and for bash 3.2 quirks; marked `[ASSUMED]` in the log above and covered by host checks

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, nothing new is introduced
- Architecture: HIGH, every piece reuses a proven repo pattern
- Pitfalls: MEDIUM to HIGH; the bash 3.2 list cannot be exercised in the dev sandbox, so the Mac run is the proof
- Compose recreate/stop/`--wait` edge cases: MEDIUM, confirmed only by H-28 and H-29

**Research date:** 2026-11-06
**Valid until:** 2026-12-06 (stable; re-check only if Compose or `versions.env` pins change)
