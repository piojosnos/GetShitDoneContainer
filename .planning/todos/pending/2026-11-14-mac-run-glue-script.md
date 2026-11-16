---
created: 2026-11-14
title: One-line glue script for the Mac validation runs
area: tooling
source: Phase 8 Mac gate (user request)
---

Every Mac checkpoint asks the user to paste the same blocks by hand: restore the exec bits the sandbox edits drop, show `git status --short`, record the local image IDs, run `./host-test.sh`, record the image IDs and leftover test containers again, and grep `host-test.log`. A small glue script runs those in one line.

Scope:
- Glue only: it calls the steps and appends their output to a gate log. It judges nothing; the user and Claude still read the log.
- Default run: exec-bit restore, `git status --short`, image IDs before, `./host-test.sh`, image IDs and `sbx-hosttest-*` containers after.
- Exceptional cases through options, not new code each time: for example `--grep PATTERN` appends matching `host-test.log` lines, and arguments after `--` go to `host-test.sh`.
- Plain bash, thin, BSD and macOS portable.
- The exec-bit restore is its own standalone script, not a step inside the glue script: the glue script calls it. It must work in any git repo (no project paths or names), so the user can copy it to another project that has the same problem. It restores the exec bit on every file `git diff --summary` reports as `mode change 100755 => 100644`, then prints `git status --short`.

Cost: one more script to keep in step with `host-test.sh`; the README, the test checklist and the Mac checkpoint text of future plans point to it.

Do it as its own quick task on a separate branch after Phase 8 closes.
