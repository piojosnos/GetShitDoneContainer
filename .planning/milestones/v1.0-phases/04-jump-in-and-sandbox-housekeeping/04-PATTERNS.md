# Phase 4: Jump-In and Sandbox Housekeeping - Pattern Map

**Mapped:** 2026-11-07
**Files analyzed:** 17 new or modified
**Analogs found:** 17 / 17

All analog paths below were confirmed git-tracked with `git ls-files`.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `bin/sbx-shell` | host script | request-response (start if needed, then exec) | `bin/sbx-start` | exact |
| `bin/sbx-list` | host script | batch/transform (read registry + one docker call) | `bin/sbx-add` (registry loop, lines 229-235) + `bin/sbx-stop` (shape) | role-match |
| `bin/sbx-rm` | host script | request-response (compose down, optional delete) | `bin/sbx-stop` | exact |
| `bin/sbx-lib.sh` (modify: add `runs_older_image`, `bring_up_sandbox`) | library | request-response | `warn_if_older_image` + `start_sandbox` in `bin/sbx-start` | exact (move) |
| `bin/sbx-start` (modify: use lib, new hint) | host script | request-response | itself | exact |
| `tests/guard/isolation.sh` (modify `host_scripts_keep_sandbox_data`) | guard rule | transform | same file, `nowhere_matches` use | exact |
| `tests/selftest/guard/sandbox-rules.sh` (modify `case_host_script_rule`) | test | transform | same function, lines 142-150 | exact |
| `tests/selftest/sbx/lib.sh` (modify stand-in) | test helper | event-driven (file-driven fake) | `make_scripted_docker` | exact |
| `tests/selftest/sbx/shell.sh` | test | request-response | `tests/selftest/sbx/start.sh` | exact |
| `tests/selftest/sbx/list.sh` | test | request-response | `tests/selftest/sbx/start.sh`, `entry.sh` | role-match |
| `tests/selftest/sbx/rm.sh` | test | request-response | `tests/selftest/sbx/upgrade.sh` | exact |
| `tests/host/h31-sbx-shell-list.sh` | host check | request-response | `tests/host/h28-sbx-add-start-stop.sh` | exact |
| `tests/host/h32-sbx-rm.sh` | host check | request-response | `tests/host/h29-sbx-upgrade.sh` | exact |
| `tests/host/manual/h31-jump-in.sh` | manual helper | request-response | `tests/host/manual/h29-upgrade-resume.sh` | exact |
| `tests/host/run-all.sh` (modify `chainCheckList`) | config | batch | line 24 | exact |
| `tests/host-checklist.md`, `tests/README.md`, `host-test.sh` comment | docs | n/a | existing rows (H-28..H-30) | exact |
| `SANDBOX.md` (modify) | docs | n/a | its "Start, enter, stop" section | exact |

Do NOT edit `README.md` (guard `old_layout_untouched`).

## Pattern Assignments

### `bin/sbx-lib.sh` additions (library)

**Analog:** `bin/sbx-start` lines 16-47 (to be moved). Library functions use the banner block form and `local` declarations on separate lines from assignments (`bin/sbx-lib.sh:208-214`).

**Style to copy** (`bin/sbx-lib.sh:204-214`):
```bash
# ------------------------------------------------------------------------------
# sandbox_is_running NAME: true when the container sbx-NAME is running
# ------------------------------------------------------------------------------
# A missing container is false, not an error.
# ------------------------------------------------------------------------------
sandbox_is_running() {
  local runningState

  runningState=$(docker container inspect --format '{{.State.Running}}' "sbx-$1" 2>/dev/null </dev/null) || return 1

  [ "$runningState" = "true" ]
}
```

**Comparison to move into `runs_older_image`** (`bin/sbx-start:31-36`):
```bash
  runningImage=$(docker container inspect --format '{{.Image}}' "sbx-$1" 2>/dev/null </dev/null) || return 0
  currentImage=$(docker image inspect --format '{{.Id}}' "$claudeImage" 2>/dev/null </dev/null) || return 0

  if [ "$runningImage" != "$currentImage" ]; then
    warn_sessions_close "$1" "runs on an older image; recreating it on the new one"
  fi
```
In the lib, failed inspect returns 1 (false), so list and start never mark on error. Keep the warning text byte for byte (start selftest asserts it).

