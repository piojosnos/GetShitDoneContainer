---
phase: 08-in-image-self-check
review: 08-REVIEW.md
---

# Phase 08 code review disposition

| Finding | Severity | Title | Disposition |
|---|---|---|---|
| WR-01 | warning | The `no-root-owned-state` fix line tells the sandbox user to run a `chown` that cannot succeed | open |
| WR-02 | warning | `scan_owned_state` raises on an unreadable folder, so the check reports a crash instead of the root-owned path | open |
| WR-03 | warning | A missing or empty agent checks folder gives a green result with no agent checks | open |
| WR-04 | warning | `bash` and `keytool` are executed through PATH without the "not under /home" guard | open |
| IN-01 | info | `owned_by_uid_paths` is dead code in the image | open |
| IN-02 | info | Blank lines missing before control flow | open |
| IN-03 | info | Comprehensions and generator expressions in the tests | open |
| IN-04 | info | Dict-typed locals without a `Map` suffix, and an inconsistent exception name | open |
| IN-05 | info | Public functions without type hints | open |
| IN-06 | info | `managed_settings_result` reports a missing or unreadable file as "does not parse as JSON" | open |
| IN-07 | info | A test name and a constant hard-code the check counts | open |
| IN-08 | info | Host scripts: leftover state and a predictable shared folder | open |
