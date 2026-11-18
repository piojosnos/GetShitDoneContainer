---
created: 2026-11-18
title: Revisit the test suite names in Phase 10 (host versus integration, unit versus component)
area: tests
source: Glossary review in the vocabulary alignment phase (2026-11-18)
---

`tests/selftest/` was renamed to `tests/unit/`. Most of it is unit tests in the strict sense: `init/` and `selfcheck/` import one function or check and call it in-process. `sbx/` is not: each harness runs a whole `bin/sbx-*` script as a process against the stand-in docker and asserts on its exit code, output and files. That is a component test.

The user chose to keep one `tests/unit/` suite for now, with a line in `tests/README.md` saying what `sbx/` does.

Reassess when Phase 10 (host side to Python) rewrites the `bin/` commands and removes the stand-in docker. The `sbx/` harnesses are rewritten or dropped there anyway. At that point decide:

- whether the new tests for the Python host commands are plain unit tests (call functions in-process), so `tests/unit/` stays accurate; or
- whether some still run a whole command as a process with a faked dependency, and earn a `tests/component/` suite next to `tests/unit/`, `tests/guard/` and `tests/host/`.

Also in Phase 10, revisit the name of the host tests. `tests/host/` runs the real images on real Docker, so "integration" is the standard term and pairs with `tests/unit/`; the recommendation is `tests/integration/`. But "host" carries a fact the user values: these tests run only on the host, never in the dev sandbox. The user wants to balance the two then, against the state of the code at that point, rather than decide now. The Python rewrite replaces every bash host test and its runner anyway, so whatever is chosen costs little there:

- the suite directory (`tests/host/` or `tests/integration/`);
- the runner in place of `host-test.sh`, its log in place of `host-test.log`, `tests/host-checklist.md` and the H-nn IDs;
- if the name becomes "integration", the docs keep the fact that "host" carried.

Update `GLOSSARY.md` and `tests/README.md` with the outcome of both.