**`bring_up_sandbox NAME`** = `check_sandbox_folders`, `require_images`, `if runs_older_image then warn_sessions_close`, `start_sandbox` body (`bin/sbx-start:42-47`: `if ! run_compose "$1" up -d --wait; then sbx_error "docker compose up failed; docker logs sbx-$1 shows why"; return 1; fi`), `wait_until_ready`. Call it from a plain statement or `if !` test only as the research Pattern 1 notes (never `|| exit`, errexit is off in test context).

---

### `bin/sbx-shell` (host script, request-response)

**Analog:** `bin/sbx-start` (banner, header, Main).

**Header and banner** (`bin/sbx-start:1-14`):
```bash
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Starts a registered sandbox by name and waits until its start hooks are done
# ------------------------------------------------------------------------------
# Usage: sbx-start NAME
# ...
# ------------------------------------------------------------------------------

# The library sets claudeImage.
# shellcheck disable=SC2154
set -eu

. "$(dirname "$0")/sbx-lib.sh"
```

**Main skeleton** (`bin/sbx-start:52-55`):
```bash
[ "$#" -eq 1 ] || sbx_usage 'NAME'
sbx_init
check_name "$1"
read_registry_entry "$1"
```
Then `if ! sandbox_is_running "$1"; then bring_up_sandbox "$1"; fi` and finally a function with `exec docker exec -it -w "/home/sandbox/workspace/$1" "sbx-$1" bash`. No `</dev/null` on that line; no `[ -t 0 ]` check (banner should say why it differs from other docker calls). Apply the blank-line-around-control-flow and braces rules.

---

### `bin/sbx-rm` (host script, request-response)

**Analog:** `bin/sbx-stop` (whole file, 34 lines).

**Function shape and error text** (`bin/sbx-stop:15-23`):
```bash
stop_sandbox() {
  if ! run_compose "$1" stop; then
    sbx_error "docker compose stop failed for sbx-$1"
    return 1
  fi
}
```
Copy as `run_compose "$1" down` (no `-v`, `--rmi`, `--remove-orphans`).

**Closing line** (`bin/sbx-stop:33`):
```bash
echo "sbx-stop: sbx-$1 is stopped; nothing in $entryDir was changed"
```
**Warning before removing a running sandbox:** `if sandbox_is_running "$1"; then warn_sessions_close "$1" "is running; removing it"; fi` (lib `warn_sessions_close`, `bin/sbx-lib.sh:222-224`).

Only deletion in `bin/`: `rm -- "$entryFile"` after `down` succeeded. Do not call `check_sandbox_folders` or `require_images`. Parse `NAME`, `NAME --unregister`, `--unregister NAME` without arrays (bash 3.2 `set -u`). Wrong shape: `sbx_usage 'NAME [--unregister]'`.

---

### `bin/sbx-list` (host script, batch/transform)

**Analog:** registry loop in `bin/sbx-add:229-235`:
```bash
  for entryPath in "$registryDir"/*; do
    if [ ! -f "$entryPath" ]; then
      continue
    fi

    otherName=${entryPath##*/}
    read_registry_entry "$otherName" || return 1
```
For list, replace the `|| return 1` with `if read_registry_entry "$entryName" 2>/dev/null; then ... else error row; fi` (an unreadable entry is a row, not a failure; call it directly, not in `$(...)`, so `entryDir` survives). Add `check_name "$entryName" 2>/dev/null` for hand-made files.

