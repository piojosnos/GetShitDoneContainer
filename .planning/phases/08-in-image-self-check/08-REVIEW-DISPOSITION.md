---
phase: 08-in-image-self-check
review: 08-REVIEW.md
---

# Phase 08 code review disposition

| Finding | Severity | Title | Disposition | Reason |
|---|---|---|---|---|
| WR-01 | warning | The `no-root-owned-state` fix line tells the sandbox user to run a `chown` that cannot succeed | fixed | 9f17723, 591dd80, 78f9fb0: the fix line gives the Mac command (a throwaway root container through `--volumes-from`), plan 08-08; H-34 runs it on real Docker, plan 08-09 |
| WR-02 | warning | `scan_owned_state` raises on an unreadable folder, so the check reports a crash instead of the root-owned path | fixed | 124297b, 1f4c2e4: unreadable folders are named with `(unreadable)` and vanished folders are skipped, plan 08-08 |
| WR-03 | warning | A missing or empty agent checks folder gives a green result with no agent checks | fixed | 5e304b3, feff7d5: a runner level `load-agent-checks` FAIL when the agent folder yields no check, counts unchanged, plan 08-08 |
| WR-04 | warning | `bash` and `keytool` are executed through PATH without the "not under /home" guard | fixed | 0ca3e69, 6fe06ee: `tool-bash` and `tool-keytool` lines, counts 41, 53 and 51, plan 08-09 |
| IN-01 | info | `owned_by_uid_paths` is dead code in the image | fixed | 124297b: the test-only wrapper is gone, plan 08-08 |
| IN-02 | info | Blank lines missing before control flow | fixed | feff7d5, 5e304b3, 6fe06ee, 183206d: the four blank lines, plans 08-08, 08-09 and 08-10 |
| IN-03 | info | Comprehensions and generator expressions in the tests | fixed | 183206d: loops and the `check_name_list_of` fixture, plan 08-10 |
| IN-04 | info | Dict-typed locals without a `Map` suffix, and an inconsistent exception name | fixed | 0aee85e: shape suffixes and `e`, plan 08-10 |
| IN-05 | info | Public functions without type hints | fixed | 0aee85e: `ModuleType` and `object` hints, plan 08-10 |
| IN-06 | info | `managed_settings_result` reports a missing or unreadable file as "does not parse as JSON" | fixed | ca96830, dc579a7: `is missing` and `is not valid JSON`, as in the Cursor check, plan 08-10 |
| IN-07 | info | A test name and a constant hard-code the check counts | fixed | 6fe06ee: the counts test no longer names the numbers, plan 08-09 |
| IN-08 | info | Host scripts: leftover state and a predictable shared folder | deferred | The bash host checks are rewritten in Python in Phase 10 (HOST-01, HOST-05), where per-check clean state and the certificate folder are best handled; (b) is harmless on macOS, where `TMPDIR` is per user; tracked in the 2026-11-14 todo `h34-host-check-hygiene` |
