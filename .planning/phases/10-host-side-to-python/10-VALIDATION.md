---
phase: "10"
slug: "host-side-to-python"
# status lifecycle: draft (seeded by plan-phase) -> validated (set by validate-phase)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-19"
---

# Phase 10: Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 9.2.0 |
| **Config file** | `pyproject.toml` (`[tool.pytest.ini_options]`) |
| **Quick run command** | `uv run pytest tests/unit/sbx tests/guard -q` |
| **Full suite command** | `uv run pytest` (dev sandbox); `./host-test.sh` on the host for everything including `tests/integration` |
| **Estimated runtime** | ~30 seconds (dev sandbox); host run is minutes (image builds, two agents) |

---

## Sampling Rate

- **After every task commit:** Run `uv run pytest tests/unit/sbx tests/guard -q`
- **After every plan wave:** Run `uv run pytest`; for Docker-dependent waves the user runs `./host-test.sh` and Claude reads `host-test.log`
- **Before `/gsd-verify-work`:** `./host-test.sh` green on the host
- **Max feedback latency:** 60 seconds (dev sandbox)

---

## Per-Task Verification Map

Filled by the planner per task. Requirement-level map:

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| HOST-01 | every launcher is two lines, `exec uv run`, names an existing module, mode 100755 | guard | `uv run pytest tests/guard -k launcher -q` | W0 | pending |
| HOST-01 | each launcher with no arguments exits 2 with its `Usage:` line | unit | `uv run pytest tests/unit/sbx -k launcher -q` | W0 | pending |
| HOST-01 | same names on macOS through uv | integration, host | `./host-test.sh` | W0 | pending |
| HOST-02 | entry JSON content, exclusive create, values read as data, broken forms, migration | unit | `uv run pytest tests/unit/sbx -k registry -q` | W0 | pending |
| HOST-03 | overlap function resolves symlink and `..`; holds, inside, text prefix; sbx-add refusals | unit | `uv run pytest tests/unit/sbx -k "overlap or add" -q` | W0 | pending |
| HOST-04 | persistence, refusal, failed upgrade, smoke, isolation, first run, init and selfcheck, owner, images match; per agent; first failed step named | integration, host only | `./host-test.sh` | W0 | pending |
| HOST-05 | no `.sh` under `tests/`, `bin/` holds only launchers, no stand-in docker, bash helpers gone | guard | `uv run pytest tests/guard -k no_host_shell -q` | W0 | pending |

---

## Wave 0 Requirements

- [ ] `pyproject.toml` `testpaths` and `pythonpath` edit
- [ ] `tests/unit/sbx/conftest.py` (tmp registry, recorder Docker function, injected environ)
- [ ] `tests/guard/` Python rule files and the `nowhere_matches` helper
- [ ] `tests/integration/conftest.py`, the agent spec table, the sandbox harness, `step()`
- [ ] `tests/unit/selfcheck/test_inventory.py` reads counts from the agent spec table

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Launchers run through uv on macOS, Python downloaded on first use | HOST-01 | Docker and macOS not in the dev sandbox | `./host-test.sh`, read `host-test.log` |
| `sbx-shell` TTY, Ctrl-C and exit status under uv | HOST-01 | needs a real terminal on the host | run `sbx-shell NAME`, exit with a code, Ctrl-C a command |
| macOS case-insensitive overlap on existing directories | HOST-03 | APFS behavior | covered by `./host-test.sh` on the Mac |
| Manual Cursor login | HOST-04 | interactive login | `tests/host-checklist.md` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
