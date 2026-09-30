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

*The planner fills in task IDs. Requirement → check mapping:*

| Requirement | Secure Behavior | Test Type | Automated Command (static) | Host Check | Status |
|-------------|-----------------|-----------|----------------------------|------------|--------|
| LAY-01 | Nothing mounted over /home/sandbox | static + host | `grep -Fq 'target: /home/sandbox/workspace' compose.yml` | H-05 | ⬜ pending |
| LAY-02 | State is a directory mount, never a single file | static + host | `grep -q 'CLAUDE_CONFIG_DIR=/home/sandbox/.claude' claude/Dockerfile` | H-07, H-09 | ⬜ pending |
| LAY-03 | History persists | static + host | `grep -q 'HISTFILE=' base/Dockerfile` | H-08 | ⬜ pending |
| LAY-04 | No data-deleting paths (no VOLUME, no down -v) | static + host | `! grep -nE '^\s*VOLUME\b' base/Dockerfile claude/Dockerfile` | H-09, H-11 | ⬜ pending |
| IMG-02 | Claude image FROM base | static + host | `grep -Fxq 'FROM ${BASE_IMAGE}' claude/Dockerfile` | H-02 | ⬜ pending |
| IMG-05 | Native arm64, no emulation | static + host | `! grep -rnE 'platform:\|--platform\|linux/amd64' base claude compose.yml` | H-01 | ⬜ pending |
| IMG-06 | Non-root UID 1000, safe.directory | static + host | `grep -Fq "safe.directory '*'" base/Dockerfile` | H-04, H-06 | ⬜ pending |
| D-10 | Refuse start on missing dirs | host | — | H-10, H-12 | ⬜ pending |
| Coexistence | Old layout untouched, no cc_ names, no npx/GSD | static | `git diff --quiet <phase-base> -- ClaudeCode OpenCode` | coexistence note | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/static-check.sh` — plain-bash assertions for LAY-01..04, IMG-02, IMG-05, IMG-06, naming, pins, coexistence
- [ ] `SANDBOX.md` — Phase 1 usage plus the H-00..H-13 host checklist

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
