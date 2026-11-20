# Phase 10: Host side to Python - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-11-19
**Phase:** 10-host-side-to-python
**Areas discussed:** How a command runs through uv, Registry migration, Which host checks survive, Test runner and scenarios, Suite names, Scope of "no bash", host-test.sh runs everything, Todos to fold

---

## How a command runs through uv

| Option | Description | Selected |
|--------|-------------|----------|
| Keep the small commands in bash | `sbx-start`, `sbx-stop`, `sbx-shell` look trivial | |
| All Python | their logic lives in `sbx-lib.sh`; a split duplicates it in two languages | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| (a) PEP 723 uv scripts | no shell; each file patches the import path | |
| (b) `uv tool install --editable` with `[project.scripts]` | the textbook Python practice; one install step | |
| (c) package plus two-line launchers | no install; names and PATH stay | ✓ |

**User's choice:** (c).
**Notes:** The user asked what the best practice is, ignoring churn; that is (b). The user is not ready to add an install step without a stronger reason from real use, so (c) now, with modules shaped so (b) is a small later switch. Python is also cleaner to unit test.

---

## Registry migration

| Option | Description | Selected |
|--------|-------------|----------|
| (a) Convert on the fly | no user action; read commands start writing | |
| (b) One-off `sbx-migrate-registry` | explicit; easy to delete later | ✓ |
| (c) No conversion, rerun `sbx-add` | no code; manual | |

**User's choice:** (b), deleted eventually.

---

## Test runner and scenarios

| Option | Description | Selected |
|--------|-------------|----------|
| pytest | fixtures, parametrize per agent, free summary | ✓ |
| Plain Python scripts with PASS/FAIL lines | today's output; a hand-rolled runner again | |

**User's choice:** pytest without `-x`.
**Notes:** The user asked why a group stops at its first failure and whether checks depend on each other. Today a 10-check chain hides later checks after one failure. Decided: a test is one end-to-end scenario that stops at its first failed step; scenarios are independent; the shared test sandbox is fine for integration tests (like a shared database) if it is clear and managed. The user insisted the scenario rule be stated very clearly and that each test carries a 1 to 3 line schematic header.

---

## Which host checks survive

**User's choice:** every check survives as a scenario except H-03's compose variables part; later also drop H-35's lock part and move H-25's bare-build refusal to a unit test. A mapping of old to new steps goes into the plan.

---

## Suite names

**User's choice:** `tests/integration/` (README states host only); drop the H-nn IDs; shrink `tests/host-checklist.md` to the manual Cursor login check and reading `host-test.log`.

---

## Scope of "no bash" and host-test.sh

**User's choice:** anything with real logic goes to Python, including `tests/guard/`, `clean.sh`, `sbx-fix-modes`. `./host-test.sh` stays the one command and runs every suite.

---

## Todos to fold

**Notes:** The user asked whether any of it tests third-party behavior, is paranoid or adds needless complexity. Result: fold only what the rewrite gives for free (H-34 hygiene a and c, selfcheck follow-ups d and e, test duplication d); close H-34 hygiene b and selfcheck a to c as not worth doing.

## Claude's Discretion

Package location and names, launcher flags, where the Mac's uv environment lives, the `step()` helper, guard file grouping, fixture state restore, doc updates.

## Deferred Ideas

- Installed tool via `uv tool install --editable .`
- Delete `sbx-migrate-registry` once every sandbox has moved
