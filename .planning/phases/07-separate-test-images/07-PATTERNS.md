# Phase 7: Separate test images - Pattern Map

**Mapped:** 2026-11-14
**Files analyzed:** 17 (groups of files counted once)
**Analogs found:** 16 / 17

All analog paths below were checked as git-tracked (`git ls-files`). Line numbers are from the current branch; re-grep before editing.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `bin/sbx-lib.sh` (`knownImageTagList`, `check_image_tag`, `sbx_init` call) | utility (allow-list) | request-response | `is_known_agent` in `bin/sbx-lib.sh:118-128` | exact |
| `bin/sbx-lib.sh` (`agentImage`, `run_compose`) | utility | request-response | the same lines (modify in place) | exact |
| `build.sh` (`check_image_tag`, tags, `BASE_IMAGE`) | script | batch | `build_image` in `build.sh:55-69`, Main at `150-165` | exact |
| `compose.yml` (image line) | config | transform | `compose.yml:14` | exact |
| `claude/Dockerfile`, `cursor/Dockerfile` (comment only) | config | n/a | themselves | exact |
| `clean.sh` (comment only) | script | batch | itself | exact |
| `tests/selftest/sbx/image-tag.sh` (new) | test | request-response | `tests/selftest/sbx/upgrade.sh`, `entry.sh` | exact |
| `tests/selftest/sbx/lib.sh` (`start_group`) | test lib | n/a | `start_group` lines 21-33 | exact |
| `tests/guard/start.sh` (`compose_image_follows_the_agent`) | test (guard rule) | transform | itself, lines 67-84 | exact |
| `tests/guard/isolation.sh` (new rule) | test (guard rule) | transform | `no_docker_socket_or_privileges` | exact |
| `host-test.sh` | script | batch | itself (`linter_versions`, `make_linter_standin`) | exact |
| `tests/host/lib.sh` (`host_init`) | test lib | n/a | `host_init` lines 21-37 | exact |
| `tests/host/h01, h12, h17, h22, h25, h27, h29, h30, h33` | test (host check) | request-response | `h01`, `h12` (variable replaces literal) | exact |
| `tests/host/h03` (one assertion) | test (host check) | transform | `h01` `add_problem` style | role-match |
| `tests/host/run-all.sh` (message) | test runner | batch | itself | exact |
| `README.md`, `tests/README.md`, `tests/host-checklist.md` | doc | n/a | neighbouring sections | role-match |
| `tests/selftest/sbx/entry.sh` | test | request-response | keep lines 75, 79 unchanged | n/a |

## Pattern Assignments

### `bin/sbx-lib.sh`: tag allow-list (utility)

**Analog:** `is_known_agent`, `bin/sbx-lib.sh:118-128`.

**Allow-list loop to copy** (banner + local var + loop + `return 1`):
```bash
is_known_agent() {
  local knownAgent

  for knownAgent in $knownAgentList; do
    if [ "$1" = "$knownAgent" ]; then
      return 0
    fi
  done

  return 1
}
```
New `check_image_tag` mirrors it: `local knownTag`, `imageTag=${SBX_IMAGE_TAG:-local}`, loop over `$knownImageTagList`, on miss `sbx_error "SBX_IMAGE_TAG must be ${knownImageTagList// / or }, not '$imageTag'"; return 1`. Declare `knownImageTagList="local test"` beside `knownAgentList`. `${var// /...}` already runs on bash 3.2 (used in `bin/sbx-add`).

**`sbx_init` call site** (`bin/sbx-lib.sh:61-89`): add after the `unset COMPOSE_*` line, before `load_name_rule`:
```bash
  unset COMPOSE_PROJECT_NAME COMPOSE_FILE ...
  check_image_tag || return 1
  load_name_rule
```
Error style in `sbx_init`: `sbx_error "..."; return 1`; callers run under `set -eu`.

**agentImage** (line 176): `agentImage=sbx-$entryAgent:local` becomes `agentImage=sbx-$entryAgent:$imageTag`.

