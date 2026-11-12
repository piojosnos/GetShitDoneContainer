# Phase 3: Remembered Sandboxes and One-Command Upgrade - Pattern Map

**Mapped:** 2026-11-06
**Files analyzed:** 22 new/modified
**Analogs found:** 21 / 22 (all analogs verified git-tracked via `git ls-files`)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `bin/sbx-lib.sh` (new, mode 644) | library | request-response | `base/sbx-start-lib.sh` | exact (role) |
| `bin/sbx-add` (new, 755) | host script | file-I/O | `build.sh` (layout) + `base/sbx-start-lib.sh` (name check) | role-match |
| `bin/sbx-start` (new, 755) | host script | request-response | `build.sh` + `tests/host/lib-sandbox.sh` `compose_cmd`/`compose_up` | role-match |
| `bin/sbx-stop` (new, 755) | host script | request-response | `build.sh` + `compose_cmd` | role-match |
| `bin/sbx-upgrade` (new, 755) | host script | batch | `build.sh` (forwards `"$@"`) + `compose_up` | role-match |
| `base/sbx-start-lib.sh` (mod: reserved-name variable) | library | transform | itself, lines 12-15 and 60-65 | exact |
| `base/Dockerfile` (mod: version file + bashrc line) | config | file-I/O | itself, lines 149 and 166-174 | exact |
| `claude/Dockerfile` (mod: prepend claude fields) | config | file-I/O | itself, lines 70-94 | exact |
| `tests/selftest/sbx/run-all.sh` (new) | test runner | batch | `tests/selftest/entrypoint/run-all.sh` | exact |
| `tests/selftest/sbx/lib.sh` (new) | test lib | transform | `tests/selftest/entrypoint/lib.sh` | exact |
| `tests/selftest/sbx/*.sh` groups (new) | test | file-I/O | `tests/selftest/entrypoint/start-folders.sh` | exact |
| `tests/host/h28-*.sh` lifecycle (new) | test | request-response | `tests/host/h11-stop-is-quick-and-safe.sh` | exact |
| `tests/host/h29-*.sh` upgrade (new) | test | request-response | `tests/host/h09-rebuild-keeps-files-no-volumes.sh` | role-match |
| `tests/host/h30-*.sh` version line (new) | test | request-response | `tests/host/h25-images-match-versions.sh` | role-match |
| `tests/host/manual/h29-upgrade-resume.sh` (new) | test (attended) | request-response | `tests/host/manual/h09-rebuild-resume.sh` | exact |
| `tests/host/run-all.sh` (mod: lists) | test runner | batch | itself, lines 20-26 | exact |
| `host-test.sh` (mod: `mac_sbx_selftest`) | test runner | batch | `mac_guard` (line 141), `run_step` (line 187) | exact |
| `tests/guard/lib.sh` (mod: `SHELL_FILES`) | config | transform | itself, line 22 | exact |
| `tests/guard/supply-chain.sh` (mod: file lists) | test | transform | itself, lines 13, 35 | exact |
| `tests/selftest/guard/sandbox-rules.sh` (mod: planted cases) | test | transform | itself | exact |
| `SANDBOX.md`, `tests/README.md`, `tests/host-checklist.md` (mod) | doc | n/a | neighbouring sections | exact |
| Registry file `~/.config/sbx/sandboxes/<name>` | data | file-I/O | none | no analog |

## Pattern Assignments

### Banner and script layout (all `bin/*` scripts)

**Analog:** `/home/sandbox/GetShitDoneContainer/build.sh` lines 1-18, 69-78.

```bash
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Builds sbx-base:local, then sbx-claude:local, with the pins in versions.env
# ------------------------------------------------------------------------------
# Usage: ./build.sh [DOCKER_BUILD_OPTION...]
# Extra options go to both builds, for example --no-cache.
# ------------------------------------------------------------------------------
set -eu

# ------------------------------------------------------------------------------
# check_versions_file: stops when versions.env is not next to this script
# ------------------------------------------------------------------------------
check_versions_file() {
  if [ ! -f ./versions.env ]; then
    echo "build.sh: versions.env is missing next to build.sh" >&2
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
cd "$(dirname "$0")"
check_versions_file
```

