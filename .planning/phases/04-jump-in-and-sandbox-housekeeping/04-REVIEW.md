---
phase: 04-jump-in-and-sandbox-housekeeping
reviewed: 2026-11-07T00:00:00Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - SANDBOX.md
  - bin/sbx-lib.sh
  - bin/sbx-list
  - bin/sbx-rm
  - bin/sbx-shell
  - bin/sbx-start
  - host-test.sh
  - tests/README.md
  - tests/guard/isolation.sh
  - tests/host-checklist.md
  - tests/host/h31-sbx-shell.sh
  - tests/host/h32-sbx-list.sh
  - tests/host/h33-sbx-rm.sh
  - tests/host/manual/h31-jump-in.sh
  - tests/host/run-all.sh
  - tests/selftest/guard/sandbox-rules.sh
  - tests/selftest/sbx/lib.sh
  - tests/selftest/sbx/list.sh
  - tests/selftest/sbx/rm.sh
  - tests/selftest/sbx/shell.sh
  - tests/selftest/sbx/start.sh
findings:
  critical: 0
  warning: 5
  info: 5
  total: 10
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-11-07
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

The new scripts (`sbx-shell`, `sbx-list`, `sbx-rm`) and the `bring_up_sandbox` refactor are sound on the points that matter for the safety goal. I traced these and found no defect:

- `sbx-rm` runs one scoped `docker compose ... down`, and its only delete is `rm -- "$entryFile"`. The name is validated by `check_name` before `entryFile` is built, so there is no path traversal. A symlinked entry loses only the link.
- No bash 3.2 or BSD traps: no `mapfile`, `declare -A`, `${x,,}`, `sed -i`, `readlink -f` or `grep -P` in the new bin/ or test files. The here-doc `while read` loops, `${!1}` and `local LC_ALL=C` all behave under 3.2.
- The `set -e` interaction in `sbx-list` (final `while read` loops, `status_of` in `$(...)`) cannot produce a spurious non-zero exit.
- `sbx-start` keeps its previous call order inside `bring_up_sandbox`.
- No dashes used as punctuation in the changed prose; the `--` hits are literal code.

No data-loss or security defect was found. The findings below are one test that can fail for a documented-valid Docker wording, a housekeeping gap, two misleading-failure paths, and weak or vacuous test and guard assertions.

## Warnings

### WR-01: H-31 greps for "TTY" but SANDBOX.md says newer Docker prints a different message

**File:** `tests/host/h31-sbx-shell.sh:75`
**Issue:** `check_start_without_terminal` requires `grep -qi 'TTY'` in the error log. `SANDBOX.md` (Troubleshooting table and the `sbx-shell` bullets) states that newer Docker prints `stdin is not a terminal` instead of `the input device is not a TTY`. On such a Docker the check fails with "printed no TTY refusal" although `sbx-shell` behaves correctly. A false FAIL in the unattended run blocks the whole chain (H-32, H-33, H-20, H-10 become NOT RUN). The check passes today only because the Mac's Docker uses the old wording.
**Fix:**
```bash
if ! grep -qiE 'TTY|not a terminal' "$RUN/logs/h31-noterm.err"; then
```
The fix also gives the check a second signal: `sbxStatus` non-zero and the sandbox running afterwards are already asserted, so the message match could be dropped to an advisory.

### WR-02: `sbx-rm` cannot clean up the entries `sbx-list` reports as broken

**File:** `bin/sbx-rm:82`
**Issue:** `read_registry_entry` is called unconditionally and returns 1 for a missing or relative `SBX_DIR` or an agent other than `claude`. `sbx-list` shows exactly those entries as `broken entry`, and the SANDBOX.md troubleshooting row tells the user to "delete it and run sbx-add again", but `sbx-rm NAME --unregister` refuses them, and so cannot remove the container that belongs to a broken entry either. The housekeeping command fails on the cases that need housekeeping, and the user falls back to a hand `rm` in `~/.config/sbx/sandboxes/`, the one delete the guard is designed to keep inside a single reviewed line.
**Fix:** For `sbx-rm` only, tolerate a bad `SBX_DIR` and agent. `down` does not read the folder, but `compose.yml` requires `SBX_DIR` to interpolate, so pass a placeholder when the entry gives none:
```bash
read_registry_entry "$sandboxName" || [ -f "$registryDir/$sandboxName" ] || exit 1
entryDir=${entryDir:-/}   # interpolation only; down never touches it
```
Keep the "nothing in $entryDir was changed" lines honest by printing the real value only when it is absolute. If the placeholder route is rejected, document in the SANDBOX.md `sbx-rm` section that a broken entry is deleted by hand.

### WR-03: `sbx-shell` and `sbx-start` blame a missing image when Docker is simply not running

**File:** `bin/sbx-lib.sh:194-201` (reached from `bin/sbx-shell:32-34`)
**Issue:** `sandbox_is_running` swallows every docker error, so with Docker Desktop stopped `sbx-shell` goes to `bring_up_sandbox`. `require_images` then reports "sbx-claude:local is not built; run: sbx-upgrade NAME (it builds the images and starts the sandbox)". The advice starts a full image rebuild, which fails or wastes minutes, when the fix is to start Docker. `sbx-shell` is now the daily entry point, so this is the most likely failure a user sees. `sbx-list` already distinguishes the case ("is Docker running?"), so the scripts disagree.
**Fix:** Tell the two apart in `require_images`:
```bash
if ! docker info >/dev/null 2>&1 </dev/null; then
  sbx_error "cannot reach Docker; is Docker Desktop running?"
  return 1
fi
```
before the `docker image inspect`, and keep the "not built" message for the case where the daemon answers.

