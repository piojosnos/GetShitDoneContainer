---
phase: "04"
slug: "jump-in-and-sandbox-housekeeping"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-07"
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Plain bash suites: guard (`tests/guard/`), self-tests (`tests/selftest/sbx/`, `tests/selftest/guard/`, `tests/selftest/entrypoint/`), host checks (`tests/host/`, Mac + Docker) |
| **Config file** | none (`.shellcheckrc`, `.hadolint.yaml` for lint) |
| **Quick run command** | `bash tests/selftest/sbx/run-all.sh && bash tests/selftest/guard/run-all.sh && bash tests/guard/run-all.sh` |
| **Full suite command** | On the Mac: `./host-test.sh` (then read `host-test.log`); attended: `bash tests/host/manual/h31-jump-in.sh` |
| **Estimated runtime** | ~30 seconds quick; host suite several minutes |

In this dev sandbox the guard without linters ends with exactly two FAILs (`shellcheck_passes`, `hadolint_passes`: not installed); with `PATH="${TMPDIR:-/tmp}/sbx-linters/bin:$PATH"` it ends `All rules hold.`. Docker is not available here: every Docker behaviour (H-31, H-32) is proven only by the Mac run.

---

## Sampling Rate

- **After every task commit:** Run the quick run command
- **After every plan wave:** Run the quick run command plus shellcheck on the new `bin/` files when available
- **Before `/gsd-verify-work`:** Full suite must be green on the Mac
- **Max feedback latency:** 30 seconds (quick suite)

---

## Per-Task Verification Map

Filled in from the PLAN.md files once planning passes. Requirement level map (from 04-RESEARCH.md):

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| SCR-04 | usage, refusals before any exec; start-if-needed then `docker exec -it -w /home/sandbox/workspace/NAME`; running gets exec only; exit status passes through; `sbx-start` hint names `sbx-shell` | selftest | `bash tests/selftest/sbx/run-all.sh` | ❌ W0 `shell.sh` | ⬜ pending |
| SCR-04 | real start and shell in the project folder; running one entered without recreate | host | `./host-test.sh` (H-31) | ❌ W0 | ⬜ pending |
| SCR-05 | three statuses, path with spaces, older-image marker, error row, leftover section, `docker ps` failure exits 1 | selftest | `bash tests/selftest/sbx/run-all.sh` | ❌ W0 `list.sh` | ⬜ pending |
| SCR-05 | status equals `docker ps -a` in all three states | host | `./host-test.sh` (H-31) | ❌ W0 | ⬜ pending |
| SCR-06 | `down` with exact scope, no `-v`/`--volumes`/`--rmi`; `--unregister` only after a good `down`; folder untouched; closing line | selftest | `bash tests/selftest/sbx/run-all.sh` | ❌ W0 `rm.sh` | ⬜ pending |
| SCR-06 | rewritten data rule passes clean tree, fails each planted violation | guard + guard selftest | `bash tests/guard/run-all.sh && bash tests/selftest/guard/run-all.sh` | modify | ⬜ pending |
| SCR-06 | container gone, sentinels intact, re-register brings back login and history | host | `./host-test.sh` (H-32) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/selftest/sbx/shell.sh`, `list.sh`, `rm.sh`: new groups for SCR-04, SCR-05, SCR-06
- [ ] `tests/selftest/sbx/lib.sh`: stand-in docker gains `ps`, `exec -it` status and compose-failure knobs
- [ ] `tests/guard/isolation.sh` and `tests/selftest/guard/sandbox-rules.sh`: data rule rewrite and planted cases (with, or before, `bin/sbx-rm`)
- [ ] `tests/host/h31-sbx-shell-list.sh`, `tests/host/h32-sbx-rm.sh`, `tests/host/manual/h31-jump-in.sh`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Interactive terminal shell, then `sbx-claude` starts logged in | SCR-04 | needs a real terminal and a real login | `bash tests/host/manual/h31-jump-in.sh` on the Mac |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
