---
phase: 01-two-mount-claude-sandbox
reviewed: 2026-10-01T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - SANDBOX.md
  - base/Dockerfile
  - base/sbx-entrypoint
  - claude/Dockerfile
  - compose.yml
  - tests/static-check.sh
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-10-01
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the two-mount sandbox layout: base and Claude images, the mount-check entrypoint, compose.yml, the host checklist in SANDBOX.md and the static checker. `tests/static-check.sh` runs clean here (all PASS; shellcheck and hadolint not installed). The entrypoint is executable in git (mode 100755). The `--allow-scripts` npm flag is documented as observed in the phase research, so it is not flagged.

No data-loss or isolation-breaking defects were found in the static artifacts. Three warnings need attention. One is a documented behaviour the code does not deliver. One is a host checklist step that overwrites the user's real git identity. One is a supply-chain integrity gap in a project whose stated concern is supply-chain safety. Docker was not available, so none of the runtime behaviour was exercised.

## Warnings

### WR-01: "History is shared between all open shells" is not delivered by `history -a` alone

**File:** `base/Dockerfile:68-79` (also `SANDBOX.md:48`)
**Issue:** The Dockerfile comment says "concurrent shells see each other's history", and SANDBOX.md says history is "shared between all open shells". `PROMPT_COMMAND="history -a"` only appends this shell's new commands to the file. It never reads other shells' commands into the running shell (that needs `history -n` or `history -r`). A shell already open will not see commands typed in another shell until a new shell starts. Persistence works. The sharing claim does not. H-08 does not catch this, because it opens a fresh shell after the recreate.
**Fix:** Either make the behaviour match the claim:
```dockerfile
PROMPT_COMMAND="history -a; history -n"
```
or drop the "shared between all open shells" and "concurrent shells see each other's history" wording from both files, and say new shells see everything written so far.

### WR-02: H-06 overwrites the user's persistent git identity with "T"

**File:** `SANDBOX.md:218`
**Issue:** `git config --global user.name T` writes to `$GIT_CONFIG_GLOBAL`, which is `state/git/config` on the Mac. That file is the persistent identity this layout exists to keep. A user who already set a real name, or who re-runs the checklist on a live sandbox, has `user.name` silently replaced with `T`. Later commits are then authored as "T". The checklist never restores it.
**Fix:** Use a throwaway config for the persistence probe, or set a probe key and unset it:
```bash
docker exec sbx-demo sh -c 'git config --global sbx.probe 1 && cat $GIT_CONFIG_GLOBAL && git config --global --unset sbx.probe'
```
Alternatively, say explicitly that the step sets the real identity and tell the user to substitute their own name and email.

### WR-03: Claude Code install has no integrity verification, and the Node and gh checksums come from the same origin as the artifacts

**File:** `claude/Dockerfile:19`, `base/Dockerfile:28-50`
**Issue:** The comments present Node and gh as "checksum-verified". The SHASUMS256.txt and checksums.txt files are fetched over HTTPS from the same host as the tarballs, with no signature check (nodejs.org publishes SHASUMS256.txt.asc). That detects corruption but not a compromised origin. Claude Code, which holds the login token and runs with network access, is installed by version pin only. The npm integrity hash is not compared to a known value. The project's constraints exist because a package was already compromised once, and an unverified npm install is the weakest link in the image.
**Fix:** At minimum, pin the expected integrity and compare it at build time:
```dockerfile
ARG CLAUDE_CODE_INTEGRITY=sha512-...
RUN test "$(npm view "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" dist.integrity)" = "${CLAUDE_CODE_INTEGRITY}" && npm install -g ...
```
Also consider hardcoding the Node and gh SHA-256 values per architecture as ARGs, or verifying the Node GPG signature. Otherwise, reword the comments to say "corruption check" and record the accepted risk.

## Info

### IN-01: Entrypoint cannot tell a bind mount from tmpfs or a named volume, but its message and the docs claim it can

**File:** `base/sbx-entrypoint:17-27`, `SANDBOX.md:103`
**Issue:** `is_mount` only checks that the path is a mount point. A `--tmpfs` mount passes and loses data on stop. A named volume also passes, which contradicts the "no volumes" rule. The error text says "is not a bind mount" and the docs say "a real bind mount to a folder on the Mac". The guard covers the actual accident (no mounts at all) but overstates its strength.
**Fix:** Soften the wording to "is not a mount point". Optionally also compare the filesystem type in field 9 onward of `mountinfo`, and reject `tmpfs`.

### IN-02: Orphaned section comment in base/Dockerfile

**File:** `base/Dockerfile:81-87`
**Issue:** The "Home directories and mount targets ... Created AFTER switching to sandbox" banner sits before the entrypoint block and the `USER sandbox` line. The `mkdir` it describes is at line 101, after the entrypoint section, so the comment describes code that is not beneath it.
**Fix:** Move the banner down to sit directly above `RUN mkdir -p ...`.

### IN-03: SANDBOX.md misdescribes the SBX_NAME rule

**File:** `SANDBOX.md:11`
**Issue:** It says the name "must start with a letter or digit". The project name is `sbx-${SBX_NAME}`, so the leading character is always `s`, and `-foo` or `_foo` would be accepted. The real constraint is lowercase letters, digits, `-` and `_`. Separately, `compose.yml` does not enforce an absolute `SBX_DIR`, even though the doc says to use one. A relative value is resolved by Compose against the compose file's directory, which could mount a folder inside the repo.
**Fix:** Drop the "must start with" clause. Optionally state that `SBX_DIR` must be absolute, and add it to the preflight loop.

### IN-04: Hardcoded base commit in the static checker will fail on any later legitimate edit

**File:** `tests/static-check.sh:213-219`
**Issue:** `BASE_COMMIT=934e2c5...` is compared against the working tree for `ClaudeCode`, `OpenCode` and `README.md`. Any intended later change, such as a README update for the new layout, makes the check fail permanently. The Constraints section says the old layout stays untouched only until Phase 5.
**Fix:** Retire the check or change its scope when the old layout is removed in Phase 5. Alternatively, drop `README.md` from the pathspec and note the Phase 5 expiry in a comment.

---

_Reviewed: 2026-10-01_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
