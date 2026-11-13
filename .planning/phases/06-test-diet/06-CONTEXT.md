# Phase 6: Test diet - Context

**Gathered:** 2026-11-13
**Status:** Ready for planning

<domain>
## Phase Boundary

The test suite checks only our own setup and runs with nobody at the keyboard. Deletions only, no rewrite: the manual helpers, the checks of Claude, GSD, Docker and Maven Central behaviour, the guard self-test and every stand-in `docker` go. Simple proxies cover what the manual helpers used to prove. Requirements DIET-01 to DIET-05; success criteria in `.planning/ROADMAP.md` Phase 6.

</domain>

<decisions>
## Implementation Decisions

### Carried forward (v2 decisions doc, not re-asked)
- **D-01:** Deletions only, no rewrite. Phases 8 to 10 rebuild what is left.
- **D-02:** No test drives Claude (no `claude -p`). Proxies only: a file, link, owner or env var is in place.
- **D-03:** Host check IDs keep their gaps; nothing is renumbered (Phase 8 names checks by ID).

### Persistence proxies (DIET-03)
- **D-04:** The fake credentials file and the fake session file are planted in H-09 (rebuild and recreate) and in H-29 (`sbx-upgrade`), next to the sentinels those checks already plant. Both use one small shared plant and check helper, so the two checks stay alike. No new host check.
- **D-05:** `DISABLE_UPDATES`, the managed settings and the bundle links are proved by the parts of H-13, H-14 and H-15 that stay (see D-06); no extra check for them.

### What stays in the trimmed checks (DIET-02)
- **D-06:**
  - H-13 keeps the five env vars (including `DISABLE_UPDATES`) and the two "no local claude" path tests; the `claude update` reply goes.
  - H-15 keeps "the container reads the clone's rule through `~/.claude/rules`"; the `claude -p /context` listing goes.
  - H-16 keeps the live clone, the relink on restart and the user files surviving it; the "GSD aged and resynced to the pin" part and its GSD skill edit go.
  - H-23 keeps the cache folders under `state/`, the tools finding them and a marker surviving a recreate; the Maven download from Maven Central goes.

### No stand-in docker at all (DIET-05, changes roadmap criterion 1)
- **D-07:** Both stand-ins go: the scripted fake docker and the 7-line fence in `tests/selftest/sbx/lib.sh` (`start_group`, `make_scripted_docker`, `set_standin_*`, `reset_standin_calls`, `run_sbx_scripted`, `no_docker_call`). The user wants no mock of Docker in the tests.
- **D-08:** The sbx self-test keeps the cases where a script must refuse before Docker (bad name, wrong usage, unregistered name, refusal before compose). They run with `DOCKER_HOST=unix:///nonexistent` set by the group setup, so the real `docker` cannot reach any daemon. A case that calls Docker too early fails on its exit code and error text. Every case that needs Docker to answer (container running, stopped, older image, `ps` rows, down failing) is deleted; H-28 to H-33 cover those paths with real Docker.
- **D-09:** Roadmap criterion 1 and DIET-05 say "only the 7-line fence stays". Update both to "no stand-in `docker` is left" in the same planning change.

### host-test.sh (DIET-01)
- **D-10:** `--keep` stays, reworded as "leave the test sandbox up to look around after a failure". The `tests/host/manual/` hint and the "holds a Claude login if a helper logged in" text in the cleanup output go (`host-test.sh` header and `tests/host/run-all.sh` `print_next_block`).
- **D-11:** H-00 becomes one preflight line in `host-test.sh` (Compose v2 present); `h00-compose-v2.sh` and its fatal slot in `tests/host/run-all.sh` go.

### Claude's Discretion
- Which self-test cases count as "refuses before Docker" when sorting `start.sh`, `shell.sh`, `list.sh` and `rm.sh`; a group left with no case is deleted with its `run-all.sh` entry.
- The exact guard rule shape for the managed deny entries and the one-FROM rule (DIET-04), and which three `tests/guard/start.sh` rules H-20 covers.
- How H-11 folds into H-28 (stop is quick and keeps the files).
- Doc updates that follow the deletions: `tests/README.md`, `tests/host-checklist.md`, the README and `MIGRATION.md` mentions of the manual helpers.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and decisions
- `.planning/ROADMAP.md` (Phase 6) : goal and success criteria (criterion 1 changed by D-09)
- `.planning/REQUIREMENTS.md` (DIET-01 to DIET-05) : requirements (DIET-05 changed by D-09)
- `.planning/research/v2-simple-tooling-decisions.md` : milestone principles and the full delete list

### Tests touched
- `tests/README.md` : what each suite is for; must match the code after the phase
- `tests/host-checklist.md` : the reading guide per host check
- `tests/host/run-all.sh` : check lists and run order
- `host-test.sh` : the Mac entry point (`--keep`, `sandbox_suites` runs `tests/selftest/guard/`)
- `tests/selftest/sbx/lib.sh` : the fence and the scripted fake docker

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- H-09 and H-29 already plant sentinel files and check them after the rebuild or upgrade; the credentials and session plants slot in beside them.
- H-16 already plants a session file (`h16-session.jsonl`); its pattern fits the shared helper.
- `tests/host/lib.sh` holds the shared host helpers; the plant helper belongs there or in a new small `lib-*.sh`.

### Established Patterns
- Host checks are chained in `tests/host/run-all.sh`; a deleted check must leave all three lists (`noSandboxCheckList`, `sandboxCheckList`, `chainCheckList`).
- `host-test.sh` `sandbox_suites` runs `tests/selftest/guard/run-all.sh`; that entry goes with the suite.
- The sbx self-test runs in the dev sandbox and in the Mac shell under `/bin/bash` 3.2; the `DOCKER_HOST` setting must work in both.

### Integration Points
- `tests/host/manual/` is referenced from `host-test.sh`, `tests/host/run-all.sh`, the H-09, H-13 and other check headers, and the docs.
- `tests/host/support/fake-claude-api.js` is used by H-18 only.

</code_context>

<specifics>
## Specific Ideas

- The user wants the test tooling simple over clever: no mock of Docker, even a 7-line one.

</specifics>

<deferred>
## Deferred Ideas

- A `docker` wrapper script or a dry-run flag in the `sbx-*` commands, so the refusal tests can prove that no Docker call was made. Revisit in Phase 10 (host side to Python), where the pytest refusal group lands.

### Reviewed Todos (not folded)
- The bundle hook todos (atomic links, keeping user skills), the `sbx-claude` wait and the GSD root-owned files: Phase 9 (`sbx-init`).
- `sbx-bundle-clone` error hint, `sbx-gh-login` skip, the leaked-token limit: Future Requirements in `.planning/REQUIREMENTS.md`.
- MIGRATION.md follow-ups, the CLAUDE.md refresh and the phase 5 review nits: docs work, not a test diet.

</deferred>

---

*Phase: 06-test-diet*
*Context gathered: 2026-11-13*
