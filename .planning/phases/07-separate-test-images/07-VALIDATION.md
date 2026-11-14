---
phase: "07"
slug: "separate-test-images"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-14"
---

# Phase 07: Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | plain bash suites with their own `expect` / `run_rules` helpers |
| **Config file** | none; `.shellcheckrc` and `.hadolint.yaml` for the linter rules |
| **Quick run command** | `bash tests/selftest/sbx/run-all.sh && bash tests/guard/run-all.sh` |
| **Full suite command** | `./host-test.sh` (Mac only; writes `host-test.log`) |
| **Estimated runtime** | ~10 seconds (quick); full run on the Mac only |

---

## Sampling Rate

- **After every task commit:** Run `bash tests/selftest/sbx/run-all.sh && bash tests/guard/run-all.sh`
- **After every plan wave:** Same, plus `bash -n` on every edited script
- **Before `/gsd-verify-work`:** Full `./host-test.sh` green on the Mac plus the manual image ID comparison
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01-xx | 01 | 1 | IMG-01 | n/a | `SBX_IMAGE_TAG` accepts only `local` and `test`; unset or empty means `local` | selftest | `bash tests/selftest/sbx/image-tag.sh` | ❌ W0 | ⬜ pending |
| 07-01-xx | 01 | 1 | IMG-01 | n/a | compose image line and `run_compose` carry the tag | guard | `bash tests/guard/start.sh` | ✅ (edit) | ⬜ pending |
| 07-02-xx | 02 | 2 | IMG-01 | n/a | no host test file names `:local` | guard | `bash tests/guard/run-all.sh` | ❌ W0 | ⬜ pending |
| 07-02-xx | 02 | 2 | IMG-01 | n/a | the real run builds and uses `:test` | host | `./host-test.sh` (Mac) | ✅ (edit) | ⬜ pending |
| 07-02-xx | 02 | 2 | IMG-02 | n/a | `:local` image IDs unchanged by a test run | manual | see Manual-Only Verifications | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/selftest/sbx/image-tag.sh`: allow-list, agent image mapping, `build.sh` tag naming (IMG-01)
- [ ] `tests/selftest/sbx/lib.sh`: `start_group` unsets `SBX_IMAGE_TAG` and `SBX_CA_CERT`
- [ ] guard rule `host_tests_never_name_the_local_tag` and the updated compose image rule

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `:local` image IDs identical before and after a full run | IMG-02 | Docker is not available in the dev sandbox; D-06 rules out an automated comparison | `docker image inspect --format '{{.RepoTags}} {{.Id}}' sbx-base:local sbx-claude:local sbx-cursor:local` before and after `./host-test.sh` |
| `host-test.sh` builds `:test` and the log names the test tags | IMG-01 | Needs a real Docker build | `./host-test.sh`; check `host-test.log` for the image tag line and `building sbx-base:test` |
| `build.sh` and `sbx-upgrade` still build `:local` when unset | IMG-02 | Needs a real Docker build | `./build.sh` prints `building sbx-base:local`; `SBX_IMAGE_TAG=bogus ./build.sh` refuses |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
