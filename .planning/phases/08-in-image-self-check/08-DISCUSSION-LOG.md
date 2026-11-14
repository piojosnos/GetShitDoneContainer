# Phase 8: In-image self-check - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-11-14
**Phase:** 08-in-image-self-check
**Areas discussed:** Claude and Cursor, SKIP and the count, extra checks, doctor output and skill, where checks live, the mount check, probe files

---

## Claude and Cursor

| Option | Description | Selected |
|--------|-------------|----------|
| Claude sandbox only | Agent checks written for both, only Claude exercised on the Mac | |
| Both agents | Start a Cursor test sandbox too; about a minute more | ✓ |

**User's choice:** Run per agent; accept the extra minute, revisit if the run gets long.

---

## SKIP and the count

| Option | Description | Selected |
|--------|-------------|----------|
| Plain container plus sandbox | Plain run proves SKIP; sandbox run expects all PASS | |
| Sandbox plus a no-FAIL plain run | Keeps the SKIP path tested at small cost | |
| Sandbox only, no SKIP | Drop SKIP entirely; checks outside a sandbox just FAIL | ✓ |

**User's choice:** Drop SKIP; a code path no run exercises should not exist.
**Notes:** The self-check always runs in a real sandbox (user's own, test sandboxes, later CI). H-22's "tools come from the image" point is kept by checking tool paths are outside `/home`.

---

## Extra checks

**User's choice:** Everything not interactive that can be tested from inside the sandbox. "gh logged in" is out (needs a real token).

---

## Doctor output and skill

| Option | Description | Selected |
|--------|-------------|----------|
| Skill in the bundle | One propagation mechanism; but the bundle must stay general and is missing exactly when the doctor is needed | |
| Skill in the image, linked by the same code | One mechanism, two sources | |
| No skill | Fix hints carry the explanation | ✓ |

**User's choice:** Drop the skill, less complexity. CHECK-04 amended.

---

## Where checks live

| Option | Description | Selected |
|--------|-------------|----------|
| One base script with agent-tagged checks | Base knows about both agents | |
| Base runner plus agent checks files | Base holds shared checks; each agent image adds its file to a fixed folder | ✓ |

**User's choice:** Base must not know about the agents; agent images delegate their own checks.

---

## The mount check (H-05 file reaches the Mac)

**User's choice:** Drop it; it tests our compose mount line, which H-06 and H-08/H-09 already prove.

---

## Probe files

**User's choice:** Agreed: H-01, H-04, H-05, H-13, H-14, H-15, H-22, H-30 deleted; H-06, H-12, H-25 slimmed to their Mac-only parts.

---

## Claude's Discretion

- Agent checks folder name and check declaration format
- Python shape of a check
- How the extra certificates are found
- How the interactive-shell line is checked from inside
- Doc updates

## Deferred Ideas

- Revisit Cursor coverage if the host run gets long.