### WR-04: `sbx-rm` takes down a running sandbox with no confirmation and the default 10 s stop timeout

**File:** `bin/sbx-rm:48-62`, `SANDBOX.md` ("Remove a sandbox")
**Issue:** The script prints one warning line and proceeds. `compose down` sends SIGTERM and SIGKILLs after 10 s. A Claude session or `git` operation writing under `state/claude`, `state/shell` or the project folder at that moment can be cut mid-write, which is the login/history/workspace damage the safety goal names. "Nothing on disk is lost" in the docs is not guaranteed for in-flight writes. `--unregister` makes the loss of the way back to the container also one keystroke away. The same warning-only pattern is accepted for `sbx-start`'s recreate, but removal is the more destructive command.
**Fix:** When the sandbox is running, require either a terminal answer or an explicit flag, for example:
```bash
if sandbox_is_running "$1" && [ "$forceRemove" != yes ]; then
  sbx_error "sbx-$1 is running; stop it with sbx-stop $1 first, or add --force"
  return 1
fi
```
At minimum, stop the sandbox with `compose stop` (or pass a longer `down --timeout`) and say so in the warning.

### WR-05: H-33 volume and container snapshots can pass vacuously when Docker errors

**File:** `tests/host/h33-sbx-rm.sh:27` and `tests/host/h33-sbx-rm.sh:34`
**Issue:** `list_project_volumes` and `list_other_containers` use `2>&1`, so a docker failure puts its error text into the "list". The before and after snapshots are then the same error text and the comparisons `volumesBefore != volumesAfter` and `othersBefore != ...` succeed. The "no volume or other sandbox was touched" claims in the PASS line would hold without ever having been checked. In `list_other_containers`, `|| true` also hides the pipeline status.
**Fix:** Drop `2>&1` and fail the check when the command itself fails:
```bash
list_project_volumes() {
  docker volume ls -q --filter label=com.docker.compose.project=sbx-hosttest </dev/null
}
...
volumesBefore=$(list_project_volumes) || add_problem "docker volume ls failed before sbx-rm"
```
Do the same for the `docker ps` call, filtering with `grep -v ... || true` only after capturing docker's own status.

## Info

### IN-01: Guard for `sbx-rm` is a pattern list with holes

**File:** `tests/guard/isolation.sh:57-59`
**Issue:** The `sbx-rm` rule blocks listed words and options, but not other ways to drop data: `find ... -delete`, `unlink`, `mv`, `shred`, a redirect that truncates `"$entryFile"`, or options reaching `down` through a variable or `"$@"` (`down $opts`). The allow-list for `rm` is the exact source line `  if ! rm -- "$entryFile"; then`, so a second identical line elsewhere in the file (for example in a loop over entries) would pass, and any reformat of that line fails closed. The planted-failure cases in `sandbox-rules.sh` cover only the patterns already listed.
**Fix:** Add `unlink|-delete|shred|truncate` to the word list, add `down[[:space:]]+[^[:space:]]` to flag anything after `down` but a line end, and count occurrences: the file must contain exactly one `rm -- "$entryFile"` line.

### IN-02: `sbx-list` finds containers by label but `sandbox_is_running` and `runs_older_image` find them by name

**File:** `bin/sbx-list:28`, `bin/sbx-lib.sh:211`
**Issue:** A container named `sbx-demo` that lacks the `sbx.name` label (for example made with a raw `docker run --name sbx-demo`) reads `no container` in `sbx-list` while `sbx-shell` and `sbx-rm` treat it as running. The SANDBOX.md claim that the list "matches docker ps -a" holds only for labelled containers.
**Fix:** Say so in the `sbx-list` section ("only containers with the `sbx.name` label"), or look the registered names up by name with `docker ps -a --filter name=^sbx-NAME$`.

### IN-03: H-33 moves the test sandbox folder with no cleanup path

**File:** `tests/host/h33-sbx-rm.sh:222-244`
**Issue:** `mv "$sbxDir" "$sbxDir moved"` is undone by a second `mv`, with no `trap`. An interrupt between them, or a failed second `mv`, leaves the run folder's sandbox displaced under a different name, and the later checks in the chain then run against a folder that is not there. Only scratch data is at risk, since the folder lives under the run folder.
**Fix:** Register a `trap 'if [ -d "$sbxDir moved" ] && [ ! -e "$sbxDir" ]; then mv "$sbxDir moved" "$sbxDir"; fi' EXIT INT TERM` before the first `mv` and clear it after the second.

### IN-04: The failed-entry-delete branch of `sbx-rm` has no test

**File:** `bin/sbx-rm:68-71`, `tests/selftest/sbx/rm.sh`
**Issue:** The "could not delete $entryFile; the container is gone" path is never exercised; `case_rm_down_fails` covers only a failed `down`. A regression that swallowed the `rm` failure, or printed the success line after it, would pass every test.
**Fix:** Add a case that makes the registry directory read-only (`chmod a-w "$SBX_CONFIG_DIR/sandboxes"`, skipped when running as root) and expects exit 1, the error text, and no "deleted the registry entry" line.

### IN-05: `warn_sessions_close` writes a warning to stdout

**File:** `bin/sbx-lib.sh:242-244`
**Issue:** The sessions warning goes to stdout, unlike every other diagnostic (`sbx_error` uses stderr). A caller that pipes or captures the output of `sbx-rm` or `sbx-start` gets the warning mixed into the result, and a `2>/dev/null` hides nothing. The self-tests assert the stdout placement, so it is a convention choice made on purpose.
**Fix:** Either send it to stderr (`>&2`) and update the `.out` assertions in `rm.sh` and `start.sh` to `.err`, or document in the library header that warnings are stdout by design.

---

_Reviewed: 2026-11-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
