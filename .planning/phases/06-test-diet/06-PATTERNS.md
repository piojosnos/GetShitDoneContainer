# Phase 6: Test diet - Pattern Map

**Mapped:** 2026-11-13
**Files analyzed:** 9 new or reshaped pieces (the rest of the phase is deletions and trims, inventoried in 06-RESEARCH.md sections 1, 2, 4, 7 and 9)
**Analogs found:** 9 / 9

All analog paths below are git-tracked (checked with `git ls-files`).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `tests/host/lib-login.sh` (new) | utility (host test library) | file-I/O | `tests/host/lib-sbx.sh`, plant code in `tests/host/h09-rebuild-keeps-files-no-volumes.sh` | role-match |
| `tests/host/h09-rebuild-keeps-files-no-volumes.sh` (edit) | test | file-I/O | itself (`plant_sentinels`, `check_sentinels_survived`) | exact |
| `tests/host/h29-sbx-upgrade.sh` (edit) | test | file-I/O | itself (`plant_and_snapshot`, `check_upgrade`) | exact |
| `tests/guard/isolation.sh` (edit: add one rule, trim one) | test (guard rule) | transform (file grep) | `no_docker_socket_or_privileges` in the same file | exact |
| `tests/guard/supply-chain.sh` (edit: add one rule, fix one glob) | test (guard rule) | transform | `dockerfile_args_have_no_defaults` in the same file | exact |
| `host-test.sh` (edit: preflight line, comments, suite list) | config / runner | request-response | `show_context`, `main` in the same file | exact |
| `tests/host/h28-sbx-add-start-stop.sh` (edit: timing fold) | test | request-response | `check_stop` in the same file, timing idiom from the deleted H-11 | exact |
| `tests/selftest/sbx/lib.sh` (edit: `start_group`) | utility | transform (environment setup) | the existing `start_group` lines 16-37 | exact |
| `tests/host/run-all.sh` (edit: lists, `print_next_block`, `run_compose_check`) | runner | batch | itself, lines 21-26, 143-156, 239-248 | exact |

## Pattern Assignments

### `tests/host/lib-login.sh` (utility, file-I/O)

**Analog:** the sentinel plant in `tests/host/h09-rebuild-keeps-files-no-volumes.sh` (lines 33-41, 70-78), the session path in `tests/host/h16-live-clone-and-restart.sh` line 17 (`sessionFile=$syncedDir/projects/-home-sandbox-workspace-hosttest/h16-session.jsonl`, planted at line 120 with `printf '%s\n' "$sentinelText" >"$sessionFile"`), and the library shape in `tests/host/lib-sbx.sh` (functions only, sourced after `host_init`, as in `h29-sbx-upgrade.sh` lines 9-11).

**Library header and sourcing pattern** (`h29-sbx-upgrade.sh` lines 9-11):
```bash
. "$(dirname "$0")/lib.sh"
host_init
. "$(dirname "$0")/lib-sbx.sh"
```
Add `. "$(dirname "$0")/lib-login.sh"` right after `host_init` in H-09 and H-29.

**Plant pattern** (h09 lines 33-38):
```bash
plant_sentinels() {
  printf '%s\n' "$sentinelText" >"$RUN/hosttest/h09-sentinel.txt"
  ...
  mkdir -p "$(dirname "$memorySentinel")"
  printf '%s\n' "$sentinelText" >"$memorySentinel"
```

**Check pattern** (h09 lines 70-78): loop over paths, compare `cat` to text, `add_problem "$file is missing or changed after the rebuild"`.

**What to write:** the helper body in 06-RESEARCH.md section 6 is ready to copy (`plant_login_files STATE_DIR TEXT PREFIX`, `check_login_files STATE_DIR TEXT PREFIX WHEN`, `loginProjectName=-home-sandbox-workspace-hosttest`). Keep it a library: no `set`, no calls at top level, a banner per function (`# name ARGS: what it does`), full names, braces, blank lines around control flow. Host-side `grep -Fq` only; no `stat` (GNU and BSD flags differ).

---

### `tests/host/h09-rebuild-keeps-files-no-volumes.sh` and `tests/host/h29-sbx-upgrade.sh` (edits)

**H-09 call sites:** in `plant_sentinels` after line 38 add `plant_login_files "$RUN/state" "$sentinelText" h09`; in `check_sentinels_survived` after the loop add `check_login_files "$RUN/state" "$sentinelText" h09 "after the rebuild"`. Delete header line 6 (the manual helper pointer). Update the `report_check` pass text (line 145).

**H-29 call sites:** `plant_and_snapshot` (lines 99-106, after the three `printf` lines): `plant_login_files "$sbxDir/state" "$sentinelText" h29`. `check_upgrade` (after the sentinel loop at lines 175-179): `check_login_files "$sbxDir/state" "$sentinelText" h29 "after sbx-upgrade"`. Update the `report_check` pass text (line 248). Note H-29 plants with `mkdir -p "$sbxDir/state/claude"` already (line 100); the helper's own `mkdir -p` covers `projects/`.

