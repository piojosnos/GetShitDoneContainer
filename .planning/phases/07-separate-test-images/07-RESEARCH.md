# Phase 7: Separate test images - Research

**Researched:** 2026-11-14
**Domain:** Shell tooling for Docker image tags (bash 3.2 portable), Docker Compose variable interpolation, test harness wiring
**Confidence:** HIGH (every file below was opened this session; Docker is not available in the dev sandbox, so the Mac gate is manual)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Choosing the tag
- **D-01:** One variable, `SBX_IMAGE_TAG`, picks the image tag. `build.sh`, `compose.yml` and `bin/sbx-lib.sh` read it; `build.sh` passes `BASE_IMAGE=sbx-base:$SBX_IMAGE_TAG` to the agent image builds. Unset, it means `local`, so every command behaves as today.
- **D-02:** Only `local` and `test` are accepted. Any other value stops the command with an error naming the two allowed values, so a typo cannot create a third image set.
- **D-03:** The test run does not copy the repo or rewrite tags with `sed`; it runs the real scripts with the variable set.

#### Tag naming
- **D-04:** Same image names, different tag: `sbx-base:test`, `sbx-claude:test`, `sbx-cursor:test`. The compose image line becomes `sbx-${SBX_AGENT}:${SBX_IMAGE_TAG}` (with the `local` default).

#### The test run
- **D-05:** `host-test.sh` sets `SBX_IMAGE_TAG=test` for the whole run. Every host check, the linter stand-ins (`make_linter_standin`, `linter_versions`) and the in-sandbox suites use the test tags; no host check names a `:local` tag. The log names the test tags.
- **D-06:** No step compares the `:local` image IDs before and after a run. The user judged it over paranoid: the run never names `:local`, so the guarantee comes from the design. Success criterion 2 is confirmed by eye at the Mac gate, not by a new check.

#### Test images after a run
- **D-07:** The test images stay between runs; the next run reuses their build cache. `clean.sh` removes the `:test` images along with the `:local` ones when no container uses them.

#### Size of the change
- **D-08:** Keep the bash change small and plain. Phase 10 rewrites the host side in Python, so this phase adds the variable and nothing more.

### Claude's Discretion
- Where exactly the allowed-value check lives (a helper in `bin/sbx-lib.sh` used by the `sbx-*` scripts, and a matching check in `build.sh`).
- How `run_compose` hands the tag to compose (set explicitly on the one command after the check, keeping its "never taken from the caller" spirit).
- Updating the self-test expectations (for example `tests/selftest/sbx/entry.sh` lines that expect `sbx-cursor:local`) and any guard rule that names `:local`.
- Doc updates (`README.md`, `tests/README.md`, the comments in `build.sh` and `compose.yml`) for the variable and the test tags.

### Deferred Ideas (OUT OF SCOPE)
None; discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IMG-01 | `./host-test.sh` builds its own test image tags and runs every host check against them. | Inventory sections 1 to 3 (every literal to change), `host-test.sh` and `host_init` export, build.sh `BASE_IMAGE` pass-through, new guard rule that no host file names `:local`. |
| IMG-02 | A test run never replaces `sbx-base:local` or `sbx-claude:local`. | Design guarantee (no test path names `:local`, tags are independent refs), unconditional `SBX_IMAGE_TAG=test` in two places so a stray caller value cannot redirect the run, manual before/after image ID look at the Mac gate (D-06). |
</phase_requirements>

## Summary

The change is one variable, `SBX_IMAGE_TAG`, read in four production places and set unconditionally in two test places. Production: `build.sh` (three tag names plus `BASE_IMAGE` for the two agent builds), `compose.yml` (one image line), `bin/sbx-lib.sh` (one `agentImage` line, one `run_compose` line, one new check). Test side: `host-test.sh` and `tests/host/lib.sh` `host_init` export `SBX_IMAGE_TAG=test`, and about 20 literal `:local` names in `host-test.sh` and nine host checks become `:test` references.

Because every host check starts the real `sbx-*` scripts and `build.sh` as child processes (never `env -i`), an exported variable reaches all of them. That is the whole mechanism and it needs no copy of the repo (D-03). Three traps matter more than the edits: (1) the sbx self-test runs in the Mac shell under `host-test.sh` with the variable exported, so its `:local` expectations break unless `start_group` unsets `SBX_IMAGE_TAG`; (2) the guard greps the exact compose image line and the `SBX_AGENT="$entryAgent" docker compose` text, so both rules must be updated in the same plan as the production edit; (3) `host-test.sh` must set the variable with `=test`, never `${SBX_IMAGE_TAG:-test}`, or a `local` left in the user's shell would make a test run replace the user's images.

`clean.sh` needs no code change: `docker image prune -a -f` already removes every unused image, `:local` and `:test` alike (D-07). Only its comment and the docs change.

**Primary recommendation:** Add `check_image_tag` (allow-list `local test`, mirrors `is_known_agent`) to `bin/sbx-lib.sh` and call it from `sbx_init`; mirror it in `build.sh`; export `SBX_IMAGE_TAG=test` unconditionally in `host-test.sh` and `host_init`; replace every host `:local` literal with `$baseImage`/`$claudeImage` variables; add one guard rule that no host test file names `:local`; add one dockerless self-test group for the tag.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tag allow-list for `sbx-*` commands | Host scripts (`bin/sbx-lib.sh`) | none | `sbx_init` is called by every `bin/` script, so one check covers all of them. |
| Tag allow-list for builds | Host script (`build.sh`) | none | `build.sh` is its own process and does not source `sbx-lib.sh`; it needs a matching check. |
| Image name to run | Compose (`compose.yml` interpolation) | `run_compose` sets the value | Compose renders the `image:` line; `run_compose` is the only place that hands it the checked value. |
| Base image for agent builds | `build.sh` (`--build-arg BASE_IMAGE=...`) | Dockerfile default | The Dockerfile `ARG BASE_IMAGE=sbx-base:local` stays as the plain `docker build` default. |
| Choosing the test tag | `host-test.sh` and `tests/host/lib.sh` | none | Test harness decides; production code only reads the variable. |
| Proof `:local` untouched | Design plus manual Mac look | none | D-06: no automated before/after check. |

## Standard Stack

No new libraries or packages. Everything is plain bash 3.2 compatible shell plus Docker Compose v2 variable interpolation, both already in use.