**`run_compose`** (lines 199-207, current):
```bash
SBX_NAME="$sandboxName" SBX_DIR="$entryDir" SBX_AGENT="$entryAgent" docker compose --env-file /dev/null -p "sbx-$sandboxName" -f "$repoDir/compose.yml" "$@" </dev/null
```
Insert `SBX_IMAGE_TAG="$imageTag"` BEFORE `SBX_AGENT=` so the guard's substring `SBX_AGENT="$entryAgent" docker compose` still matches. Update the banner comment: name, dir and agent are never from the caller; the tag comes from the caller only after `check_image_tag`.

---

### `build.sh` (script, batch)

**Analog:** `build_image` (lines 55-69) and Main (lines 150-165).

**Extra options go after TAG, no change to `build_image`:**
```bash
build_image() {
  local dockerfile=$1
  local imageTag=$2

  shift 2

  echo "build.sh: building $imageTag"
  docker build "$@" -f "$dockerfile" "${buildArgList[@]}" -t "$imageTag" .
}
```
Note: `build_image` has a `local imageTag`; a global `imageTag` set by `check_image_tag` is shadowed inside it, which is safe. If the planner wants zero confusion, name the global `selectedTag` in `build.sh` only (the wording of the error must still be identical to `bin/sbx-lib.sh`: `must be local or test`).

**Main today (lines 150-165):**
```bash
cd "$(dirname "$0")"

check_versions_file
load_versions
collect_build_args
prepare_extra_cert || exit 1
print_cert_banner

if [ -n "$extraCertDir" ]; then
  build_image base/Dockerfile sbx-base:local --build-context "cacert=$extraCertDir" "$@"
else
  build_image base/Dockerfile sbx-base:local "$@"
fi

build_image claude/Dockerfile sbx-claude:local "$@"
build_image cursor/Dockerfile sbx-cursor:local "$@"
```
Target shape: `check_image_tag || exit 1` right after `cd`, tags `sbx-base:$imageTag`, and `--build-arg "BASE_IMAGE=sbx-base:$imageTag"` on the claude and cursor builds only. Do not touch `collect_build_args` or `versions.env` (guard `pins_are_exact` would reject it). `prepare_extra_cert || exit 1` is the existing "function returns non-zero, caller exits" pattern to copy. Use `case "$tag" in local | test) ;; *) echo "build.sh: SBX_IMAGE_TAG must be local or test, not '...'" >&2; return 1 ;; esac` (build.sh does not source the lib).

---

### `compose.yml` (config)

**Analog:** line 14, today:
```yaml
image: "sbx-${SBX_AGENT:-claude}:local"
```
Target: `image: "sbx-${SBX_AGENT:-claude}:${SBX_IMAGE_TAG:-local}"`. Keep `pull_policy: never` on the next line. Update the comment above (lines 11-13). Leave line 45 (`name-check` image) alone.

---

### `tests/selftest/sbx/image-tag.sh` (new, test, request-response)

**Analog:** `tests/selftest/sbx/upgrade.sh` (group shape and refusal helper) and `entry.sh:68-82` (registry mapping cases). No registration needed; `run_groups` globs the folder. New file may need `chmod +x`.

**Group shape** (`upgrade.sh:1-12, 55-62`):
```bash
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of ...
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/image-tag.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
...
# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_upgrade_refusals
finish_cases
```

**Refusal helper to reuse** (`upgrade.sh:15-19`):
```bash
refused_before_build() {
  refused_cleanly "$1" "$2" "" "" || return 1
  lacks_text "$WORK/$1.out" "build.sh: building" || return 1
  lacks_text "$WORK/$1.err" "build.sh: building"
}
```
Case body pattern (`upgrade.sh:28-48`): `SBX_CONFIG_DIR=$WORK/cfg-xxx; export SBX_CONFIG_DIR`, `echo '--- title'`, `run_sbx LABEL sbx-script ARGS`, `expect "label" helper LABEL "text"`.

**Registry mapping pattern** (`entry.sh:68-82`):
```bash
plant_entry cursorentry "SBX_DIR=/x/cursor" "SBX_AGENT=cursor"
readOut=$(lib_eval "${readText/NAME/cursorentry}" 2>&1)
expect "registry: a cursor entry maps to sbx-cursor:local" equals "$readOut" "cursor|sbx-cursor:local"
```
For the new group, wrap the tag in a subshell on bash 3.2: `readOut=$( export SBX_IMAGE_TAG=test; lib_eval "..." 2>&1 )`. `lib_eval` is `( . "$BIN/sbx-lib.sh"; sbx_init || exit 1; eval "$1" )` (`lib.sh:93-97`). Helpers available: `expect`, `equals`, `has_text`, `lacks_text` (`lib-expect.sh`), `run_sbx` (output to `$WORK/LABEL.out/.err`, rc in `SBX_RC`), `refused_cleanly LABEL TEXT NAME PATH`.

