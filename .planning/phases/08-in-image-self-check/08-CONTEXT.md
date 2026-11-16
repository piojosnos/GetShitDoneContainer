# Phase 8: In-image self-check - Context

**Gathered:** 2026-11-14
**Status:** Ready for planning

<domain>
## Phase Boundary

`sbx-selfcheck`, a Python command in the image, tells whether a sandbox is set up right: one PASS or FAIL line per named check, with a fix hint under each FAIL. `./host-test.sh` runs it in a Claude and a Cursor test sandbox instead of probing each piece from the Mac. The test base image carries a throwaway root certificate, so the extra certificate path is checked on every run.

The self-check always runs inside a sandbox started by `sbx-start`: the user's own sandbox (as the doctor) or a test sandbox. It is not a tool for a plain `docker run`.

</domain>

<decisions>
## Implementation Decisions

### Where the checks live
- **D-01:** The base image ships the runner (`sbx-selfcheck`) and the shared checks only (toolchain, user, git, env and so on). It knows nothing about Claude or Cursor.
- **D-02:** Each agent image adds its own checks file to a fixed folder (for example `/etc/sbx/selfcheck.d/claude.py` and `cursor.py`). The runner runs its shared checks plus every file in that folder. Nothing records which agent an image is for.

### Output
- **D-03:** One line per check, PASS or FAIL, easy to grep. There is no SKIP: outside a sandbox the checks that need the mounts simply FAIL, with a hint to run the command in a sandbox started with `sbx-start`. No code path exists that only a plain container would exercise.
- **D-04:** Each FAIL line has an indented `fix:` line under it. When the fix is on the Mac, the hint says so and gives the Mac command.
- **D-05:** No skill wraps the self-check; the fix hints carry the explanation. CHECK-04 and success criterion 4 were amended to say so.

### The host check
- **D-06:** One new host check runs `sbx-selfcheck` with `docker exec` in a Claude test sandbox and in a Cursor test sandbox. It fails on any FAIL line or when the number of checks differs from that agent's expected count. The two expected counts are constants in the host check, so a check that silently disappears fails the run.
- **D-07:** The run starts a Cursor test sandbox, which no host check does today. The user accepts the extra minute or so; revisit if the run gets long.

### What moves and what stays on the Mac
- **D-08:** Everything the old probes check from inside the container moves into the self-check: architecture, user and home owners, git and identity, pinned versions, env variables, wrappers and managed settings, bundle links, the toolchain, the versions record and the interactive-shell versions line.
- **D-09:** The toolchain check confirms each tool resolves to a path in the image, not under `/home`. This keeps H-22's point (the tools come from the image, not the mount) without a throwaway container.
- **D-10:** Probe files after this phase:

  | Probe | Result |
  |---|---|
  | H-01, H-04, H-05, H-13, H-14, H-15, H-22, H-30 | deleted: everything moves inside |
  | H-06 | slimmed: keeps "git works on a repo made on the Mac" |
  | H-12 | slimmed: keeps "a plain `docker run` is refused" |
  | H-25 | slimmed: keeps "the image's `versions.env` equals the repo's" and "a bare build is refused" |

- **D-11:** H-05's "a file made in the container shows up in the Mac folder" is dropped, not kept: H-06 (git on a Mac-made repo) and H-08/H-09 (files survive a recreate) already prove the mount.

### Extra checks
- **D-12:** Add every check that needs no login and no interaction and can be seen from inside: credentials file present (the planted fake passes it), git identity set, `state/` writable, no root-owned files except the known GSD sync leftovers (Phase 9 fixes those). "gh logged in" is out, because it needs a real token.

### Root certificate
- **D-13:** `./host-test.sh` makes a throwaway root certificate with `openssl`, builds it into the test base image through `SBX_CA_CERT`, and deletes the private key at once. Nothing is committed. No HTTPS server, no per-tool checks.
- **D-14:** The self-check confirms every extra certificate the build installed is in the system bundle and in Java `cacerts`. With no extra certificate there is nothing to confirm and the check passes.

### Decided after research
- **D-15:** `./host-test.sh` reuses one throwaway root certificate across runs (kept under `${TMPDIR:-/tmp}/sbx-hosttest-root-ca/`, made when missing, private key deleted at once, never committed), so the test base image keeps its layer cache.
- **D-16:** The runner's Python is unit tested with pytest pinned to exactly 9.2.0, through a minimal root `pyproject.toml`, `.python-version` (3.12) and `uv.lock`. Phase 10 extends the same file.
- **D-17:** H-01 is deleted whole, with nothing kept on the Mac (no architecture comparison with `docker info`, no platform-warning grep). Builds run natively on the Mac; the small emulation risk is accepted.
- **D-18:** pytest runs in the dev sandbox only. `./host-test.sh` does not run it.
- **D-19:** One self-check line per tool; tool checks are not merged into groups.