Copy: banner, `set -eu`, one function per step with `name: purpose` header, `Main / Entry Point` at the bottom, error message prefixed with script name on stderr. Note `build.sh` does `cd "$(dirname "$0")"`; `sbx-*` scripts must NOT `cd` (the user's cwd is irrelevant, but compute `repoDir=$(cd "$(dirname "$0")/.." && pwd -P)` instead; `sbx-lib.sh` is sourced via `. "$(dirname "$0")/sbx-lib.sh"`, the same form `tests/host/h11` line 8 uses). Hint: when `bin/` is reached through PATH, `$0` holds the full path, so `dirname "$0"` works.

`sbx-upgrade` forwards build options like `build.sh` does: `shift` the name, then `"$repoDir/build.sh" "$@" || exit 1` as its own statement (see build.sh lines 59-67 `shift 2` then `"$@"`). Do not wrap in `if`.

---

### `bin/sbx-lib.sh` (library)

**Analog:** `/home/sandbox/GetShitDoneContainer/base/sbx-start-lib.sh`

Header for a library (lines 1-6): "A library: defines variables and functions, runs nothing, sets no options."

**Name check pattern** (lines 52-58), copy shape with `LC_ALL=C` and a regex in a variable:
```bash
check_sandbox_name() {
  local LC_ALL=C

  if [[ ! "${SBX_NAME:-}" =~ $sandboxNamePattern ]]; then
    start_error "SBX_NAME \"${SBX_NAME:-}\" breaks the sandbox name rule: $sandboxNameRuleText. Example: my-project."
    return 1
  fi
```

**Rule loading** (do not copy the regex; RESEARCH Code Examples): read it from the base library in a subshell so `ws`, `state`, `hookDir` do not leak:
```bash
nameRulePattern=$(. "$repoDir/base/sbx-start-lib.sh" && printf '%s' "$sandboxNamePattern")
nameRuleText=$(. "$repoDir/base/sbx-start-lib.sh" && printf '%s' "$sandboxNameRuleText")
```
Same for the new reserved-name variable (D-20).

**Registry read** (no analog in repo; use RESEARCH Pattern 1: `while IFS= read -r line || [ -n "$line" ]` with `case` on `SBX_DIR=*` / `SBX_AGENT=*`; never source). Bash 3.2 rules: no arrays-empty expansion under `set -u`, `local v; v=$(cmd)` split when status matters, regex in a variable.

**run_compose** (analog `tests/host/lib-sandbox.sh` lines 23-34):
```bash
compose_cmd() {
  SBX_NAME=hosttest SBX_DIR="$RUN" docker compose --env-file /dev/null -f "$REPO_DIR/compose.yml" "$@" </dev/null
}
```
Add `-p "sbx-$sandboxName"` (RESEARCH Pattern 2). Keep the `--env-file /dev/null` comment.

**Wait for start hooks** (analog `tests/host/lib-sandbox.sh` lines 146-175): copy the loop (`pgrep -x sleep` probe, `docker container inspect --format '{{.State.Running}}'` to detect a dead container, `case "$limitSeconds" in ''|*[!0-9]*)` guard, 120 s bound). Replace `$CONTAINER` with `sbx-$name`, print `docker logs sbx-$name` hint, and add a short self-contained comment that a compose healthcheck should replace it. Do not use planning IDs.

**Error helper** (analog `start_error`, lines 29-32): one function printing `sbx: ...` to stderr.

---

### `base/sbx-start-lib.sh` (modify: reserved-name variable, D-20)

Current lines 12-15 and 60-65:
```bash
sandboxNamePattern='^[a-z][a-z0-9-]{0,30}$'
sandboxNameRuleText='starts with ...'
...
  case "$SBX_NAME" in
    state | best-practices)
      start_error "SBX_NAME \"$SBX_NAME\" is taken: ..."
```
Add `sandboxReservedNameList="state best-practices"` beside the pattern; make the check loop over it with a `for` and braces (imperative style; no `case` with a fixed list). Keep existing entrypoint self-test (`tests/selftest/entrypoint/start-folders.sh`) and H-21 green. The file already sits in `SHELL_FILES`.

---

### `base/Dockerfile` and `claude/Dockerfile` (version file)

**Analog base:** `base/Dockerfile` lines 143-149, comment banner then root `RUN mkdir -p /etc/sbx/start.d`, ARGs `NODE_VERSION` (38) and `MAVEN_VERSION` (76) already in scope before it. Insert the RESEARCH Pattern 4 `RUN printf ... > /etc/sbx/tool-versions` right after line 149, before `USER sandbox` (157), with a banner comment block in the same dash style. Separator ` | `, full Python version (D-22). Smoke tests at lines 166-174 already prove the pins.

**Analog claude:** `claude/Dockerfile` lines 70-77: root section (`COPY`, `RUN chmod ...`) before `USER sandbox` at 77; ARGs at 17, 31, 43 are in scope. Add the prepend `RUN` there (write to `/tmp`, then `mv`, per RESEARCH). Do not add a COPY; `.dockerignore` is an allowlist. Keep the "Last RUN" smoke test (line ~84) and the `COPY --chmod=644 versions.env` (line 94) as the last items; keep hadolint style (`&&` chains, `\` continuation).

Bashrc hook: append a single line to `/etc/bash.bashrc` (after Ubuntu's `PS1` guard), so only interactive shells print.

---

### `tests/selftest/sbx/` (docker-free suite)

**Analogs:** `tests/selftest/entrypoint/run-all.sh` (all 14 lines), `tests/selftest/entrypoint/lib.sh`, `tests/selftest/entrypoint/start-folders.sh`.

`run-all.sh` copy verbatim, retitle:
```bash
set -u
. "$(dirname "$0")/../lib-expect.sh"
require_no_arguments "$@" || exit 2
run_groups "$(dirname "$0")"
report_and_exit
```
`lib.sh` copy `start_group`: `enter_repo_root`, then `make_work_folder sbxtest`, set `SBX_CONFIG_DIR="$WORK/cfg"` for every case. Groups use `expect NAME cmd...`, `equals`, `has_text`, `lacks_text`, end with `finish_cases`. Group header (start-folders.sh lines 1-8) is the template. Cases: duplicate, bad name, `state`, `best-practices`, relative path, path containing the registry, path used by another entry, path with a space, a planted `$(touch x)` in a value that must not run, no registry entry written on a refusal, `BASH_VERSION` printed.

---

### `tests/host/h28-*.sh`, `h29-*.sh`, `h30-*.sh`

**Analog:** `/home/sandbox/GetShitDoneContainer/tests/host/h11-stop-is-quick-and-safe.sh`

```bash
set -u
. "$(dirname "$0")/lib.sh"
host_init
...
add_problem "compose down failed (exit $downStatus); log: $RUN/logs/h11-down.log"
...
require_no_arguments "$@" || exit 2
require_test_sandbox H-11 || exit 1
plant_sentinels
stop_sandbox
check_stop_was_clean
check_sentinels_intact
start_sandbox_again
report_check H-11 "stopping is not quick and safe" \
  "compose down took $elapsedSeconds s, the container is gone, the folders are intact"
```
Copy: header banner with `Needs:` line, one function per verdict, `add_problem` for each failure, `report_check` last, sentinel files under `$RUN/hosttest` and `$RUN/state`. H-28/H-29 differ: use `SBX_CONFIG_DIR="$RUN/sbxcfg"` and fail first if it is empty or not under `$RUN`; run scripts as found on `PATH` and also with `/bin/bash`; end with `compose_down` then `compose_up` to restore the normal `$RUN` (see `restart_test_sandbox`, lib-sandbox.sh 226-241). Do not call `require_test_sandbox` after starting the spaced sandbox. Use `run_timeout` (lib-sandbox.sh 87) around slow calls.

**H-29** also follows `h09-rebuild-keeps-files-no-volumes.sh` (rebuild keeping files, no volume appears); read it when planning (not extracted here). Compare container id before and after; negative case uses a bogus build flag.

**H-30 analog:** `tests/host/h25-images-match-versions.sh` uses `docker run --rm --entrypoint cat sbx-claude:local /etc/sbx/versions.env`; reuse for `/etc/sbx/tool-versions`, and `pin_of NAME` for expected values. Interactive probe: `docker exec -i "$CONTAINER" bash -i </dev/null 2>/dev/null` (RESEARCH).

**Manual:** `tests/host/manual/h09-rebuild-resume.sh` with `tests/host/manual/lib-manual.sh`.

**Registration:** `tests/host/run-all.sh` lines 20-26. Add H-28/H-29 to `chainCheckList` after `h09-...` and before `h20-...`; H-30 to `sandboxCheckList`. Update the "H-00 to H-27" counts in `host-test.sh`, `tests/README.md`, `tests/host-checklist.md`.

---

### `host-test.sh` (add `mac_sbx_selftest`)

**Analog:** `mac_guard` at line 141 and its step call at line 187:
```bash
run_step "guard in the Mac shell" mac_guard
```
Add a sibling function running `/bin/bash tests/selftest/sbx/run-all.sh` with output printed and non-zero status failing the step, plus `run_step "sbx self-test in the Mac shell" mac_sbx_selftest` next to it. No linter stand-ins are needed.

---

### Guard edits

- `tests/guard/lib.sh` line 22: append `bin/*` to `SHELL_FILES` (current value: `build.sh clean.sh host-test.sh base/sbx-entrypoint base/sbx-start-lib.sh claude/start.d/* claude/bin/* tests/*/*.sh ...`). `bin/*` does not collide with `claude/bin/*`.
- `tests/guard/supply-chain.sh` rules at lines 13 (`no_compromised_gsd_package`) and 35 (`no_pipe_to_shell_installers`): add `bin/*` to their file lists, with the rule list at ~158-160 unchanged.
- Optional rules (RESEARCH): use `nowhere_matches REGEX FILE...` (lib.sh) and add a planted case in `tests/selftest/guard/sandbox-rules.sh` for each.

## Shared Patterns

### Shell portability (bash 3.2, BSD tools)
**Apply to:** every `bin/*` file and every new test.
No `mapfile`, `declare -A`, `${var,,}`, `sed -i`, `readlink -f`, `stat -c`. Empty array under `set -u` must be count-checked. `build.sh` line 41 (`buildArgList=()`, `+=`) is fine on 3.2.

### Code style
**Apply to:** all shell. Braces on every `if`/`for`/`while`, blank line before and after control flow, full camelCase names, collection suffix `List`, ASCII only, no planning IDs, no dash punctuation in comments or text.

### Data safety
**Apply to:** the four scripts. Never `source`/`eval` the registry, never `down -v`, `rm`, `prune`, `docker rm/stop` by name. All Compose through one wrapper with `-p`, `-f`, `--env-file /dev/null`, variables set on the command.

### File modes
New scripts committed 100755 (`git add --chmod=+x`), `bin/sbx-lib.sh` 100644; verify with `git ls-files -s bin`.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `~/.config/sbx/sandboxes/<name>` registry read/write code | data store | file-I/O | No data-file parser exists host-side; use RESEARCH Patterns 1 and 5 (line-by-line `read`, temp file plus `mv` in the same folder) |

## Metadata

**Analog search scope:** repo root, `base/`, `claude/`, `tests/` (guard, selftest, host), `host-test.sh`
**Files read in full or by range:** build.sh, base/sbx-start-lib.sh, tests/host/lib-sandbox.sh, h11, lib-expect.sh, selftest/entrypoint (run-all, lib, start-folders), Dockerfile ranges, host-test.sh range, guard lib range
**Not read (planner should open):** h09, h25, h10, manual/h09-rebuild-resume.sh, lib-manual.sh, supply-chain.sh bodies
**Pattern extraction date:** 2026-11-06