For `build.sh` cases, run `bash "$REPO/build.sh"` with `DOCKER_HOST` already pointing nowhere (set by `start_group`); assert stdout has `build.sh: building sbx-base:test` / `:local`, and that a bad value prints `must be local or test` and no `building` line. No fake docker (never extend one).

---

### `tests/selftest/sbx/lib.sh` `start_group` (test lib)

**Analog:** lines 21-33:
```bash
  SBX_CONFIG_DIR=$WORK/cfg
  export SBX_CONFIG_DIR
  unset SBX_DIR SBX_NAME DOCKER_CONTEXT
```
Change to `unset SBX_DIR SBX_NAME DOCKER_CONTEXT SBX_IMAGE_TAG SBX_CA_CERT`. This is required: `host-test.sh` exports `SBX_IMAGE_TAG=test` before the Mac self-test, and `entry.sh:75,79` (keep unchanged) expect `:local`. Update the header comment to name the new unsets.

---

### `tests/guard/start.sh` `compose_image_follows_the_agent` (guard rule)

**Analog:** itself, lines 67-84 (`ok=0` accumulator, `grep -Fq`, echo with 4-space indent, `return "$ok"`):
```bash
  if ! grep -Fq 'image: "sbx-${SBX_AGENT:-claude}:local"' $COMPOSE; then
    echo "    $COMPOSE does not take its image from \"sbx-\${SBX_AGENT:-claude}:local\""
    ok=1
  fi

  if ! grep -Fq 'SBX_AGENT="$entryAgent" docker compose' bin/sbx-lib.sh; then
    echo "    bin/sbx-lib.sh does not pass SBX_AGENT=\"\$entryAgent\" to docker compose"
    ok=1
  fi
```
Change the first grep and message to `...:${SBX_IMAGE_TAG:-local}"`; keep the second; add a third block of the same shape for `SBX_IMAGE_TAG="$imageTag"` in `bin/sbx-lib.sh`. Optional fourth: grep `build.sh` for `BASE_IMAGE=sbx-base:$imageTag`. Ship in the same plan as the production edit.

---

### `tests/guard/isolation.sh` new rule `host_tests_never_name_the_local_tag`

**Analog:** `no_docker_socket_or_privileges` (`isolation.sh:13-24`), which calls `nowhere_matches REGEX FILE...` from `tests/guard/lib.sh:31` (prints hits, returns 1 on match, 1 with "no file to scan" if the file list is empty).
```bash
host_tests_never_name_the_local_tag() {
  nowhere_matches ':local\b' host-test.sh tests/host/*.sh
}
```
Register in `run_rules` at `isolation.sh:74-77` (backslash-continued list, last line ends `|| exit 1`):
```bash
run_rules \
  no_docker_socket_or_privileges \
  host_scripts_keep_sandbox_data \
  managed_settings_deny_skill_edits || exit 1
```
Do not scan `tests/selftest/`. Because the rule scans `host-test.sh` and `tests/host/*.sh`, comments naming `:local` in `h22:36` and `host-test.sh:132,145` must be reworded. Bump the rule count in `tests/README.md`.

---

### `host-test.sh` (script)

**Analog:** itself.

**linter_versions today:**
```bash
linter_versions() {
  docker run --rm --entrypoint shellcheck sbx-base:local --version \
    && docker run --rm --entrypoint hadolint sbx-base:local --version
}
```
Use `sbx-base:$SBX_IMAGE_TAG`.

**make_linter_standin today:**
```bash
printf '#!/bin/sh\nexec docker run --rm -v "$PWD:$PWD:ro" -w "$PWD" --entrypoint %s sbx-base:local "$@"\n' "$2" > "$1/$2"
```
Use `sbx-base:%s` with `"$2" "$SBX_IMAGE_TAG"` as printf args so the tag is written into the stand-in (the `"$@"` stays literal).