### Claude's Discretion
- The exact name of the agent checks folder and how a checks file declares its checks.
- How each check is expressed in Python (small functions returning a result with a name and a hint).
- How the self-check knows which extra certificates the build installed (for example the `sbx-extra-ca-*.crt` files `build.sh` produces).
- How the interactive-shell versions line is checked from inside.
- Updating `tests/README.md`, `tests/host-checklist.md` and `README.md` for the new command and the removed probes.

### Folded Todos
- **Two wording nits from the phase 5 review** (`.planning/todos/pending/2026-11-08-retirement-review-nits.md`): the comment at `tests/guard/isolation.sh:28` and the guard row at `tests/README.md:25`. They were meant for the old sandbox doctor phase, which this phase replaces.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and requirements
- `.planning/ROADMAP.md` (Phase 8 section): goal and the four success criteria, amended in this discussion
- `.planning/REQUIREMENTS.md`: CHECK-01 to CHECK-04, amended in this discussion
- `.planning/research/v2-simple-tooling-decisions.md`: item 3, and the appendix text of the old Phases 05.1 (sandbox doctor) and 05.4 (root certificate test)

### Prior decisions that constrain this phase
- `.planning/phases/07-separate-test-images/07-CONTEXT.md`: `SBX_IMAGE_TAG=test` for the whole host run; only `local` and `test` exist
- `.planning/phases/06.1-cursor-agent-image/06.1-CONTEXT.md`: both agent images are always built
- `tests/README.md`: the fake docker in `tests/selftest/sbx/` is quasi deprecated and must not be extended

### Pending todos touched
- `.planning/todos/pending/2026-11-08-retirement-review-nits.md`: folded in
- `.planning/todos/pending/2026-11-08-gsd-sync-leaves-root-owned-files.md`: the self-check tolerates those files; Phase 9 fixes them

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/host/support/toolchain-probe.sh`: what H-22 checks today; the source for the shared toolchain checks
- `tests/host/h14-wrappers-and-settings-in-image.sh`: the owner, mode, writable and mount probe for wrappers, hooks and managed settings
- `tests/host/lib-bundle.sh` `check_bundle_links`: the bundle link expectations
- `build.sh` `prepare_extra_cert`: splits `SBX_CA_CERT` into `sbx-extra-ca-N.crt` files for the base image
- `/etc/sbx/versions.env` and `/etc/sbx/tool-versions`: build-time records already in the image

### Established Patterns
- Image tools live in `base/bin`, `claude/bin`, `cursor/bin` and are copied to `/usr/local/bin` with mode 755.
- The base `Dockerfile` already installs `python3`; `uv` is in the image too.
- Host checks use `in_container` and `report_check` from `tests/host/lib.sh`.

### Integration Points
- `base/Dockerfile`: copies the runner and the shared checks
- `claude/Dockerfile`, `cursor/Dockerfile`: copy each agent's checks file into the fixed folder
- `host-test.sh` and `tests/host/lib-docker.sh`: make the throwaway certificate and pass it to the test base build
- `tests/host/run-all.sh`: the new host check, a Cursor test sandbox, and the removed probes

</code_context>

<specifics>
## Specific Ideas

- The user wants no dead code: a branch that no run ever exercises (like SKIP) is not written.
- Base must not know about the agents; agent images compose their own checks in.
- Do not test plain Docker or Compose behaviour; test only our own setup.

</specifics>

<deferred>
## Deferred Ideas

- If the Cursor test sandbox makes the run noticeably longer, revisit how the host run covers Cursor.
- Phase 10 (when `uv` reaches the Mac): consider running the self-check pytest suite as part of `./host-test.sh`.

### Reviewed Todos (not folded)
- `2026-11-08-gsd-sync-leaves-root-owned-files.md`: belongs to Phase 9 (INIT-06).
- The bundle hook todos (`2026-10-24-bundle-hook-atomic-and-verified.md`, `2026-10-24-bundle-hook-keeps-user-skills.md`) and `2026-10-24-sbx-claude-no-wait-when-non-interactive.md`: belong to Phase 9.
- `2026-10-24-bundle-clone-error-hint-and-option-guard.md`, `2026-10-26-sbx-gh-login-skip-when-logged-in.md`: future requirements, not this phase.

</deferred>

---

*Phase: 08-in-image-self-check*
*Context gathered: 2026-11-14*