H-16 keeps its own session file untouched.

---

### `tests/guard/isolation.sh` (guard rule, transform)

**Analog:** `no_docker_socket_or_privileges` (lines 11-22) for banner and `local` style; `run_rules` list at lines 62-64.

**Rule placement pattern** (lines 60-64):
```bash
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  no_docker_socket_or_privileges \
  host_scripts_keep_sandbox_data || exit 1
```
Add `managed_settings_deny_skill_edits \` to the list. Rule body (verified in research against the real tree and a mutated scratch copy) is in 06-RESEARCH.md section 8.4: loop over the two `Edit(//home/sandbox/workspace/state/claude/...)` entries, `grep -Fq "\"$denyEntry\"" claude/managed-settings.json`, echo with four-space indent, `return "$ok"`.

**Trim of `host_scripts_keep_sandbox_data` (D-13):** delete only the second block, lines 49-54 (the `{ grep -nE ... bin/sbx-rm ... } | report_lines 'bin/sbx-rm:'`). Keep lines 35-47: the `bin/sbx-rm is missing` check, the `otherFileList` loop and `nowhere_matches '\b(rm|rmdir|prune|kill|down)\b|--volumes' $otherFileList || return 1`. After the trim, line 47 must become the last statement, so make it `nowhere_matches ... $otherFileList` without `|| return 1`, or keep `|| return 1` then `return 0`. Update the rule comment (lines 25-30), which currently describes the exact-line pin.

---

### `tests/guard/supply-chain.sh` (guard rule, transform)

**Analog:** `dockerfile_args_have_no_defaults` (lines 114-128), which already reads `$CLAUDE`'s Dockerfile lines (`CLAUDE=claude/Dockerfile`, `BASE=base/Dockerfile` in `tests/guard/lib.sh` lines 16-17).

**Single-check rule style to copy** (`gsd_installs_only_the_official_package`, lines 20-27):
```bash
gsd_installs_only_the_official_package() {
  if ! grep -Fq 'npm install -g "@opengsd/gsd-core@${GSD_CORE_VERSION}"' $CLAUDE; then
    echo "    $CLAUDE does not install \"@opengsd/gsd-core@\${GSD_CORE_VERSION}\""
    return 1
  fi

  return 0
}
```
Add `claude_image_has_one_from_line` (body in 06-RESEARCH.md section 8.4: `grep -c '^FROM'` must be 1 and `grep -Fxq 'FROM ${BASE_IMAGE}'`). Add it to the `run_rules` list (lines 160-169), for example after `dockerfile_args_have_no_defaults`.

**Forced fix in the same commit as deleting `tests/host/manual/`:** line 14 of `no_compromised_gsd_package`, remove the token `tests/host/manual/*.sh` from the file list; otherwise `grep` exits 2 and the rule fails.

---

### `host-test.sh` (runner, request-response)

**Analog:** the file itself. Steps are `run_step NAME FUNCTION` in `main` (lines 204-229); `exit` style comes from the entry block (lines 234-241).

**H-00 preflight:** the research pattern (06-RESEARCH.md 4.2) goes at the top of `main`, before `run_step "context" show_context` (line 205). Because `main` runs on the left of `| tee`, an `exit 1` there ends only that subshell and the exit code is read from `${PIPESTATUS[0]}` (line 241), so the message still reaches `host-test.log`. It must be an early exit, not a `run_step` (a `run_step` records FAIL and continues):
```bash
docker compose version --short </dev/null 2>&1 | grep -Eq '^v?([2-9]|[1-9][0-9])\.' || { echo "Docker Compose v2 or newer is required; install Docker Desktop"; exit 1; }
```
Under the coding rules, write it as a small function `require_compose_v2` with its own banner and call it first in `main`, with `|| exit 1` per the shell rule (a function reports and returns non-zero; the caller exits). Bash 3.2 safe as written.

**Other edits:** line 6 becomes "--keep leaves the test sandbox up to look around after a failure." Line 52 comment becomes `H-01 to H-33`. Line 107 comment, "the guard and the entrypoint self-test". Line 120 loop: `for suite in tests/guard/run-all.sh tests/selftest/entrypoint/run-all.sh; do`.

---

### `tests/host/h28-sbx-add-start-stop.sh` (H-11 timing fold)

**Analog:** `check_stop` (lines 139-163), plus H-11's `date +%s` idiom (research 4.3; H-11's threshold is 10 s because Compose waits 10 s before a kill).