| Tool | Version | Purpose | Source |
|------|---------|---------|--------|
| Docker Compose interpolation `${VAR:-default}` | Compose v2 (host-test requires v2+) | Render `image:` from `SBX_IMAGE_TAG` with a `local` default | [CITED: docs.docker.com/reference/compose-file/interpolation/] states `${VAR:-default}` gives "value of VAR if set and non-empty, otherwise default" |
| bash | 3.2 on the Mac, 5.2 in the dev sandbox | All scripts | [VERIFIED: `bash --version` in sandbox: GNU bash 5.2.21]; Mac 3.2 per `bin/sbx-lib.sh:6` "Stock bash 3.2 with BSD tools" |
| shellcheck, hadolint | present at `/usr/local/bin` in the dev sandbox | Guard linter rules | [VERIFIED: `command -v`] |

**Package Legitimacy Audit:** No external packages are installed in this phase. Not applicable.

**Installation:** none.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Matching tag check in `build.sh` (recommended, as CONTEXT says) | `build.sh` sources `bin/sbx-lib.sh` and calls the shared `check_image_tag` | One copy of the allow-list, but `build.sh` gains a dependency on a library written for the `sbx-*` scripts and must set `scriptName`. Two copies is within the repo rule (extract at three). A self-test asserts both refuse the same way, so they cannot drift silently. |
| `host_init` exports `SBX_IMAGE_TAG=test` | Only `host-test.sh` exports it | Running `bash tests/host/run-all.sh` or one check by hand would then default to `local` and replace the user's images. Keep both. |

## Architecture Patterns

### Data flow of the tag

```
 caller shell (user)                         ./host-test.sh
 SBX_IMAGE_TAG unset  -> "local"             SBX_IMAGE_TAG=test   (always, exported)
        |                                          |
        |                                          +--> show_context prints "image tag: test"
        v                                          +--> mac_sbx_selftest (start_group UNSETS it)
 bin/sbx-* --> sbx_init --> check_image_tag        +--> host_checks --> tests/host/run-all.sh
                  |            (local|test else     |        host_init re-exports test
                  |             error, exit 1)      |        build_images --> build.sh (child, inherits)
                  v                                 |        compose_cmd  --> docker compose (inherits)
        imageTag                                    |        run_sbx      --> bin/sbx-* (env inherits)
          |            |                            +--> linter_versions, make_linter_standin: sbx-base:$SBX_IMAGE_TAG
          |            +--> read_registry_entry: agentImage=sbx-<agent>:<tag>
          |                    (require_images, runs_older_image)
          +--> run_compose: SBX_IMAGE_TAG="$imageTag" ... docker compose
                                                   |
                                                   v
                                  compose.yml image: "sbx-${SBX_AGENT:-claude}:${SBX_IMAGE_TAG:-local}"

 build.sh: check tag, then
   docker build -f base/Dockerfile   -t sbx-base:$tag      (no BASE_IMAGE arg: base has no such ARG)
   docker build -f claude/Dockerfile -t sbx-claude:$tag --build-arg BASE_IMAGE=sbx-base:$tag
   docker build -f cursor/Dockerfile -t sbx-cursor:$tag --build-arg BASE_IMAGE=sbx-base:$tag
```

### Pattern 1: allow-list helper that mirrors `is_known_agent`

**What:** `knownImageTagList="local test"` next to `knownAgentList`, a `check_image_tag` that sets `imageTag` and returns 1 with a message naming both values.
**When to use:** called once from `sbx_init`, so all nine scripts that call it (`sbx-add`, `sbx-fix-modes`, `sbx-list`, `sbx-upgrade`, `sbx-shell`, `sbx-stop`, `sbx-start`, `sbx-rm`, and the lib itself) refuse a bad value before doing anything.
**Example:**
```bash
# Source: pattern copied from is_known_agent, bin/sbx-lib.sh:118-128
knownImageTagList="local test"

# ------------------------------------------------------------------------------
# check_image_tag: sets imageTag from SBX_IMAGE_TAG; only local or test pass
# ------------------------------------------------------------------------------
# Unset or empty means local, as in compose.yml and build.sh.
# ------------------------------------------------------------------------------
check_image_tag() {
  local knownTag

  imageTag=${SBX_IMAGE_TAG:-local}

  for knownTag in $knownImageTagList; do
    if [ "$imageTag" = "$knownTag" ]; then
      return 0
    fi
  done

  sbx_error "SBX_IMAGE_TAG must be ${knownImageTagList// / or }, not '$imageTag'"
  return 1
}
```
`${var// / or }` already runs on the Mac: `bin/sbx-add` uses `${knownAgentList// /|}` [VERIFIED: bin/sbx-add, `addUsage="NAME HOST_PATH [${knownAgentList// /|}]"`]. In the dev sandbox it prints `local or test` [VERIFIED: run this session].

