# Phase 7: Separate test images - Context

**Gathered:** 2026-11-14
**Status:** Ready for planning

<domain>
## Phase Boundary

A `./host-test.sh` run builds and uses its own image tags, so it never replaces `sbx-base:local`, `sbx-claude:local` or `sbx-cursor:local`, the images the user's sandboxes run. `build.sh`, `sbx-upgrade` and the user's sandboxes keep building and running the `:local` tags.

The test run exercises the real `sbx-*` commands (H-28 and H-33 run `sbx-add`, `sbx-start` and `sbx-rm`; H-29 runs `sbx-upgrade`, which runs `build.sh`), so the tag cannot be swapped in the test files alone: it must reach `build.sh`, `compose.yml`, `bin/sbx-lib.sh` and the agent Dockerfiles' `BASE_IMAGE`.

</domain>

<decisions>
## Implementation Decisions

### Choosing the tag
- **D-01:** One variable, `SBX_IMAGE_TAG`, picks the image tag. `build.sh`, `compose.yml` and `bin/sbx-lib.sh` read it; `build.sh` passes `BASE_IMAGE=sbx-base:$SBX_IMAGE_TAG` to the agent image builds. Unset, it means `local`, so every command behaves as today.
- **D-02:** Only `local` and `test` are accepted. Any other value stops the command with an error naming the two allowed values, so a typo cannot create a third image set.
- **D-03:** The test run does not copy the repo or rewrite tags with `sed`; it runs the real scripts with the variable set.

### Tag naming
- **D-04:** Same image names, different tag: `sbx-base:test`, `sbx-claude:test`, `sbx-cursor:test`. The compose image line becomes `sbx-${SBX_AGENT}:${SBX_IMAGE_TAG}` (with the `local` default).

### The test run
- **D-05:** `host-test.sh` sets `SBX_IMAGE_TAG=test` for the whole run. Every host check, the linter stand-ins (`make_linter_standin`, `linter_versions`) and the in-sandbox suites use the test tags; no host check names a `:local` tag. The log names the test tags.
- **D-06:** No step compares the `:local` image IDs before and after a run. The user judged it over paranoid: the run never names `:local`, so the guarantee comes from the design. Success criterion 2 is confirmed by eye at the Mac gate, not by a new check.

### Test images after a run
- **D-07:** The test images stay between runs; the next run reuses their build cache. `clean.sh` removes the `:test` images along with the `:local` ones when no container uses them.

### Size of the change
- **D-08:** Keep the bash change small and plain. Phase 10 rewrites the host side in Python, so this phase adds the variable and nothing more.

### Claude's Discretion
- Where exactly the allowed-value check lives (a helper in `bin/sbx-lib.sh` used by the `sbx-*` scripts, and a matching check in `build.sh`).
- How `run_compose` hands the tag to compose (set explicitly on the one command after the check, keeping its "never taken from the caller" spirit).
- Updating the self-test expectations (for example `tests/selftest/sbx/entry.sh` lines that expect `sbx-cursor:local`) and any guard rule that names `:local`.
- Doc updates (`README.md`, `tests/README.md`, the comments in `build.sh` and `compose.yml`) for the variable and the test tags.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and requirements
- `.planning/ROADMAP.md` (Phase 7 section): goal and the three success criteria
- `.planning/REQUIREMENTS.md`: IMG-01, IMG-02
- `.planning/research/v2-simple-tooling-decisions.md`: item 2 and the old Phase 05.3 goal text

### Prior decisions that constrain this phase
- `.planning/phases/06.1-cursor-agent-image/06.1-CONTEXT.md`: D-13 (`build.sh` and `sbx-upgrade` always build both agent images; compose picks the image from the entry's agent)

</canonical_refs>

<code_context>
## Existing Code Insights

### Places that name `:local` today
- `build.sh:159-165`: builds `sbx-base:local`, `sbx-claude:local`, `sbx-cursor:local`
- `claude/Dockerfile:7`, `cursor/Dockerfile:7`: `ARG BASE_IMAGE=sbx-base:local`
- `compose.yml:14`: `image: "sbx-${SBX_AGENT:-claude}:local"`
- `bin/sbx-lib.sh:176`: `agentImage=sbx-$entryAgent:local` (used by `require_images` and `runs_older_image`)
- `host-test.sh:71-72,137`: linter stand-ins run from `sbx-base:local`
- `tests/host/lib-docker.sh` `build_images`: runs plain `build.sh`
- Host checks naming `:local`: h01, h12, h17, h22, h25, h27, h29, h30, h33
- `tests/selftest/sbx/entry.sh:75,79`: expects `sbx-cursor:local` and `sbx-claude:local`
- `clean.sh:116-117`: removes the `:local` images when unused

### Established Patterns
- `run_compose` sets `SBX_NAME`, `SBX_DIR` and `SBX_AGENT` on the one compose command and never takes them from the caller.
- `build.sh` passes every `versions.env` pin as a bare `--build-arg NAME`; `BASE_IMAGE` is not a pin and keeps its Dockerfile default.

### Integration Points
- `sbx-upgrade` runs `build.sh` in its own process, so the exported variable reaches it.

</code_context>

<specifics>
## Specific Ideas

- The user wants the plain solution they would write by hand: no extra safety checks beyond what the design needs.

</specifics>

<deferred>
## Deferred Ideas

None; discussion stayed within phase scope.

</deferred>

---

*Phase: 07-separate-test-images*
*Context gathered: 2026-11-14*