**Existing code to wrap** (lines 139-146):
```bash
check_stop() {
  local sentinelFile

  run_sbx h28-stop sbx-stop hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-stop exited $sbxStatus; log: $RUN/logs/h28-stop.err"
  fi
```
Change to declare `local stopStart stopSeconds`, set `stopStart=$(date +%s)` before the `run_sbx h28-stop` call, `stopSeconds=$(( $(date +%s) - stopStart ))` right after it, and add (after the status check):
```bash
  if [ "$stopSeconds" -ge 10 ]; then
    add_problem "sbx-stop took $stopSeconds s; 10 s or more means the stop fell through to a kill"
  fi
```
The "container kept" and sentinel checks (lines 148-156) already cover what H-11 proved besides timing. Add "sbx-stop returned in under 10 s" to H-28's `report_check` pass text. Remove `h11-stop-is-quick-and-safe.sh` from `chainCheckList`.

---

### `tests/selftest/sbx/lib.sh` (`start_group`)

**Analog:** current `start_group` (lines 16-37). Keep lines 17-25 (`enter_repo_root`, `BIN`, `make_work_folder`, `SBX_CONFIG_DIR` export, `unset SBX_DIR SBX_NAME`). Delete lines 27-36 (the fence and the `PATH=` export), and delete `make_scripted_docker` (lines 58-105) and all `set_standin_*`, `reset_standin_calls`, `run_sbx_scripted`, `run_sbx_in_terminal`, `no_docker_call`, `appears_before` (confirm no caller by grep).

**Replacement (bash 3.2 safe, no arrays, no new syntax):**
```bash
  SBX_CONFIG_DIR=$WORK/cfg
  export SBX_CONFIG_DIR
  unset SBX_DIR SBX_NAME DOCKER_CONTEXT
  DOCKER_HOST=unix:///nonexistent
  export DOCKER_HOST
```
`unset DOCKER_CONTEXT` is required (D-15): the Docker CLI lets it override `DOCKER_HOST`. Rewrite the banner (lines 3, 11-15) to say the group points Docker at a missing socket instead of a stand-in. Also drop the `no_docker_call` line at the end of `add.sh:295`, `entry.sh:140`, `fix-modes.sh:173`, `upgrade.sh:59`, and update group header comments in `start.sh`, `shell.sh`, `list.sh`, `rm.sh`.

---

### `tests/host/run-all.sh` (runner, batch)

**Edits:** lists at lines 21-26 exactly as in 06-RESEARCH.md 4.1 (remove `fatalCheck`, `h02`, `h11`, `h18`, `h21`, `h24`; `remainingList="$noSandboxCheckList $sandboxCheckList $chainCheckList"`). Delete `run_compose_check` (lines 239-248 region, with its banner) and its call in Main. `print_next_block` (lines 143-156): change the banner to "prints the cleanup command", reword line 149 to "Cleanup when you are done:", delete line 155 (`see tests/host/manual/`). Keep `finish` and `fatal`.

## Shared Patterns

### Rule file shape (guard)
**Source:** `tests/guard/supply-chain.sh` lines 156-169 and `tests/guard/isolation.sh` lines 58-64.
**Apply to:** both new guard rules.
```bash
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  rule_one \
  rule_two || exit 1
```
`tests/guard/run-all.sh` runs every `*.sh` in the folder, and `SHELL_FILES` uses globs, so no registration is needed. A failing rule prints four-space-indented lines and returns non-zero. Use `nowhere_matches` and `report_lines` from `tests/guard/lib.sh` where they fit.

### Host check shape
**Source:** `tests/host/h09-rebuild-keeps-files-no-volumes.sh` lines 8-10 and 137-145.
**Apply to:** H-09, H-29, H-28, H-13, H-15, H-16, H-23 edits.
`require_no_arguments "$@" || exit 2`, `require_test_sandbox H-NN || exit 1`, accumulate with `add_problem`, end with `report_check H-NN "<failure text>" "<pass text>"`. Update the pass text whenever a part is trimmed.

### Coding rules for every edited or new shell file
Banner above each function (78 hyphens), braces on every `if`, blank line before and after control flow, full variable names, `xList` suffix for collections, ASCII only, no dash punctuation in comments, no D-xx or phase IDs in committed source. Keep H-nn names (the repo's own test names). After sandbox edits run `git diff --summary` and restore any lost exec bit.

## No Analog Found

None. The one genuinely new behaviour, a fast-failing "Docker at a missing socket" environment, has no earlier analog in the tree (the old fence is the thing being removed), so use the snippet in 06-RESEARCH.md 7.2 and the Docker CLI documentation it cites. The negative control for the two new guard rules (scratch copy with one deny line deleted and a second `FROM` appended, both must FAIL) is described in 06-RESEARCH.md section 8.4 and Validation Architecture.

## Metadata

**Analog search scope:** `tests/host/`, `tests/guard/`, `tests/selftest/sbx/`, `host-test.sh`
**Files read:** h09, h29, h28 (`check_stop`), h16 (session lines), guard `isolation.sh` and `supply-chain.sh`, `start.sh` (rule list), `host-test.sh`, `tests/host/run-all.sh` (three ranges), `tests/selftest/sbx/lib.sh` (lines 1-110)
**Pattern extraction date:** 2026-11-13
