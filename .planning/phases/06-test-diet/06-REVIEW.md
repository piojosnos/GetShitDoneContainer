---
phase: 06-test-diet
reviewed: 2026-11-13T00:00:00Z
depth: standard
files_reviewed: 28
files_reviewed_list:
  - README.md
  - clean.sh
  - host-test.sh
  - tests/README.md
  - tests/guard/isolation.sh
  - tests/guard/lib.sh
  - tests/guard/start.sh
  - tests/guard/supply-chain.sh
  - tests/host-checklist.md
  - tests/host/h09-rebuild-keeps-files-no-volumes.sh
  - tests/host/h13-env-and-no-self-update.sh
  - tests/host/h15-bundle-linked-and-visible.sh
  - tests/host/h16-live-clone-and-restart.sh
  - tests/host/h23-caches-survive-recreate.sh
  - tests/host/h28-sbx-add-start-stop.sh
  - tests/host/h29-sbx-upgrade.sh
  - tests/host/h31-sbx-shell.sh
  - tests/host/lib-login.sh
  - tests/host/run-all.sh
  - tests/selftest/entrypoint/start-folders.sh
  - tests/selftest/sbx/add.sh
  - tests/selftest/sbx/entry.sh
  - tests/selftest/sbx/fix-modes.sh
  - tests/selftest/sbx/lib.sh
  - tests/selftest/sbx/list.sh
  - tests/selftest/sbx/rm.sh
  - tests/selftest/sbx/shell.sh
  - tests/selftest/sbx/start.sh
  - tests/selftest/sbx/upgrade.sh
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-11-13
**Depth:** standard
**Files Reviewed:** 28
**Status:** issues_found

## Summary

The diet is mostly clean: no dead helpers, no non-ASCII, no planning IDs, no dash punctuation, and no kept file references a deleted script, group or fake docker. The guard, the sbx self-test and the entrypoint self-test pass, and `bash -n` is clean on every kept script.

The weaknesses are checks that pass vacuously or were dropped:

- **Guard rules:** both rules added in this phase can be bypassed.
- **H-13:** it now checks only that a variable name exists.
- **Entrypoint name rule:** it has no automated coverage left.
- **README:** one troubleshooting row points at a check that no longer does what the row says.

## Warnings

### WR-01: README tells the reader to rely on H-23 for Maven, but H-23 no longer runs Maven

**File:** `README.md:433`
**Issue:** The row says "Keep `MAVEN_VERSION` at 3.9.11 until a newer release passes host check H-23". H-23 now only touches marker files in the cache folders, so a Maven bump passes H-23 whether or not Maven can use its local repository on the Docker Desktop mount.
**Fix:** Reword the row so it no longer cites H-23. For example, say to try a newer release by hand (`mvn -q dependency:get` in a sandbox). Or keep a one-line Maven write test in H-23.

### WR-02: The entrypoint's sandbox-name check has no automated test left

**File:** `tests/selftest/entrypoint/start-folders.sh`; the code under test is `base/sbx-start-lib.sh:50-67` (`check_sandbox_name`)
**Issue:** H-21 and the entrypoint name-rule cases are deleted. H-03 and H-20 cover other refusals. Nothing fails if `check_sandbox_name` is removed or loosened to accept `../x` or `best-practices`, and `SBX_NAME` becomes a path (`sbx-start-lib.sh:143`).
**Fix:** Keep one cheap case in `start-folders.sh`. It runs `SBX_NAME=../x` and `SBX_NAME=best-practices` through `make_entry_copy` and asserts:
- exit 1;
- `[sbx] ERROR: SBX_NAME` is printed;
- the command never runs.

### WR-03: The new deny-entry guard rule passes when the entry sits in the wrong JSON array

**File:** `tests/guard/isolation.sh:58-66` (`managed_settings_deny_skill_edits`)
**Issue:** `grep -Fq` matches the quoted entry anywhere in the file, so moving it from `deny` to an `allow` list still passes.
**Fix:** Restrict the search to the deny block, for example with `sed -n '/"deny"/,/\]/p'`. Also fail when that block is empty.

### WR-04: `claude_image_has_one_from_line` is bypassed by a lowercase or indented `from`, and by `COPY --from=`

**File:** `tests/guard/supply-chain.sh:137-146`
**Issue:** `grep -c '^FROM'` misses `from x` and `  FROM x`, because Dockerfile instructions are case-insensitive. `COPY --from=<image>` and `RUN --mount=...,from=<image>` pull an image without any `FROM`.
**Fix:** Count with `grep -ciE '^[[:space:]]*FROM[[:space:]]'`. Also refuse `--from=` and `from=` mounts, with a short comment explaining why.

### WR-05: H-13 checks only that `DISABLE_UPDATES` is named, not that it is on

**File:** `tests/host/h13-env-and-no-self-update.sh:28`
**Issue:** `grep -q "^$envName="` accepts `DISABLE_UPDATES=0` or an empty value. Since the `claude update` reply check was removed, this check is the only proof that updates are disabled.
**Fix:** Check `DISABLE_UPDATES=1` exactly (`grep -qx`), and keep the name-only loop for the other variables. Update the H-13 row in `tests/host-checklist.md` to match.

## Info

### IN-01: `plant_login_files` ignores its own failures

**File:** `tests/host/lib-login.sh:26-34`
**Issue:** If the plant itself fails, the error later reads "missing or changed after the rebuild", which blames the rebuild.
**Fix:** Check `mkdir -p` and each `printf`, and call `add_problem` naming the plant step if one fails.

### IN-02: The path-scoped fixture rule is unused and its text is stale

**File:** `tests/host/support/bundle/rules/sbx-fixture-shell.md:8`
**Issue:** Only the deleted H-15 `/context` check used it. Its body still says the host checks expect it to load only for shell files.
**Fix:** Delete it, or change the body to something true.

### IN-03: Literals duplicated across files will drift

**Files:**
- `tests/host/lib-login.sh:11`
- `tests/host/h09-rebuild-keeps-files-no-volumes.sh:12`
- `tests/host/h16-live-clone-and-restart.sh:14,16`
- `tests/guard/isolation.sh:62`
- `tests/host/h14-wrappers-and-settings-in-image.sh:121`

**Issue:** The project folder name and the two deny entries are copied across checks.
**Fix:** Optional. Use `$loginProjectName` in h09. Add a comment in each deny-entry copy naming the other copies.

### IN-04: Comments describe the removed implementation

**Files:** `tests/selftest/sbx/lib.sh:3`, `tests/README.md:41`
**Issue:** "Docker at nothing" is unclear. "(no stand-in docker)" describes something that no longer exists.
**Fix:** Say "Docker pointed at a missing socket", and drop the parenthesis.

---

_Reviewed: 2026-11-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