`sbx_init` gets one call: after the `unset COMPOSE_*` line and before `load_name_rule`, as `check_image_tag || return 1`. With `set -eu` in every script, a failing `sbx_init` ends the script (same as today's config errors).

### Pattern 2: `run_compose` sets the checked value, keeps the guard's grep alive

Current line [VERIFIED: bin/sbx-lib.sh:207]:
`SBX_NAME="$sandboxName" SBX_DIR="$entryDir" SBX_AGENT="$entryAgent" docker compose --env-file /dev/null -p "sbx-$sandboxName" -f "$repoDir/compose.yml" "$@" </dev/null`

New line: insert `SBX_IMAGE_TAG="$imageTag"` BEFORE `SBX_AGENT=`, so the substring `SBX_AGENT="$entryAgent" docker compose` that `tests/guard/start.sh:80` greps stays intact. `imageTag` is the checked value, not the raw caller variable. Update the header comment (lines 199 to 201): SBX_NAME, SBX_DIR and SBX_AGENT still never come from the caller; the tag does, but only after `check_image_tag`.

Note the spirit change to flag in the plan: `tests/host/lib-sbx.sh` `run_sbx` documents "The bogus exported values prove the scripts take everything from the registry" and passes `SBX_DIR=/nonexistent-ambient SBX_NAME=ambient`. It uses `env PATH=... "$@"` (inherits the rest), so the exported test tag reaches the scripts. Leave that comment as is; the tag is intentionally a caller input.

### Pattern 3: `BASE_IMAGE` on the agent builds only

`build_image DOCKERFILE TAG [OPTION...]` puts `"$@"` right after `docker build` [VERIFIED: build.sh:61-69, `docker build "$@" -f "$dockerfile" "${buildArgList[@]}" -t "$imageTag" .`]. So extra options for one build go after the TAG argument and need no change to `build_image`:

```bash
# Main / Entry Point of build.sh, after cd, before check_versions_file
check_image_tag || exit 1

if [ -n "$extraCertDir" ]; then
  build_image base/Dockerfile "sbx-base:$imageTag" --build-context "cacert=$extraCertDir" "$@"
else
  build_image base/Dockerfile "sbx-base:$imageTag" "$@"
fi

build_image claude/Dockerfile "sbx-claude:$imageTag" --build-arg "BASE_IMAGE=sbx-base:$imageTag" "$@"
build_image cursor/Dockerfile "sbx-cursor:$imageTag" --build-arg "BASE_IMAGE=sbx-base:$imageTag" "$@"
```
Do NOT put `BASE_IMAGE` in `collect_build_args` or `versions.env`: base has no such `ARG` (it would be an unconsumed build arg), and the guard rule `pins_are_exact` requires every `versions.env` name to end in `_VERSION`, `_IMAGE` or `_URL` with an `@sha256` digest for `_IMAGE` [VERIFIED: tests/guard/supply-chain.sh:107, `grep -E '^[A-Z_]+_IMAGE=' | grep -Ev '...@sha256:[0-9a-f]{64}$'`]. `BASE_IMAGE=sbx-base:test` would fail it. Keep `BASE_IMAGE` out of the pin file (CONTEXT already says: "`BASE_IMAGE` is not a pin").

The check in `build.sh` is a function under a banner (repo shell rule), placed first among the calls because `prepare_extra_cert` and the banner print before any build:

```bash
# ------------------------------------------------------------------------------
# check_image_tag: sets imageTag from SBX_IMAGE_TAG; only local or test pass
# ------------------------------------------------------------------------------
check_image_tag() {
  imageTag=${SBX_IMAGE_TAG:-local}

  case "$imageTag" in
    local | test) ;;
    *)
      echo "build.sh: SBX_IMAGE_TAG must be local or test, not '$imageTag'" >&2
      return 1
      ;;
  esac
}
```
Keep the wording `must be local or test` identical in both scripts so one self-test assertion covers both.

### Recommended file touches (plan split)

```
Plan A, production + their tests
  build.sh                      check_image_tag, tags, BASE_IMAGE, header comment (line 3, 5-8)
  compose.yml                   line 14 image, comment lines 11-13
  bin/sbx-lib.sh                knownImageTagList, check_image_tag, sbx_init call, agentImage, run_compose
  claude/Dockerfile, cursor/Dockerfile   comment line 4 only (ARG line 7 stays byte-exact)
  clean.sh                      comment lines 116-117 only
  tests/guard/start.sh          compose_image_follows_the_agent (lines 67-84), + tag wiring greps
  tests/selftest/sbx/lib.sh     start_group unset; new group tests/selftest/sbx/image-tag.sh
  tests/selftest/sbx/entry.sh   keep lines 75, 79 (default case); optional comment
  README.md                     Build the images, Free disk space, raw compose note
Plan B, test harness
  host-test.sh                  export, show_context line, linter_versions, make_linter_standin
  tests/host/lib.sh             host_init exports SBX_IMAGE_TAG=test, sets baseImage, claudeImage
  tests/host/h01,h12,h17,h22,h25,h27,h29,h30,h33   literals -> variables
  tests/host/h03                one assertion that compose renders the test tag
  tests/host/run-all.sh         build_all_images message names the tags; after build assert tags exist
  tests/guard (new rule)        no host test file names :local
  tests/README.md, tests/host-checklist.md
```

## Exhaustive inventory

Classes: **READ** = must read `SBX_IMAGE_TAG`; **LIT** = must stay literal; **TEST** = test expectation or host check to change; **DOC** = documentation. All line numbers are from files opened or grepped this session; the planner should re-run the grep below before editing.

Re-check command: `grep -rnE ':local|sbx-(base|claude|cursor):' . --exclude-dir=.git --exclude-dir=.planning --exclude-dir=.gsd -I`

### 1. Production code

| File:line | Today (verbatim) | Class | Action |
|-----------|------------------|-------|--------|
| build.sh:3 | `# Builds sbx-base:local, then sbx-claude:local and sbx-cursor:local, with the pins in versions.env` | DOC | Reword: tags come from `SBX_IMAGE_TAG` (default local). Add usage lines 5-8. |
| build.sh:159 | `build_image base/Dockerfile sbx-base:local --build-context "cacert=$extraCertDir" "$@"` | READ | `"sbx-base:$imageTag"` |
| build.sh:161 | `build_image base/Dockerfile sbx-base:local "$@"` | READ | same |
| build.sh:164 | `build_image claude/Dockerfile sbx-claude:local "$@"` | READ | tag plus `--build-arg "BASE_IMAGE=sbx-base:$imageTag"` |
| build.sh:165 | `build_image cursor/Dockerfile sbx-cursor:local "$@"` | READ | same |
| compose.yml:14 | `image: "sbx-${SBX_AGENT:-claude}:local"` | READ | `image: "sbx-${SBX_AGENT:-claude}:${SBX_IMAGE_TAG:-local}"` |
| compose.yml:11-13 | comment on the image line | DOC | mention `SBX_IMAGE_TAG` |
| compose.yml:45 | `image: "sbx-${SBX_NAME}-name-check"` | LIT | name-check image, scale 0, unrelated to the tag |
| bin/sbx-lib.sh:176 | `agentImage=sbx-$entryAgent:local` | READ | `agentImage=sbx-$entryAgent:$imageTag` (used by `require_images` line 232 and `runs_older_image` line 266) |
| bin/sbx-lib.sh:61-89 | `sbx_init` | READ | add `check_image_tag \|\| return 1` |
| bin/sbx-lib.sh:199-207 | `run_compose` | READ | add `SBX_IMAGE_TAG="$imageTag"` before `SBX_AGENT=` |
| bin/sbx-lib.sh:233 | `sbx_error "$agentImage is not built; run: sbx-upgrade ..."` | LIT | already prints `$agentImage`, so it shows the real tag |
| bin/sbx-upgrade | `bash "$repoDir/build.sh" "$@"` (run_build) | none | child process inherits the exported variable; the validated tag came from `sbx_init` first, so a bad value is refused before any build |
| bin/sbx-add, sbx-fix-modes, sbx-list, sbx-rm, sbx-shell, sbx-start, sbx-stop | call `sbx_init` | none | covered by the `sbx_init` call; no per-script edit |
| claude/Dockerfile:7, cursor/Dockerfile:7 | `ARG BASE_IMAGE=sbx-base:local` | LIT | stays: the default for a plain `docker build`, and `tests/guard/supply-chain.sh:127` allows exactly this line (`grep -Fvx 'ARG BASE_IMAGE=sbx-base:local'`) |
| claude/Dockerfile:4, cursor/Dockerfile:4 | `# BASE_IMAGE keeps a default because it names the local base tag, not a version.` | DOC | optional reword: build.sh passes the tag; the default is for a plain build |
| base/Dockerfile | no `:local`, no `BASE_IMAGE` | none | [VERIFIED: `grep -n BASE_IMAGE -r base claude cursor build.sh` returned only the two agent Dockerfiles] |
| clean.sh:116-117 | `# Other containers, their images and all volumes are kept. sbx-base:local,` / `# sbx-claude:local and sbx-cursor:local go too when unused; ./build.sh rebuilds them.` | DOC | comment only; add "and the :test images". `docker image prune -a -f` (line 124) already removes every unused image, so D-07 needs no code. |

### 2. Test harness: Mac run

| File:line | Today | Class | Action |
|-----------|-------|-------|--------|
| host-test.sh:71-72 | `docker run --rm --entrypoint shellcheck sbx-base:local --version` and the hadolint twin | TEST | `sbx-base:$SBX_IMAGE_TAG` |
| host-test.sh:137 | `printf '#!/bin/sh\nexec docker run --rm -v "$PWD:$PWD:ro" -w "$PWD" --entrypoint %s sbx-base:local "$@"\n' "$2" > "$1/$2"` | TEST | change `sbx-base:local` to `sbx-base:%s` and add `"$SBX_IMAGE_TAG"` as a printf argument after `"$2"`. The `"$@"` in the format must stay literal; only the tag is expanded when the stand-in is written. |
| host-test.sh:132, 145 | comments naming `sbx-base` / `sbx-base:local` | DOC | reword without `:local` (the new guard rule scans this file) |
| host-test.sh:44-49 | `show_context` | TEST | add `printf 'image tag: %s (sbx-base:%s, sbx-claude:%s, sbx-cursor:%s)\n'` so the log names the test tags (success criterion 1) |
| host-test.sh:197 | `remove_sandbox`: `SBX_NAME=hosttest SBX_DIR="$RUN" docker compose ... down` | none | inherits the exported tag |
| host-test.sh:248-254 | Main / Entry Point | TEST | add `SBX_IMAGE_TAG=test` and `export SBX_IMAGE_TAG` before `main`, after `cd`. `main 2>&1 \| tee` runs in a pipeline subshell that inherits exports. Header comment (line 5-6) gets one line about the test tags. |
| tests/host/lib.sh:21-37 | `host_init` | TEST | add `SBX_IMAGE_TAG=test; export SBX_IMAGE_TAG; baseImage=sbx-base:$SBX_IMAGE_TAG; claudeImage=sbx-claude:$SBX_IMAGE_TAG` (full names, no one-letter variables per coding rules). Every `h*.sh` calls `host_init` [VERIFIED: `grep -L host_init tests/host/h*.sh` returned nothing]. |
| tests/host/lib-docker.sh:13-39 | `build_images` runs plain `bash "$REPO_DIR/build.sh"` | none | inherits; update the header comment ("builds the test tags") |
| tests/host/lib-sandbox.sh:23-31 | `compose_cmd`: `SBX_NAME=hosttest SBX_DIR="$RUN" docker compose ...` | none | inherits the export from `host_init` |
| tests/host/lib-sbx.sh:57 | `run_sbx` uses `env PATH=... SBX_DIR=... "$@"` | none | `env` without `-i` inherits; the sbx scripts therefore see `test` and `agentImage` becomes `sbx-claude:test` |
| tests/host/run-all.sh:240-247 | `build_all_images` prints `building the images (logs in ...)` | TEST | add the tags to the message |
| tests/host/run-all.sh:144-155 | `print_next_block` cleanup text `SBX_NAME=hosttest SBX_DIR=%q docker compose down` | none | `down` does not need the image; leave (optionally add `SBX_IMAGE_TAG=test`) |

### 3. Host checks that name a `:local` tag

| File:line | Today (verbatim) | Action |
|-----------|------------------|--------|
| tests/host/h01-native-arch.sh:31 | `for imageName in sbx-base:local sbx-claude:local; do` | `for imageName in "$baseImage" "$claudeImage"; do` |
| tests/host/h12-plain-run-refused-pin-installed.sh:16 | `docker run --rm sbx-claude:local claude --version` | `"$claudeImage"` |
| tests/host/h12-plain-run-refused-pin-installed.sh:18 | `docker run --rm --entrypoint claude sbx-claude:local --version` | `"$claudeImage"` |
| tests/host/h17-start-offline-and-failing-hook.sh:60 | `"$@" sbx-claude:local sh -c 'echo h17-command-ran'` | `"$claudeImage"` |
| tests/host/h22-toolchain-in-base.sh:36 | comment `# The throwaway sbx-base:local container ...` | reword |
| tests/host/h22-toolchain-in-base.sh:42 | `docker run --rm --entrypoint bash sbx-base:local -c "$probeText"` | `"$baseImage"` |
| tests/host/h22-toolchain-in-base.sh:236 | `check_probe "sbx-base:local" "$baseOutput"` | `check_probe "$baseImage" "$baseOutput"` |
| tests/host/h25-images-match-versions.sh:31, 51, 56, 70 | `docker run --rm --entrypoint cat\|gsd-tools\|ccusage\|ls sbx-claude:local ...` | `"$claudeImage"` |
| tests/host/h27-bundle-clone-and-publish.sh:91 | `sbx-claude:local bash -c "$scriptText"` | `"$claudeImage"` |
| tests/host/h29-sbx-upgrade.sh:203 | `docker run --rm --entrypoint cat sbx-claude:local /etc/sbx/tool-versions` | `"$claudeImage"` |
| tests/host/h30-version-line.sh:35, 38 | `docker run ... sbx-claude:local /etc/sbx/tool-versions` and the message `"/etc/sbx/tool-versions in sbx-claude:local is ..."` | `"$claudeImage"` in both |
| tests/host/h33-sbx-rm.sh:280-285 | `docker image inspect sbx-claude:local` / `sbx-base:local` plus two `add_problem` strings naming them | `"$claudeImage"`, `"$baseImage"` (this check proves `sbx-rm` keeps the images; it now proves it for the test images) |
| tests/host/h14-wrappers-and-settings-in-image.sh, h27 other lines | contain `sbx-claude` as a command name, not an image tag | LIT, leave |

No host check uses the cursor image [VERIFIED: grep for `sbx-cursor` under tests/host returns none]; the cursor test tag is only built by `build.sh`.

Direct `docker compose` calls inside checks (`h03` `read_configs` and `read_name_probes`; `h10` line 33; `h20` line 34) use `env SBX_NAME=... docker compose`, which inherits `SBX_IMAGE_TAG=test` from `host_init`. They never name a tag.

### 4. Self-test and guard

| File:line | Today | Class | Action |
|-----------|-------|-------|--------|
| tests/selftest/sbx/entry.sh:75 | `expect "registry: a cursor entry maps to sbx-cursor:local" equals "$readOut" "cursor\|sbx-cursor:local"` | TEST | KEEP: it is the default case, valid only because `start_group` unsets the variable |
| tests/selftest/sbx/entry.sh:79 | same for claude | TEST | KEEP |
| tests/selftest/sbx/lib.sh:21-33 | `start_group` has `unset SBX_DIR SBX_NAME DOCKER_CONTEXT` | TEST | add `SBX_IMAGE_TAG` and `SBX_CA_CERT` to the unset list (see Pitfall 1) |
| tests/guard/start.sh:75-76 | `grep -Fq 'image: "sbx-${SBX_AGENT:-claude}:local"' $COMPOSE` and its echo | TEST | change to the new image line `'image: "sbx-${SBX_AGENT:-claude}:${SBX_IMAGE_TAG:-local}"'` |
| tests/guard/start.sh:80 | `grep -Fq 'SBX_AGENT="$entryAgent" docker compose' bin/sbx-lib.sh` | TEST | stays passing if `SBX_IMAGE_TAG` is placed before `SBX_AGENT` on the line; add a second grep for `SBX_IMAGE_TAG="$imageTag"` |
| tests/guard/supply-chain.sh:127 | `grep -Fvx 'ARG BASE_IMAGE=sbx-base:local'` | LIT | unchanged; the Dockerfile default stays |
| tests/guard/linters.sh:20, 41 | messages "it ships in sbx-base" | LIT | image name without a tag |

### 5. Docs

| File:line | Action |
|-----------|--------|
| README.md:35-37 | image table: keep `:local` (the user's tags); add one sentence that `SBX_IMAGE_TAG=test` selects the test set |
| README.md:49 | "Build the images": describe `SBX_IMAGE_TAG` (`local` default, `test` only for the test run, anything else refused) |
| README.md:391 | "Free disk space": add the `:test` images to the list that `clean.sh --yes` removes when unused |
| README.md:432 | raw `docker compose` note: add that the `local` tag is used unless `SBX_IMAGE_TAG=test` is set |
| README.md:441, 453 | keep (user-facing `:local` commands and error text; default case) |
| MIGRATION.md:127, 142 | keep (user-facing, default tags) |
| tests/README.md:15 | host-test paragraph: say it builds and uses the `:test` images and never touches the `:local` ones |
| tests/README.md:24 | "run from `sbx-base`" -> mention the test base image |
| tests/README.md (guard row, lines 28-31) | new rules: image tag wiring, no `:local` in host tests |
| tests/host-checklist.md:23 | `- Builds sbx-base:local, sbx-claude:local and sbx-cursor:local, the real image tags.` -> the test tags |
| tests/host-checklist.md:61 | H-30 row `sbx-claude:local` -> "the Claude test image" |
| tests/host-checklist.md:64 | H-33 row says "keeps ... the images": say the test images |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rendering the image name | a `sed` rewrite of `compose.yml` or a repo copy | Compose `${SBX_IMAGE_TAG:-local}` interpolation | D-03; interpolation is documented behaviour and the same line then serves both tags |
| Removing test images | a new cleanup loop in `clean.sh` | the existing `docker image prune -a -f` | already removes any unused image (D-07 needs only comment and doc edits) |
| Before/after image ID comparison | a recorded-ID step in `host-test.sh` | the manual Mac look (D-06) | the user ruled it out; do not add it |
| A fake Docker to test tag naming | any `docker` stand-in under `tests/selftest/sbx` | refusal cases with `DOCKER_HOST` pointing nowhere, plus the `building <tag>` line `build.sh` prints before it calls docker | DIET-05 removed every stand-in docker; memory note says never extend one |

**Key insight:** the guarantee comes from having no code path in a test run that can name `:local`. Everything else (allow-list, guard rule) exists to keep that true as the code changes.

## Common Pitfalls

### Pitfall 1: the sbx self-test runs with `test` exported and its `:local` expectations fail
**What goes wrong:** `host-test.sh` exports `SBX_IMAGE_TAG=test` before `mac_sbx_selftest`; `tests/selftest/sbx/entry.sh:75,79` then read `sbx-cursor:test`, and two cases FAIL on the Mac only.
**Why:** `lib_eval` sources the real library and `sbx_init` reads the caller's variable. The dev sandbox run (no export) stays green, so the break first shows at the Mac gate.
**How to avoid:** `start_group` in `tests/selftest/sbx/lib.sh` unsets `SBX_IMAGE_TAG` (and `SBX_CA_CERT`, which would make `build.sh` do certificate work in the new build case). New cases set the value explicitly.
**Warning signs:** `registry: a cursor entry maps to sbx-cursor:local` FAIL in the "sbx self-test in the Mac shell" step.

### Pitfall 2: guard greps the old compose line and the `run_compose` text
**What goes wrong:** the production edit lands and the guard fails (`compose_image_follows_the_agent`) in the dev sandbox, in CI later, and in two host-test steps.
**How to avoid:** update `tests/guard/start.sh` in the same plan. Put `SBX_IMAGE_TAG="$imageTag"` before `SBX_AGENT="$entryAgent"` so the existing substring grep still matches. Note the guard has `grep -Fq` fixed-string matching, so `${...}` need no escaping.

### Pitfall 3: `${SBX_IMAGE_TAG:-test}` in the test run
**What goes wrong:** a user shell with `SBX_IMAGE_TAG=local` exported (or any leftover) makes `./host-test.sh` build and replace the user's `:local` images, the exact failure this phase prevents.
**How to avoid:** assign unconditionally in `host-test.sh` and `host_init`: `SBX_IMAGE_TAG=test; export SBX_IMAGE_TAG`.

### Pitfall 4: BASE_IMAGE silently left at its Dockerfile default
**What goes wrong:** if the agent builds miss `--build-arg BASE_IMAGE=...`, `sbx-claude:test` is built `FROM sbx-base:local`. Nothing is replaced, so IMG-02 holds, but the test no longer tests the fresh base, and a Mac with no `:local` image fails to build.
**How to avoid:** pass it on both agent builds only (not base). A guard grep of `build.sh` for `BASE_IMAGE=sbx-base:$imageTag` is cheap insurance (optional). The Mac gate also proves it: build from the state where `:local` exists and compare, or check the Claude test image build log for `FROM sbx-base:test`.

### Pitfall 5: the `make_linter_standin` printf
**What goes wrong:** the stand-in is a script written by `printf` with a format string; leaving `$SBX_IMAGE_TAG` inside the single-quoted format writes the literal text `$SBX_IMAGE_TAG`, which expands at run time, in a child `sh` that may lack the variable (`env` of the guard run) and silently falls back to nothing.
**How to avoid:** use `%s` in the format and pass `"$SBX_IMAGE_TAG"` as an argument so the tag is written into the file.

### Pitfall 6: false "older image" marks when the tag does not reach `bin/`
**What goes wrong:** `sbx-list` and `sbx-start` compare the running container's image ID with `agentImage` (`bin/sbx-lib.sh:257-269`). A test container is on `:test`; if a `bin/` script in a host check defaulted to `local`, H-28 and H-32 would see a different image (or a missing one) and warn or mark `running, older image`.
**How to avoid:** `host_init` exports the variable and every `bin/` call in checks goes through `env PATH=... "$@"` (no `-i`). Do not add `env -i` anywhere in the test libs.

### Pitfall 7: tag semantics differ between three readers
`${SBX_IMAGE_TAG:-local}` in compose and bash treats empty as unset. `build.sh`, `check_image_tag` and compose must all use the colon form so an empty value means `local` everywhere. A test asserts `SBX_IMAGE_TAG=''` yields `local`.

### Pitfall 8: shell portability
Use `case`, `${var// / or }` (already used in `sbx-add`) and `export`; no `declare -A`, `mapfile`, or `[[ -v ]]` (bash 3.2). Bash prefix assignment before a shell function call (`VAR=x func`) is not relied on; use `export` then `unset` in self-test cases.

## Code Examples

### Self-test group `tests/selftest/sbx/image-tag.sh` (dockerless)

Follows the existing group shape (banner, `set -u`, `. lib.sh`, `case_*` functions, `start_group`, `finish_cases`). `run_groups` picks up every `*.sh` in the folder except `lib.sh` and `run-all.sh` [VERIFIED: tests/selftest/lib-expect.sh `case "$groupName" in lib.sh | run-all.sh) continue`], so no registration is needed.

```bash
# Case: the tag picks the image name; local is the default
case_tag_picks_image() {
  local readText='read_registry_entry NAME; printf "%s|%s\n" "$entryAgent" "$agentImage"'
  local readOut

  SBX_CONFIG_DIR=$WORK/cfg-tag
  export SBX_CONFIG_DIR
  plant_entry cursorentry "SBX_DIR=/x/cursor" "SBX_AGENT=cursor"

  readOut=$(SBX_IMAGE_TAG=test lib_eval "${readText/NAME/cursorentry}" 2>&1)
  expect "tag: test maps a cursor entry to sbx-cursor:test" equals "$readOut" "cursor|sbx-cursor:test"

  readOut=$(SBX_IMAGE_TAG='' lib_eval "${readText/NAME/cursorentry}" 2>&1)
  expect "tag: an empty value means local" equals "$readOut" "cursor|sbx-cursor:local"
}
```
`VAR=value $(...)` form with a function: `SBX_IMAGE_TAG=test lib_eval ...` works here because `lib_eval` runs a subshell; if the planner prefers not to rely on prefix assignment to a function on bash 3.2, wrap as `( export SBX_IMAGE_TAG=test; lib_eval ... )`.

Refusal cases (use `export`/`unset` around `run_sbx`; `refused_cleanly LABEL TEXT NAME PATH` exists in lib.sh):
- `sbx-start` and `sbx-upgrade` with `SBX_IMAGE_TAG=latest`: exit 1, stderr has `must be local or test`; for `sbx-upgrade` also `lacks_text` `build.sh: building` (reuse the `refused_before_build` shape from `upgrade.sh:15-19`).
- `sbx-add` with a bad value creates no registry entry and no folder (`refused_cleanly ... NAME PATH`).
- `build.sh` itself, run as `bash "$REPO/build.sh"` with `DOCKER_HOST` still pointing nowhere (set by `start_group`):
  - `SBX_IMAGE_TAG=latest`: exit 1, stderr has the text, stdout lacks `build.sh: building`.
  - `SBX_IMAGE_TAG=test`: stdout has `build.sh: building sbx-base:test` (the line is printed before the docker call; verified this session that unset prints `build.sh: building sbx-base:local` and then stops at `docker: command not found`, exit 127), and the exit is non-zero.
  - unset: stdout has `build.sh: building sbx-base:local`.

No docker answers in any of these, no stand-in docker is added, and the cases pass on Linux and under `/bin/bash` 3.2 on the Mac.

### Guard rules to add or change

```bash
# tests/guard/start.sh: replace the first grep in compose_image_follows_the_agent
if ! grep -Fq 'image: "sbx-${SBX_AGENT:-claude}:${SBX_IMAGE_TAG:-local}"' $COMPOSE; then
  echo "    $COMPOSE does not take its image from \"sbx-\${SBX_AGENT:-claude}:\${SBX_IMAGE_TAG:-local}\""
  ok=1
fi

if ! grep -Fq 'SBX_IMAGE_TAG="$imageTag"' bin/sbx-lib.sh; then
  echo "    bin/sbx-lib.sh does not pass SBX_IMAGE_TAG=\"\$imageTag\" to docker compose"
  ok=1
fi
```

New rule (success criterion 1, mechanical) using the existing `nowhere_matches REGEX FILE...` helper [VERIFIED: tests/guard/lib.sh `nowhere_matches() { local regex=$1 ...`]:

```bash
# host_tests_never_name_the_local_tag: a test run cannot reach the user's images
host_tests_never_name_the_local_tag() {
  nowhere_matches ':local\b' host-test.sh tests/host/*.sh
}
```
Place it in `tests/guard/isolation.sh` (it is about keeping the test run away from user data) or a new `tests/guard/images.sh` group; add the name to `run_rules`. This rule is why the comment rewrites in `h22:36` and `host-test.sh:145` are required. It does not scan `tests/selftest/` (those default-case expectations legitimately name `:local`). Update the guard row of `tests/README.md` ("18 rules" count rises accordingly).

### Linter stand-in with the tag written in

```bash
make_linter_standin() {
  printf '#!/bin/sh\nexec docker run --rm -v "$PWD:$PWD:ro" -w "$PWD" --entrypoint %s sbx-base:%s "$@"\n' "$2" "$SBX_IMAGE_TAG" > "$1/$2"
  chmod +x "$1/$2"
}
```

### H-03 assertion that compose renders the test tag (host check, no `:local` named)

`read_configs` already renders `nameOutput=$(compose_cmd config ...)` with the exported tag. Add:

```bash
check_image_follows_the_tag() {
  if ! printf '%s\n' "$nameOutput" | grep -Fxq "    image: $claudeImage"; then
    add_problem "expected the line 'image: $claudeImage' in the config; got: $(first_lines "$nameOutput")"
  fi
}
```
The 4-space indent matches Compose's rendered `services.sandbox.image`; the planner should confirm the exact rendered form (`image: sbx-claude:test`) on the Mac gate, or use `grep -F "image: $claudeImage"` without `-x` to be indent-proof. This is the only automated proof that the Compose interpolation works; the default-`local` rendering is covered by the guard's literal grep, not by a host check (a host check may not name `:local`).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hard-coded `:local` everywhere | One `SBX_IMAGE_TAG` with allow-list `local`, `test` | this phase | test run isolated from user images |
| Roadmap/old plan: copy repo, `sed` tags | run real scripts with variable set | D-03 | tests exercise the real code |

Forward links, no action now: Phase 8 builds a throwaway root certificate into the test base image (`SBX_IMAGE_TAG=test` plus `SBX_CA_CERT`-style input fits this variable unchanged); Phase 10 rewrites the host side in Python (hence D-08, keep this small); Phase 11 CI builds the test images (`SBX_IMAGE_TAG=test ./build.sh` is the command).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `docker compose down` does not need the image to exist, so `print_next_block`'s cleanup line works without `SBX_IMAGE_TAG=test` | Inventory 2 | Cleanup command would error on a Mac with no `:local` image; fix: add `SBX_IMAGE_TAG=test` to the printed command (low cost, may do it anyway) |
| A2 | A fully cached `docker build -t sbx-base:test` yields the same image ID as `sbx-base:local` (two tags on one ID) | Pitfall 4 / Mac gate | None for IMG-02: tags are independent refs and only `:test` is moved. It only matters for how the manual before/after look is read; identical IDs for the two tags on a first run are normal |
| A3 | Rendered `compose config` shows `image: sbx-claude:test` at 4-space indent | Code Examples (H-03) | The one H-03 assertion would false-FAIL; use `grep -F` without `-x` |
| A4 | `${SBX_IMAGE_TAG:-local}` treats an empty value like unset in Compose, as the docs state for `:-` | Pitfall 7 | Documented: [CITED: docs.docker.com/reference/compose-file/interpolation/]; low risk |

## Open Questions

1. **Tag check in `build.sh`: duplicate or source the lib?**
   - What we know: CONTEXT says "a matching check in `build.sh`"; the repo allows two copies; `load_name_rule` shows a preference for single source of truth.
   - What's unclear: whether the user prefers one allow-list.
   - Recommendation: duplicate (about 10 lines), keep the wording identical, and assert it in the self-test. Revisit when Phase 10 moves both to Python.

2. **Should `print_next_block` carry the tag?**
   - Recommendation: yes, add `SBX_IMAGE_TAG=test` to the printed cleanup command so it matches the sandbox that was started (one `%s`-free text change). Harmless either way.

3. **Cursor test image coverage.** No host check runs the cursor image; `build.sh` builds `sbx-cursor:test` and nothing asserts it. Recommendation: after `build_all_images`, one `docker image inspect` over all three test tags in `run-all.sh` (cheap, no `:local` name). Not required by IMG-01.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker / Compose | real builds, host checks, Mac gate | no (dev sandbox) [VERIFIED: `command -v docker` printed nothing] | n/a | Mac host only; dockerless cases cover allow-list, naming of the base tag, refusals |
| bash | all scripts | yes | 5.2.21 here, 3.2 on Mac | none needed |
| shellcheck, hadolint | guard linter rules | yes | at `/usr/local/bin` | none needed |
| macOS Mac with Docker Desktop | success criteria 1 and 2 | not here | n/a | user runs `./host-test.sh` (CLAUDE.md: plans must include host-side manual verification steps) |

**Missing dependencies with no fallback:** none for planning; the full `./host-test.sh` run can only happen on the Mac.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | plain bash suites with their own `expect`/`run_rules` helpers (no bats/pytest yet; Phase 10 moves to pytest) |
| Config file | none; `.shellcheckrc` and `.hadolint.yaml` for the linter rules |
| Quick run command | `bash tests/selftest/sbx/run-all.sh && bash tests/guard/run-all.sh` |
| Full suite command | `./host-test.sh` (Mac only; writes `host-test.log`) |

Baseline measured this session in the dev sandbox: sbx self-test "All cases pass." in about 1 s; guard "All rules hold." in about 9 s. Both are under the 30 s sampling budget.

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IMG-01 | `SBX_IMAGE_TAG` allow-list refuses other values in `bin/` scripts and `build.sh` | selftest (dockerless) | `bash tests/selftest/sbx/image-tag.sh` | Wave 0 |
| IMG-01 | tag selects `agentImage` (`sbx-<agent>:<tag>`), unset or empty means `local` | selftest | `bash tests/selftest/sbx/image-tag.sh` | Wave 0 |
| IMG-01 | `build.sh` names `sbx-base:<tag>` (unset `local`, `test`) before any docker call | selftest | `bash tests/selftest/sbx/image-tag.sh` | Wave 0 |
| IMG-01 | compose image line and `run_compose` carry the tag | guard | `bash tests/guard/start.sh` | edit existing |
| IMG-01 | no host test file names `:local` | guard (new rule) | `bash tests/guard/isolation.sh` (or `images.sh`) | Wave 0 |
| IMG-01 | `build.sh` passes `BASE_IMAGE=sbx-base:$imageTag` to both agent builds | guard grep (optional) | `bash tests/guard/supply-chain.sh` or `images.sh` | Wave 0 |
| IMG-01 | compose renders the test image in the real run | host check H-03 assertion | `./host-test.sh` (Mac) | edit existing |
| IMG-01 | `host-test.sh` builds `:test`, runs every check on it, log names the tags | manual + host | `./host-test.sh`; `grep 'image tag' host-test.log` | Mac gate |
| IMG-02 | `:local` image IDs identical before and after a full run | manual only (D-06: no automated step) | Mac: `docker image inspect --format '{{.Id}}' sbx-base:local sbx-claude:local sbx-cursor:local` before and after `./host-test.sh` | manual |
| IMG-02 | `build.sh`, `sbx-upgrade`, sandboxes still use `:local` when unset | selftest + guard + manual | default-case cases in `entry.sh:75,79`; `SBX_IMAGE_TAG` unset `./build.sh` on the Mac prints `building sbx-base:local` | existing + manual |

Manual-only justification for IMG-02 and the real-build part of IMG-01: Docker is not available in the dev sandbox (CLAUDE.md Verification constraint) and the user ruled out an automated ID comparison (D-06).

### Mac gate procedure (for the plan's final checkpoint)
1. `docker image inspect --format '{{.RepoTags}} {{.Id}}' sbx-base:local sbx-claude:local sbx-cursor:local` and note the IDs.
2. `./host-test.sh`; confirm every step OK, `host-test.log` has an `image tag: test` line, and `grep -n ':local' host-test.log` shows nothing from the run's own commands (build logs print `building sbx-base:test`).
3. Repeat step 1: the IDs match. `docker image ls` shows `sbx-*:test` next to `sbx-*:local`.
4. `./build.sh` (variable unset) prints `building sbx-base:local`; `SBX_IMAGE_TAG=bogus ./build.sh` refuses naming `local or test`; `sbx-upgrade` of a real sandbox still ends on the new `:local` images.
5. `./clean.sh` dry run lists the `:test` images; `--yes` removes them when no container uses them.

### Sampling Rate
- **Per task commit:** `bash tests/selftest/sbx/run-all.sh && bash tests/guard/run-all.sh`
- **Per wave merge:** same, plus `bash -n` on every edited script and the shellcheck rule via the guard
- **Phase gate:** full `./host-test.sh` green on the Mac plus the manual ID comparison, before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `tests/selftest/sbx/image-tag.sh`: covers the allow-list, agent image mapping, `build.sh` tag naming (IMG-01)
- [ ] `tests/selftest/sbx/lib.sh` edit: `start_group` unsets `SBX_IMAGE_TAG` and `SBX_CA_CERT` (must land before the Mac run)
- [ ] guard rule `host_tests_never_name_the_local_tag` (and the updated `compose_image_follows_the_agent`)
- [ ] no framework install needed

## Security Domain

`security_enforcement` is enabled in `.planning/config.json` (`"security_enforcement": true`, ASVS level 1).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a |
| V3 Session Management | no | n/a |
| V4 Access Control | yes (isolation of user images from test runs) | the unconditional `SBX_IMAGE_TAG=test` plus the guard rule; sandbox isolation itself unchanged |
| V5 Input Validation | yes | allow-list (`local`, `test`) on the one new input, before it reaches `docker build -t`, `docker compose` or an image reference; never a pattern or a pass-through |
| V6 Cryptography | no | n/a |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Env var injects an arbitrary image reference (for example a registry host or digest) into `compose.yml` or `build.sh` | Tampering | Allow-list in both `check_image_tag` copies; compose also has `pull_policy: never` [VERIFIED: compose.yml:15], so even a leaked value never pulls |
| Test run replaces the user's working images | Tampering / DoS | unconditional test tag in `host-test.sh` and `host_init`; guard rule forbids `:local` in host tests |
| The sandbox sets the tag | Elevation | `SBX_IMAGE_TAG` is read on the Mac only; the registry entry holds `SBX_DIR` and `SBX_AGENT`, not the tag, and sandboxes cannot reach the Mac shell environment |

The new variable adds no secret and no network access.

## Project Constraints (from CLAUDE.md)

From `/home/sandbox/workspace/get-shit-done-container/.claude/CLAUDE.md` and the global rules loaded for this project:
- Agents never run on the host; Docker is not available in the dev sandbox, so plans must include host-side manual verification steps (this research's Mac gate).
- Keep shell scripts short and plain bash; they run on macOS bash 3.2 with BSD tools (no `sed -i` without suffix, no `grep -P`, `readlink -f`, `date -d`, `mapfile`).
- GSD comes only from `@opengsd/gsd-core`; irrelevant to this phase.
- Coexistence: the old `ClaudeCode/` layout stays untouched until Phase 5 of v1; this phase edits only the new layout (`build.sh`, `bin/`, `compose.yml`).
- Shell layout rules: banner before each section (80 columns), a function under its own banner, a `Main / Entry Point` banner, a library runs nothing and sets no options, a failing function returns non-zero and the caller exits.
- Coding rules: braces always, blank line around control flow, full variable names (`knownTag`, `imageTag`, `claudeImage`), collection variables with a type suffix, test fixture names abstract and numbered, ASCII only in source, no planning IDs (D-0x, IMG-0x, phase numbers) in committed source or comments, no "was X" comments.
- Prose rules: no dashes as punctuation in docs, comments and PR text; punctuation outside closing quotes.
- Docs: match neighbours, short, schematic (tables) where it helps.
- Git: work on a new branch cut from updated `main`; `.planning/` changes and code are separate PRs; pushes only with explicit approval; no AI attribution in commits.
- Memory: never extend the fake docker (it is gone; the new self-test uses `DOCKER_HOST` pointing nowhere); Mac validation goes through `./host-test.sh` and `host-test.log`; sandbox edits drop the exec bit on the Mac, so a new test file may need `chmod +x` (check `git diff --summary` for mode changes); write automated tests for new behaviour.

## Sources

### Primary (HIGH confidence, files opened this session)
- `/home/sandbox/workspace/get-shit-done-container/build.sh` (all 166 lines)
- `compose.yml` (all), `bin/sbx-lib.sh` (all), `bin/sbx-upgrade`, `bin/sbx-start`, `bin/sbx-add` (all)
- `host-test.sh` (all), `clean.sh` (all)
- `tests/host/lib.sh`, `lib-docker.sh`, `lib-sandbox.sh`, `lib-sbx.sh`, `run-all.sh`, `h03`, `h12`, `h25`, `h30` (relevant lines)
- `tests/selftest/lib-expect.sh`, `tests/selftest/sbx/lib.sh`, `run-all.sh`, `entry.sh`, `upgrade.sh`
- `tests/guard/run-all.sh`, `lib.sh`, `start.sh`, `supply-chain.sh`, `linters.sh`, `isolation.sh`
- `tests/README.md`, `tests/host-checklist.md`, `README.md` (relevant sections), `claude/Dockerfile`, `cursor/Dockerfile`, `.shellcheckrc`
- `.planning/phases/07-separate-test-images/07-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` (Phases 7 to 11), `.planning/research/v2-simple-tooling-decisions.md`
- Baseline runs: `bash tests/selftest/sbx/run-all.sh` (all pass, 1.2 s), `bash tests/guard/run-all.sh` (all hold, 9.2 s); `bash build.sh` with `DOCKER_HOST` unreachable printed `build.sh: building sbx-base:local` then stopped.

### Secondary (MEDIUM confidence)
- [CITED: https://docs.docker.com/reference/compose-file/interpolation/] `${VAR:-default}` semantics. The page excerpt returned by the fetch did not address `.env` versus shell precedence, so that point rests on the existing behaviour in this repo (`--env-file /dev/null` is already used with exported `SBX_*` values passing through, for example `tests/host/lib-sandbox.sh` `compose_cmd`).

### Tertiary (LOW confidence)
- none; assumptions A1 to A3 are listed above.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, no new dependencies; compose interpolation is documented.
- Architecture and inventory: HIGH, every file read and grepped this session; line numbers from the current `chore/planning-phase-07` branch (HEAD e535558).
- Pitfalls: HIGH for 1, 2, 3, 5, 6 (read from code); MEDIUM for 4 and A2/A3 (Docker behaviour unverifiable here).

**Research date:** 2026-11-14
**Valid until:** until the next edit to `build.sh`, `compose.yml`, `bin/sbx-lib.sh` or the host tests (re-run the inventory grep first); Phase 10 invalidates the whole host-side part.
