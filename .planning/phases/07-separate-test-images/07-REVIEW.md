---
phase: 07-separate-test-images
reviewed: 2026-11-14T00:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - README.md
  - bin/sbx-lib.sh
  - build.sh
  - clean.sh
  - compose.yml
  - host-test.sh
  - tests/README.md
  - tests/guard/isolation.sh
  - tests/guard/start.sh
  - tests/host-checklist.md
  - tests/host/h01-native-arch.sh
  - tests/host/h03-variable-interpolation.sh
  - tests/host/h12-plain-run-refused-pin-installed.sh
  - tests/host/h17-start-offline-and-failing-hook.sh
  - tests/host/h22-toolchain-in-base.sh
  - tests/host/h25-images-match-versions.sh
  - tests/host/h27-bundle-clone-and-publish.sh
  - tests/host/h29-sbx-upgrade.sh
  - tests/host/h30-version-line.sh
  - tests/host/h33-sbx-rm.sh
  - tests/host/lib-docker.sh
  - tests/host/lib.sh
  - tests/host/run-all.sh
  - tests/selftest/sbx/image-tag.sh
  - tests/selftest/sbx/lib.sh
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: issues_found
---

# Phase 7: Code Review Report

**Reviewed:** 2026-11-14
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

The phase threads `SBX_IMAGE_TAG` (allow-listed to `local` or `test`) through `bin/sbx-lib.sh`, `build.sh`, `compose.yml` and the host tests. I traced every `docker`, `docker compose` and `build.sh` call in `tests/host/` and `host-test.sh` and found no path where a test run builds, runs or inspects a `:local` image: the tag is exported once in `host-test.sh` and again in `host_init`, and `env`, `run_timeout` and `run_sbx` all inherit it. The allow-list is checked in `sbx_init` before any script acts, and `run_compose` hands the checked value (not the raw env) to Compose. The new guard rules and the `image-tag.sh` self-test pass on Linux (19 of 19 guard rules; all 15 new self-test cases). Bash 3.2 and BSD portability is fine: `${var// / or }`, `type -P` and the `local` usage are all bash 3.2 safe, and `host-test.sh` stays POSIX-sh clean.

No blockers. The findings below are one misleading failure message, one operator-safety gap, and some test-coverage and drift weaknesses.

## Warnings

### WR-01: H-25 failure message tells the user to rebuild the wrong images

**File:** `tests/host/h25-images-match-versions.sh:35`
**Issue:** The problem text reads `... differs from versions.env; rebuild with ./build.sh`. The image being checked is now `$CLAUDE_IMAGE` (`sbx-claude:test`). A plain `./build.sh` builds the `:local` images, so a user following the message rebuilds the wrong tag and the next `./host-test.sh` still sees the stale test image (or, since `host-test.sh` rebuilds on every run, the advice is simply irrelevant). The phase changed the image name in this line but left the remedy pointing at the old workflow.
**Fix:**
```bash
add_problem "/etc/sbx/versions.env in $CLAUDE_IMAGE differs from versions.env; rerun ./host-test.sh (it rebuilds the test images): $(first_lines "$diffText")"
```

### WR-02: A leaked `SBX_IMAGE_TAG=test` silently moves a real sandbox onto the test images

**File:** `bin/sbx-lib.sh:62-76` (and `run_compose` at `bin/sbx-lib.sh:232`)
**Issue:** The container name is `sbx-$NAME` regardless of the tag. If `SBX_IMAGE_TAG=test` is exported in the user's shell (an earlier `export` for a manual test, a shell profile, or a copy-pasted command), `sbx-start`, `sbx-shell` and `sbx-upgrade` accept it as valid and recreate the user's real sandbox on `sbx-claude:test`, or `sbx-upgrade` builds and runs the test images. Nothing in the output names the tag; the only protection is a README sentence ("leave it unset in your shell"). The project's core value is that rebuilding reliably delivers the right tools into a sandbox. Only `runs_older_image` happens to notice, and it words the change as an upgrade warning, not as a tag mismatch.
**Fix:** When `imageTag` is not `local`, have `check_image_tag` (or `sbx_init`) print one line to stderr, for example `sbx-start: SBX_IMAGE_TAG=test, using the test images`. Alternatively refuse any tag other than `local` unless the caller is the host test run (for example require a second marker variable that only `host-test.sh` sets).

