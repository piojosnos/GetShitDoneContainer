---
phase: "1"
slug: "two-mount-claude-sandbox"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-30"
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None (infrastructure phase). Tier 1: plain-bash static assertions run in the dev sandbox. Tier 2: manual host-side checks on the Mac (Docker isn't available in the dev sandbox) |
| **Config file** | none — Wave 0 adds `tests/static-check.sh` |
| **Quick run command** | `bash tests/static-check.sh` |
| **Full suite command** | `bash tests/static-check.sh`, then the host checklist H-00..H-13 (see `01-RESEARCH.md` §Validation Architecture) on the Mac |
| **Estimated runtime** | ~2 seconds (static); ~15 minutes (host checklist, including the `--no-cache` rebuild) |

---

## Sampling Rate

- **After every task commit:** Run `bash tests/static-check.sh`
- **After every plan wave:** Run `bash tests/static-check.sh` (plus `shellcheck`/`hadolint` if they were downloaded to scratch)
- **Before `/gsd-verify-work`:** Static checks green AND the user reports H-00..H-13 passing on the Mac
- **Max feedback latency:** 5 seconds (static tier)

---

## Per-Task Verification Map

*Task IDs filled by the planner (2026-09-30). Every task's quick run is `bash tests/static-check.sh`. The PASS label that proves each row is shown in quotes.*

| Requirement | Task(s) | Secure Behavior | Test Type | Automated Command (static) | Host Check | Status |
|-------------|---------|-----------------|-----------|----------------------------|------------|--------|
| LAY-01 | 01-01 T2 | Nothing mounted over /home/sandbox; `.local` sandbox-owned | static + host | `bash tests/static-check.sh` ("workspace bind target", "nothing mounted over /home/sandbox", "home directories created as the sandbox user") | H-05 | ⬜ pending |
| LAY-02 | 01-01 T2, 01-02 T2 | State is a directory mount, never a single file | static + host | `bash tests/static-check.sh` ("CLAUDE_CONFIG_DIR is the claude state mount target", "exactly five bind mounts") | H-07, H-09 | ⬜ pending |
| LAY-03 | 01-02 T1 | History persists | static + host | `bash tests/static-check.sh` ("HISTFILE and PROMPT_COMMAND in image ENV", "shell history bind target") | H-08 | ⬜ pending |
| LAY-04 | 01-01 T2, 01-01 T3, 01-03 T1 | No data-deleting paths (no VOLUME, no volumes flag on down); no run without mounts | static + host | `bash tests/static-check.sh` ("no VOLUME instruction", "docs never remove volumes on down", "entrypoint checks mounts then execs") | H-09, H-11, H-12 | ⬜ pending |
| IMG-02 | 01-01 T2, 01-03 T1 | Claude image FROM base, agent-only additions | static + host | `grep -Fxq 'FROM ${BASE_IMAGE}' claude/Dockerfile` | H-02 | ⬜ pending |
| IMG-05 | 01-01 T2, 01-02 T2 | Native arm64, no emulation | static + host | `bash tests/static-check.sh` ("no platform override") | H-01 | ⬜ pending |
| IMG-06 | 01-01 T2, 01-03 T2 | Non-root UID 1000, safe.directory, no-new-privileges, cap_drop | static + host | `grep -Fq "safe.directory '*'" base/Dockerfile` | H-04, H-06 | ⬜ pending |
| D-10 | 01-01 T2, 01-03 T1, 01-03 T2 | Refuse start on missing dirs | static + host | `bash tests/static-check.sh` ("every bind mount sets create_host_path false", "docs carry the missing-folder preflight") | H-10, H-12 | ⬜ pending |
| Coexistence | all tasks | Old layout untouched, no old-prefix names, no runtime installs, no compromised GSD | static | `git diff --quiet 934e2c5694dbc1524ae9993f2bf025ffa779358e -- ClaudeCode OpenCode README.md` (inside static-check: "old layout untouched") | coexistence note | ⬜ pending |
| Supply chain | 01-01 T1 | Claude Code npm package approved before pin | human (blocking) | n/a | H-12 (version equals pin) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/static-check.sh`: plain-bash assertions for LAY-01..04, IMG-02, IMG-05, IMG-06, naming, pins, coexistence. Created by the tracer (01-01 T2) and extended by every later task
- [ ] `SANDBOX.md`: Phase 1 usage (01-01 T3, 01-02, 01-03) plus the H-00..H-13 host checklist (01-04 T1)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Images build and run natively on arm64 | IMG-05 | No Docker in the dev sandbox | H-01 |
| Login survives recreate + `--no-cache` rebuild | LAY-02 | Needs a real login and Docker | H-07, H-09 |
| History survives recreate | LAY-03 | Needs Docker | H-08 |
| No volumes, data intact after down/up | LAY-04 | Needs Docker | H-09, H-11 |
| git works without dubious ownership | IMG-06 | Docker Desktop VirtioFS behavior | H-06 |
| Missing dirs refuse start | D-10 | Compose `create_host_path` behavior varies by version | H-10 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
