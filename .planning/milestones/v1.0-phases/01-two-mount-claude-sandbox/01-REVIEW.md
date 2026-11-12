---
phase: 01-two-mount-claude-sandbox
reviewed: 2026-10-04T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - base/Dockerfile
  - base/sbx-entrypoint
  - claude/Dockerfile
  - compose.yml
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-10-04
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Re-review of the single-mount layout: base image, Claude image, the entrypoint mount guard and `compose.yml`. Docker is not available here, so nothing was built or run; findings come from reading the files and from Docker/Compose behaviour as documented.

Carried over from the previous review and still open: the Claude Code install integrity gap (WR-03), the "bind mount" wording in the entrypoint (IN-01) and the missing absolute-path check on `SBX_DIR` (IN-02). Fixed since the previous review: the history "shared between shells" claim is gone from `base/Dockerfile`, and the orphaned mkdir banner now sits above the `RUN mkdir`. The previous WR-02 and IN-04 live in SANDBOX.md and tests/static-check.sh, which are out of scope for this pass.

New this round: the project-folder guard in the entrypoint can never fire because of `working_dir`, and a comment in `base/Dockerfile` states the opposite of what Compose is known to do. No data-loss or isolation-breaking defects were found.

## Warnings

### WR-01: The entrypoint's "project folder is missing" check is defeated by `working_dir`

**File:** `compose.yml:22`, `base/sbx-entrypoint:32`
**Issue:** `working_dir: /home/sandbox/workspace/${SBX_NAME}` points inside the bind mount. When the container is created, the Docker daemon creates a missing working directory (and chowns it to the container user) before the entrypoint runs. A mistyped `SBX_NAME` against a valid `SBX_DIR` therefore gets an empty `$SBX_DIR/<typo>/` created on the Mac, and `[ -d "$ws/$SBX_NAME" ]` always passes. The check is dead code for the one case it was written for. SANDBOX.md (line 116 and the troubleshooting row at line 155) and the comment at `compose.yml:21` ("The entrypoint needs SBX_NAME to check it exists") promise an error that cannot happen. Check H-10 only exercises a missing `SBX_DIR`, so it does not catch this.
**Fix:** Do not let Docker create the directory. Either start in a folder that always exists and `cd` after the check:
```yaml
working_dir: /home/sandbox/workspace
```
```bash
# end of base/sbx-entrypoint, before exec
cd "$ws/$SBX_NAME"
exec "$@"
```
(docker exec shells would then start at `workspace/`; give them the project folder with a `bash` wrapper or `-w`.) Or keep `working_dir` and drop the check and its documentation, accepting that a typo creates an empty folder. Add a host test for "valid SBX_DIR, mistyped SBX_NAME".

### WR-02: `create_host_path: false` is known to be ignored, and `base/Dockerfile` says the opposite

**File:** `base/Dockerfile:79-80`, `compose.yml:35-45`
**Issue:** `base/Dockerfile` says compose "never creates anything on the Mac". SANDBOX.md (lines 128-129 and 158) records that some Compose versions ignore `create_host_path: false`, and the H-10 self-test treats a Docker-created folder as an expected failure mode. The `compose.yml` comment ("asks Compose to refuse") is hedged, but the Dockerfile comment is flatly wrong, and the compose setting offers no real protection on the affected versions. The entrypoint then refuses to start, but the stray folder stays behind.
**Fix:** Correct the Dockerfile comment to "Compose is asked not to create it, but may ignore that; the entrypoint refuses an empty folder". For an actual guard, use the sentinel approach already noted in SANDBOX.md: an `env_file` at the root of `SBX_DIR`, which makes Compose itself fail before any container exists.

### WR-03: Claude Code install has no integrity verification; Node and gh checksums share an origin with the artifacts

**File:** `claude/Dockerfile:17`, `base/Dockerfile:23-41`
**Issue:** Unchanged from the previous review. Node's `SHASUMS256.txt` and gh's checksums file are fetched over HTTPS from the same host as the tarballs, with no signature check (nodejs.org publishes `SHASUMS256.txt.asc`). That detects corruption, not a compromised origin. Claude Code, which holds the login token, is installed by version pin only, with no comparison of the npm integrity hash. This project exists partly because a package was compromised once.
**Fix:** Pin expected hashes as ARGs and compare at build time:
```dockerfile
ARG CLAUDE_CODE_INTEGRITY=sha512-...
RUN test "$(npm view "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" dist.integrity)" = "${CLAUDE_CODE_INTEGRITY}" \
    && npm install -g ...
```
Consider hardcoded per-arch SHA-256 values for Node and gh, or GPG verification of Node's SHASUMS. Otherwise state in the comments that these are corruption checks and record the accepted risk.

## Info

### IN-01: Entrypoint message says "bind mount" but only checks for a mount point

**File:** `base/sbx-entrypoint:28`
**Issue:** `is_mount` accepts any mount at the path, including `tmpfs` (data lost on stop) and a named volume (contradicts the "no volumes" rule in `compose.yml:10`). The error text "is not a bind mount" and the header comment "a real, writable mount" overstate the guard.
**Fix:** Say "is not a mount point", or also read the filesystem type from `mountinfo` (fields after the `-` separator) and reject `tmpfs`.

### IN-02: `compose.yml` does not enforce an absolute `SBX_DIR`

**File:** `compose.yml:42`
**Issue:** The error text asks for an "absolute host path", but only emptiness is checked. A relative value is resolved against the compose file's directory, which can mount a folder inside the repo. A `~/` path is not expanded by Compose and fails confusingly.
**Fix:** Cheapest option is a shell preflight (`case "$SBX_DIR" in /*) ;; *) echo "SBX_DIR must be absolute" >&2 ;; esac`) in the documented start steps; Compose cannot validate the shape itself.

### IN-03: Base image and apt packages are not pinned by digest

**File:** `base/Dockerfile:4`, `base/Dockerfile:16`
**Issue:** `ubuntu:24.04` is a moving tag and the apt packages are unpinned, while Node, gh and Claude Code are pinned exactly. Rebuilds can differ without any version bump.
**Fix:** Pin `FROM ubuntu:24.04@sha256:<digest>` and bump it deliberately, or note in the header comment that the OS layer is intentionally rolling.

### IN-04: Entrypoint reports a raw `mkdir` error when `state/` is not writable

**File:** `base/sbx-entrypoint:33-38`
**Issue:** Only `$ws` writability is checked with a friendly message. If `$state` exists but is not writable (for example created by a different user), `mkdir -p` fails under `set -eu` with a bare "Permission denied" and no `[sbx]` hint. The unquoted `${SBX_STATE_DIRS:-}` is also subject to globbing, so a name containing `*` would expand.
**Fix:**
```bash
[ -w "$state" ] || die "$state is not writable by $(id -un)."
```
and add `set -f` before the loop (or after it, `set +f`) if glob-safety is wanted.

---

_Reviewed: 2026-10-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