**Docker call:** one `docker ps -a --filter label=sbx.name --format '{{.Names}} {{.State}}' </dev/null`, failure exits 1 with `sbx_error` (never treated as empty). Map: `running` stays; every other state is `stopped`; no match is `no container`. Running sandboxes call `runs_older_image` for the marker. Use `printf '%-31s'` fixed widths (no `%-*s`, no `column`), path last. Leftover section only when a labelled `sbx-X` has no `$registryDir/X`. Words `rm`, `down`, `kill`, `prune` must not appear anywhere in this file (guard).

Arguments: `[ "$#" -eq 0 ] || sbx_usage ''`.

---

### `bin/sbx-start` (modify)

Drop `warn_if_older_image` and `start_sandbox`; Main becomes `sbx_usage`, `sbx_init`, `check_name`, `read_registry_entry`, `bring_up_sandbox "$1"`, `echo "sbx-start: sbx-$1 is running"`, and hint `echo "sbx-start: open a shell with: sbx-shell $1"` (replaces `bin/sbx-start:62`). Keep the "The library sets claudeImage" shellcheck comment only if still needed.

---

### `tests/guard/isolation.sh` (modify rule)

**Current** (`tests/guard/isolation.sh:38-40`):
```bash
host_scripts_keep_sandbox_data() {
  nowhere_matches '\b(rm|rmdir|prune|kill|down)\b|--volumes' bin/*
}
```
Rewrite in place (keep 19 rules): broad regex over every `bin/*` except `bin/sbx-rm` (use a loop or a file list built without `bin/sbx-rm`); narrower regex on `bin/sbx-rm` forbidding `rmdir|prune|kill|--volumes|--rmi|--remove-orphans`, `down` followed by `-v`, and any command `rm` (`(^|[^A-Za-z-])rm[[:space:]]`) whose operand is not `"$entryFile"`. Must land before or with `bin/sbx-rm`. Update the banner comment (it says bin/ has no delete or take-down).

### `tests/selftest/guard/sandbox-rules.sh` (modify)

**Analog** (`tests/selftest/guard/sandbox-rules.sh:142-150`):
```bash
  clean_copy_passes "host scripts: a clean copy passes the data rule" isolation.sh host_scripts_keep_sandbox_data
  plant_case "host scripts: a compose take-down in sbx-stop fails" isolation.sh host_scripts_keep_sandbox_data "bin/sbx-stop" append_scratch_line bin/sbx-stop 'run_compose "$1" down -v'
  plant_case "host scripts: a delete in sbx-upgrade fails" isolation.sh host_scripts_keep_sandbox_data "bin/sbx-upgrade" append_scratch_line bin/sbx-upgrade 'rm -rf "$entryDir"'
```
Add planted cases: `down -v` in sbx-rm, `--rmi` in sbx-rm, `rm -rf "$entryDir"` in sbx-rm, `rm -- "$entryDir"` in sbx-rm, `rm` in sbx-list, `down` in sbx-shell.

---

### `tests/selftest/sbx/lib.sh` (modify stand-in)

**Analog:** `make_scripted_docker` (`tests/selftest/sbx/lib.sh:41-66`): each stand-in line is a `printf '%s\n' '...'` inside a `{ ...; } >"$WORK/scripted/docker"`, a `case "$1" in` on the subcommand, calls logged to `$WORK/standin-calls`. Add: `ps)` branch that cats `$state/ps-lines` (absent is empty; `ps-fail` file means exit 1), `exec)` branch where `-it` args exit with `$state/shell-status` (default 0) while keeping `exec-ok` for `pgrep`, `compose)` exits 1 when `$state/compose-fail` exists. `set_standin_state` wipes the state dir, so cases set extra knobs after it. Move `appears_before` (`tests/selftest/sbx/start.sh:31-39`) into `lib.sh` since shell.sh also uses it.

### `tests/selftest/sbx/shell.sh`, `list.sh`, `rm.sh` (tests)

