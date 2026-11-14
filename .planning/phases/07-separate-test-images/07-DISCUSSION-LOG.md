# Phase 7: Separate test images - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-11-14
**Phase:** 07-separate-test-images
**Areas discussed:** Choosing the tag, Tag naming, Proving `:local` untouched, Test images after a run

---

## Choosing the tag

| Option | Description | Selected |
|--------|-------------|----------|
| (a) One variable | `SBX_IMAGE_TAG` read by `build.sh`, `compose.yml`, `sbx-lib.sh`, passed as `BASE_IMAGE`; default `local`, test run sets `test`; only `local` or `test` accepted | ✓ |
| (b) Copy and rewrite | Tests copy the repo and `sed` the tags; no production change, but tests stop running the real scripts | |

**User's choice:** (a), as recommended.

---

## Tag naming

| Option | Description | Selected |
|--------|-------------|----------|
| Same names, `:test` tag | `sbx-claude:test` next to `sbx-claude:local` | ✓ |
| Separate names | `sbx-test-claude:local` | |

**User's choice:** Same names, different tag.

---

## Proving `:local` untouched

| Option | Description | Selected |
|--------|-------------|----------|
| Automated step | Record the `:local` image IDs before the run, compare at the end | |
| No check | Rely on the design | ✓ |

**User's choice:** No check.
**Notes:** "We wouldn't do that check if I was writing the code manually. It is over paranoid."

---

## Test images after a run

| Option | Description | Selected |
|--------|-------------|----------|
| Keep | Reuse the build cache; `clean.sh` removes them when unused | ✓ |
| Remove after each run | | |

**User's choice:** Keep. "Simpler."

---

## Claude's Discretion

- Where the allowed-value check lives; how `run_compose` passes the tag; self-test, guard and doc updates.

## Deferred Ideas

None.
