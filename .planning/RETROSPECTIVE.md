# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0: Two-mount sandboxes

**Shipped:** 2026-11-12 (tag `v1.0`)
**Phases:** 13 | **Plans:** 89 | **Sessions:** not tracked

### What Was Built
- Two images (`sbx-base`, `sbx-claude`) with every tool pinned in `versions.env`; one sandbox folder mount, with code and state kept apart and login surviving rebuilds.
- GSD and ccusage baked in; the best-practices bundle from its own repo, editable from any sandbox through PRs.
- The `sbx-*` host scripts: add, start, stop, shell, list, rm, upgrade, fix-modes.
- Migration of the existing sandboxes and retirement of the old `cc-*` layout.
- An optional company root certificate (`SBX_CA_CERT`) for building behind Zscaler.

### What Worked
- Vertical phases: each one left a sandbox the user could run on the Mac.
- Pinning everything in one `versions.env` with `build.sh` as the only build path.
- Proving changes on the real Mac with one `./host-test.sh` run and its log.

### What Was Inefficient
- Tests outgrew the code: about 10.9k lines of test shell around about 2.1k lines of product shell.
- The fake docker was retired twice (Phases 1.4 and 2.1) and grew back (Phases 3 and 4), because each review fix added a scripted case.
- Several tests checked Claude, GSD or Docker behaviour (a fake Anthropic API, `claude -p`, interactive helpers) rather than our setup.
- Host tests replaced the user's real `:local` images and restarted one shared sandbox many times, which needed ordering chains and guards.
- Bash 3.2 and BSD portability on the Mac cost hand-written timeouts, terminal tricks and workarounds.

### Patterns Established
- Fail closed: an input the scripts cannot use stops them with an error.
- The image wins over persisted state; user data is never deleted by a host script except `sbx-rm`'s own registry entry.
- Code, `.planning/` and `.claude/` changes go in separate branches and PRs.

### Key Lessons
1. A test must check our setup, not someone else's software; use a proxy (file, link, owner, env var) instead of driving Claude.
2. A stand-in for Docker grows with every review fix; test against real Docker or not at all.
3. Logic belongs in Python, not bash; shell only for thin `exec` wrappers.
4. Test images must never be the images the user runs.
5. Work done at container start (start hooks, a readiness poll) costs more in tests than it saves; prefer a step the user runs and watches.

### Cost Observations
- Model mix: not tracked
- Sessions: not tracked
- Notable: review rounds that each added both code and a pinned test were the main source of growth.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | not tracked | 13 | Real-Docker Mac runs as the gate; tests grew faster than code |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | about 10.9k lines of test shell (guard, self-tests, H-00 to H-33, manual helpers) | not measured | n/a |

### Top Lessons (Verified Across Milestones)

1. (Filled in after v2.0.)