**Main (lines ~248-254):** assign unconditionally, never `${SBX_IMAGE_TAG:-test}`:
```bash
SBX_IMAGE_TAG=test
export SBX_IMAGE_TAG
```
after `cd`, before `main 2>&1 | tee`. Add a line to `show_context` (lines 44-49) naming the test tags.

---

### `tests/host/lib.sh` `host_init`, and the nine host checks

**Analog:** `host_init` (lines 21-37), which already exports `SBX_NAME`:
```bash
  SBX_NAME=hosttest
  export SBX_NAME
```
Add the same two-line style: `SBX_IMAGE_TAG=test` / `export SBX_IMAGE_TAG`, then `baseImage=sbx-base:$SBX_IMAGE_TAG` and `claudeImage=sbx-claude:$SBX_IMAGE_TAG`.

**Host check literal today** (`h01-native-arch.sh:31`, `h12:16,18`):
```bash
for imageName in sbx-base:local sbx-claude:local; do
plainOutput=$(docker run --rm sbx-claude:local claude --version </dev/null 2>&1)
pinOutput=$(docker run --rm --entrypoint claude sbx-claude:local --version </dev/null 2>&1)
```
Becomes `"$baseImage"` / `"$claudeImage"`. Full list and lines are in 07-RESEARCH.md Inventory section 3 (h01, h12, h17:60, h22:42,236, h25:31,51,56,70, h27:91, h29:203, h30:35,38, h33:280-285). Do not add `env -i` to any test lib: `env PATH=... "$@"` in `lib-sbx.sh` and `compose_cmd` in `lib-sandbox.sh` must keep inheriting the exported tag.

**h03 assertion:** follow the `add_problem` style used in `h01:31-37`:
```bash
add_problem "$imageName is $imageArch; expected $expected"
```
New check uses `grep -F "image: $claudeImage"` (no `-x`, indent-proof) on `$nameOutput`.

---

## Shared Patterns

### Allow-list value check
**Source:** `is_known_agent` (`bin/sbx-lib.sh:118-128`)
**Apply to:** `check_image_tag` in `bin/sbx-lib.sh`; the `case` form in `build.sh`. Keep the message `must be local or test` identical in both.

### "Set on the one command, never from the caller"
**Source:** `run_compose` (`bin/sbx-lib.sh:199-207`)
**Apply to:** the tag hand-off to compose; only the checked `$imageTag` is passed.

### Test run owns its environment
**Source:** `host_init` exports (`tests/host/lib.sh:29-31`), `start_group` unsets (`tests/selftest/sbx/lib.sh:30`)
**Apply to:** host libs export `test` unconditionally; self-test groups unset so default-case `:local` expectations hold.

### Shell layout rules (CLAUDE.md and global rules)
Banner of 80 dashes above each function, `Main / Entry Point` banner, braces always, blank line around control flow, full variable names, bash 3.2 and BSD portable, ASCII only, no planning IDs (D-xx, IMG-xx, phase numbers) in code or comments, no dashes as punctuation in comments and docs.

### Guard-rule edits land with the production edit
`tests/guard/start.sh` greps the exact compose line and the `run_compose` text, so the guard update belongs in the same plan as the `compose.yml` and `bin/sbx-lib.sh` edits.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `docker image inspect` over all three test tags after `build_all_images` in `tests/host/run-all.sh` (optional) | test | batch | No host step checks the cursor image today; follow `check_image_architectures` (`h01`) style if the planner adds it. |

## Not changed

- `tests/selftest/sbx/entry.sh:75,79` keep `sbx-cursor:local` and `sbx-claude:local` (default case).
- `claude/Dockerfile:7`, `cursor/Dockerfile:7` keep `ARG BASE_IMAGE=sbx-base:local` byte-exact (guard `supply-chain.sh:127` allows only that line).
- `clean.sh` code: `docker image prune -a -f` already removes unused `:test` images; edit comments at lines 116-117 only.
- `tests/host/lib-docker.sh`, `lib-sandbox.sh`, `lib-sbx.sh`: inherit the export; at most a comment.

## Metadata

**Analog search scope:** `bin/`, `build.sh`, `compose.yml`, `host-test.sh`, `tests/selftest/`, `tests/guard/`, `tests/host/`
**Files scanned:** about 20
**Pattern extraction date:** 2026-11-14
