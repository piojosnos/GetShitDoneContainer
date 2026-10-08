---
phase: "2"
slug: "pinned-toolchain-gsd-and-ccusage"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-08"
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Plain bash suites in three layers: guard (static rules), self-tests (Linux, fake docker), host checks (Mac, real Docker) |
| **Config file** | none; `tests/guard/lib.sh`, `tests/selftest/lib-expect.sh`, `tests/host/lib.sh` |
| **Quick run command** | `bash tests/guard/run-all.sh` |
| **Full suite command** | Linux: `bash tests/guard/run-all.sh && bash tests/selftest/guard/run-all.sh && bash tests/selftest/entrypoint/run-all.sh && bash tests/selftest/host/run-all.sh && bash tests/selftest/bundle/run-all.sh`; Mac: `bash tests/host/run-all.sh` |
| **Estimated runtime** | Linux ~60 seconds; Mac host run several minutes (image builds) |

---

## Sampling Rate

- **After every task commit:** Run `bash tests/guard/run-all.sh` plus the self-test group(s) for the files touched
- **After every plan wave:** Run all four self-test runners and the guard
- **Before `/gsd-verify-work`:** `bash tests/host/run-all.sh` green on the Mac (human checkpoint)
- **Max feedback latency:** 60 seconds (Linux layers)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| (filled by planner) | | | | | | | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `versions.env`, `build.sh` and the Dockerfile edits come first
- [ ] Guard rewrite: `versions_are_pinned`, file lists, COPY-flag parsing, `.dockerignore` rule
- [ ] Host library: `build_images` via `build.sh`, `claude_pin` from `versions.env`, `pin_of NAME`, a poll-until-synced helper, an `elf_machine` helper
- [ ] Fake docker knobs for the new host checks and the `versions.env` pin source
- [ ] New host checks (toolchain, pins and GSD record, ccusage, caches), each with checklist row, `run-all.sh` placement and self-test group

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full host suite passes on real Docker | all | Docker is not available in the dev sandbox | `bash tests/host/run-all.sh` on the Mac |
| Real GSD bump keeps login and history | TOOL-02 | Needs a real logged-in sandbox | Attended helper in `tests/host/manual/` |
| A pin bump rebuilds only its own and later layers | IMG-03 | One-time cache observation | Attended observation on the Mac |
| Each new pin approved | IMG-03 | Supply-chain review is a human decision | Checkpoint per pin during execution |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