**Analog:** `tests/selftest/sbx/upgrade.sh` (header, `set -u`, `. "$(dirname "$0")/lib.sh"`, per-case `SBX_CONFIG_DIR=$WORK/cfg-X; export`, `run_sbx LABEL script args`, `expect "msg" fn ...`, Main):
```bash
require_no_arguments "$@" || exit 2
start_group || exit 1
case_upgrade_refusals
expect "sbx-upgrade: no case reached docker" no_docker_call
finish_cases
```
Use `refused_cleanly`, `usage_printed`, `plant_entry`, `run_sbx_scripted`, `set_standin_state`, `appears_before` (`tests/selftest/sbx/start.sh:57`: `appears_before "$WORK/olderstart.out" "will close its open shells" "standin: compose"`). The groups are picked up by `run-all.sh` automatically.

---

### `tests/host/h31-sbx-shell-list.sh`, `h32-sbx-rm.sh` (host checks)

**Analog:** `tests/host/h29-sbx-upgrade.sh` and `h28-sbx-add-start-stop.sh`.

**Header and helpers** (`h29:6-45`): `set -u`, `. "$(dirname "$0")/lib.sh"`, `host_init`, `. "$(dirname "$0")/lib-sbx.sh"`; copy `list_project_volumes` and `list_other_containers` verbatim for H-32; `prepare()` pattern: `compose_down`, `run_sbx hNN-add sbx-add hosttest "$sbxDir"`, check `sbxStatus`, `fail ID "..."`, `restore_test_sandbox`. Use `sbx_test_setup H-31 h31` (`tests/host/lib-sbx.sh:16`). Do not delete files in host checks; assert only on `hosttest` lines in list output; run `script` for the pty inside `run_timeout`.

**Chain registration** (`tests/host/run-all.sh:24`): insert `h31-sbx-shell-list.sh h32-sbx-rm.sh` after `h29-sbx-upgrade.sh` in `chainCheckList`.

### `tests/host/manual/h31-jump-in.sh`

**Analog:** `tests/host/manual/h29-upgrade-resume.sh` with `lib-manual.sh` (`require_terminal`).

## Shared Patterns

### Script scaffold
**Source:** `bin/sbx-stop:1-13, 25-33`. Applies to all three scripts: 80-col banner, title, Usage line, `# shellcheck disable=SC2154` note, `set -eu`, source `sbx-lib.sh` via `"$(dirname "$0")"`, functions, `Main / Entry Point` banner, `[ "$#" -eq N ] || sbx_usage '...'`, `sbx_init`, `check_name "$1"`, `read_registry_entry "$1"`.

### Error and usage
**Source:** `bin/sbx-lib.sh:15-27`: `sbx_error "msg"` (stderr, prefixed with script name), `sbx_usage 'ARGS'` (exit 2).

### Scoped compose
**Source:** `bin/sbx-lib.sh:184-189` `run_compose NAME ARG...`; every docker call reads `</dev/null` except the interactive exec.

### Conventions (all new code)
Braces always, blank line before and after each control block, camelCase locals with collection suffixes, full names, ASCII only, no planning IDs in source, no `--` or em dashes in comments or docs (flags like `--unregister` excepted), bash 3.2 and BSD tools only, no `local x=$(cmd)`. After creating files run `chmod +x bin/sbx-shell bin/sbx-list bin/sbx-rm` (and new test scripts matching neighbours) and confirm `git ls-files -s` shows 100755; `sbx-lib.sh` stays 644.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | | | `exec docker exec -it` and the BSD `script` pty driver in H-31 have no in-repo precedent; use RESEARCH.md Pattern 1 and Pitfall 7 |

## Metadata

**Analog search scope:** `bin/`, `tests/guard/`, `tests/selftest/{sbx,guard}/`, `tests/host/`, `tests/host/manual/`
**Files read:** `bin/sbx-lib.sh`, `bin/sbx-start`, `bin/sbx-stop`, `bin/sbx-add` (excerpt), `tests/guard/isolation.sh`, `tests/selftest/sbx/{lib,upgrade}.sh`, `tests/selftest/guard/sandbox-rules.sh` (excerpt), `tests/host/h29-sbx-upgrade.sh`, `tests/host/lib-sbx.sh`, `tests/host/run-all.sh` (excerpt)
**Pattern extraction date:** 2026-11-07
