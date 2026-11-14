---
created: 2026-11-14
title: H-34 leaves planted state, reuses a shared certificate folder unchecked, and clean.sh finds that folder by a glob
area: tests
source: Phase 8 code review (IN-08)
resolves_phase: 10
---

Three small hygiene gaps in the bash host checks. Phase 10 rewrites those checks in Python, so fix them there instead of in the bash.

(a) `check_claude_sandbox` in `tests/host/h34-selfcheck.sh` plants a git identity and a fake `.credentials.json` in the shared Claude test sandbox and leaves them for the chain checks that run after H-34, so those checks start from non-clean state. Fix: remove the planted files at the end of the check, or state in the header that later checks tolerate them.

(b) `make_test_root_cert` in `tests/host/run-all.sh` reuses an existing `root-ca.pem` in `$TMPDIR/sbx-hosttest-root-ca` without checking who owns the folder. On macOS `TMPDIR` is per user, so it is harmless there; on a shared Linux `/tmp` another user could pre-create the folder with their own certificate. Fix: test `[ -O "$certDir" ]` before reuse and regenerate when it fails.

(c) `clean.sh` removes that certificate folder only because its `sbx-hosttest-*` glob happens to match, and lists it under "Host-test run folders". Fix: name the folder outside the `sbx-hosttest-*` pattern and give it an explicit line in `clean.sh`, so the README's claim does not depend on a glob.
