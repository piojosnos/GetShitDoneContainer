---
created: 2026-11-14
title: Self-check review follow-ups: the unreadable folder hint, the hardcoded image tag, the settings read error wording, and two H-34 host check gaps
area: tests
source: Phase 8 code review, second pass (IN-01 to IN-05)
resolves_phase: 10
---

Five small gaps from the second review of Phase 8, deferred. Phase 10 rewrites the host checks in Python, so (d) and (e) land there, and (a) to (c) are self-check code that fits the same pass.

(a) IN-01: `scan_owned_state` reports any folder it cannot open, whoever owns it, and since the mode 444 fix both failure points use `mark_unreadable_folder`, so one edit covers them. For an unreadable folder owned by the sandbox user the Mac chown changes nothing and the detail does not tell the cases apart.
Fix: keep such folders out of the report (the sandbox can chmod them), or give that case its own hint, or say "or make readable" in the single hint. Files: `base/selfcheck/shared_checks.py` and its test.

(b) IN-02: the owner fix names `sbx-base:local` and `sbx-NAME`; a sandbox started with `SBX_IMAGE_TAG=test` runs `sbx-base:test`, and `sbx-NAME` repeats `container_name` in `compose.yml` and `CONTAINER` in `tests/host/lib.sh`.
Fix: pass the tag into the container through Compose and build the image name from it, or comment the constant that the hint assumes the default tag.

(c) IN-03: `managed_settings_result` in `claude/selfcheck/claude.py` and `self_update_result` in `cursor/selfcheck/cursor.py` report an unreadable file as "is not valid JSON".
Fix: `ValueError` keeps that wording, `OSError` says the file cannot be read and why; update the test that pins the old wording.

(d) IN-04: the H-34 "after" run in `tests/host/h34-selfcheck.sh` greps only for the `no-root-owned-state` FAIL, so another FAIL caused by the chown or a changed count passes silently.
Fix: call `check_selfcheck_output "owner fix, after" "$afterFile" "$expectedClaudeCount"` instead of the grep.

(e) IN-05: `root_run` in `tests/host/h34-selfcheck.sh` starts an unnamed `docker run --rm` container; when the timeout kills the docker CLI the container keeps running with the test sandbox's volumes.
Fix: give it a name and `docker rm -f` that name in `remove_planted_folder`, or note the leftover in the H-34 failure notes of `tests/host-checklist.md`.
