---
created: 2026-11-18
title: Reassess whether tests/unit/ needs a separate component suite
area: tests
source: Glossary review in the vocabulary alignment phase (2026-11-18)
---

`tests/selftest/` is being renamed to `tests/unit/`. Most of it is unit tests in the strict sense: `init/` and `selfcheck/` import one function or check and call it in-process. `sbx/` is not: each harness runs a whole `bin/sbx-*` script as a process against the stand-in docker and asserts on its exit code, output and files. That is a component test.

The user chose to keep one `tests/unit/` suite for now, with a line in `tests/README.md` saying what `sbx/` does.

Reassess when Phase 10 (host side to Python) rewrites the `bin/` commands and removes the stand-in docker. The `sbx/` harnesses are rewritten or dropped there anyway. At that point decide:

- whether the new tests for the Python host commands are plain unit tests (call functions in-process), so `tests/unit/` stays accurate; or
- whether some still run a whole command as a process with a faked dependency, and earn a `tests/component/` suite next to `tests/unit/`, `tests/guard/` and `tests/host/`.

Update `GLOSSARY.md` and `tests/README.md` with the outcome.