## Info

### IN-01: The `:local\b` guard blocks testing the default tag on real Compose

**File:** `tests/guard/isolation.sh:76-78`, `tests/host/h03-variable-interpolation.sh:46-52`
**Issue:** `host_tests_never_name_the_local_tag` forbids the text `:local` in `host-test.sh` and `tests/host/*.sh`, even in comments. As a result, no host check can render `compose.yml` with `SBX_IMAGE_TAG` unset and assert the `sbx-claude:local` default, which is the exact fallback that protects real sandboxes. That default is covered only by a `grep -F` on the compose text (`tests/guard/start.sh`). The rule is also narrow: it does not scan `tests/host/support/` or other spellings such as `sbx-base:${tag}` or `:"$x"`, so it catches a typo, not a real regression.
**Fix:** Add a Compose render in H-03 that runs `env -u SBX_IMAGE_TAG docker compose ... config` and compares against `sbx-claude:${defaultTag}`, where the default is built from a variable instead of the literal. Add `tests/host/support/*` to the guard's file list.

### IN-02: H-03 image check is a substring match

**File:** `tests/host/h03-variable-interpolation.sh:49`
**Issue:** `grep -Fq "image: $CLAUDE_IMAGE"` also matches `image: sbx-claude:test2` or `image: sbx-claude:testing`. It passes for a wrong tag that merely starts with `test`.
**Fix:**
```bash
if ! printf '%s\n' "$nameOutput" | grep -Eq "^[[:space:]]*image: $CLAUDE_IMAGE\$"; then
```
(the `.` in an image name is a regex any-char, which is harmless here; use `grep -Fxq` on a trimmed line if you want it exact).

### IN-03: The tag allow-list is written in two places with no drift check

**File:** `build.sh:13-35`, `bin/sbx-lib.sh:10,57-76`
**Issue:** `knownImageTagList` and `check_image_tag` are duplicated; the comment calls `build.sh` a "twin". Nothing in the guard asserts that the two lists, or the two error wordings the self-test greps for, stay equal. Adding a tag in one file fails closed (the other refuses it), so this is not a safety bug, but the failure surfaces late, as a `sbx-upgrade` that builds nothing. `compose.yml` is a third place that spells the default (`:-local`).
**Fix:** Add a guard rule that extracts both `knownImageTagList=` lines and compares them, for example in `tests/guard/start.sh` next to `compose_image_follows_agent_and_tag`.

### IN-04: `run_build_without_docker` depends on build.sh's exact first output and tool set

**File:** `tests/selftest/sbx/image-tag.sh:30-42,113-121`
**Issue:** The PATH holds only `dirname` and `grep`, and the cases compare the whole stdout to one line with `equals`. If `build.sh` later gains another external tool before the first build (for example a `sed` or `tr` in a banner) or prints any line before `build.sh: building ...`, these cases fail with a "command not found" or a diff against the whole file, not a message that points at the cause. The suite also lacks a case for `sbx-cursor` and `sbx-claude` build names (only `sbx-base` is asserted), so the `--build-arg BASE_IMAGE=` pairing is covered only by the grep-count guard rule, not by behavior.
**Fix:** Compare with `has_text` on the first line instead of `equals` on the whole file, and add a stub `docker` that records its arguments to a file in the work folder (no daemon is reached) to assert the three image names and both `BASE_IMAGE` build args. The repo's memory notes that the stand-in `docker` is quasi-deprecated for the `sbx` self-test; a host check is the alternative if that policy applies here.

---

_Reviewed: 2026-11-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
