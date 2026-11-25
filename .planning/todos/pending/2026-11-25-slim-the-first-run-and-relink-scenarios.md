---
created: 2026-11-25
title: Slim the first-run and relink scenarios without losing coverage of our own code
area: tests
source: PR #63 review thread on tests/integration/test_first_run_and_relink.py
---

File: `tests/integration/test_first_run_and_relink.py` (518 lines, two scenarios).

`test_first_run_refuses_then_inits_from_the_clone` has 11 steps across four jobs: init gating and links, the clone command, the agent wrapper and PATH, and GSD sync. `test_relink_after_a_pull` has 6 steps. Three steps look like tests of someone else's code:

| Step | Scenario | What it really tests |
|---|---|---|
| a push reaches the origin | first run | git push |
| an edit on the host is live | relink | the bind mount and symlink resolution |
| a pull in the sandbox is live | relink | the same |

Suggested change:

1. Drop those three steps, and the second clone and push plumbing only they use.
2. Move the wrapper, PATH and GSD-sync steps (off the PATH, starts after init, a login shell in a session finds the agents dir, GSD is synced at the pin) into the shared-sandbox scenario in `tests/integration/test_init_and_selfcheck.py`, which is already running with init done. No extra sandbox start.
3. First run keeps init gating, the clone command and the links; relink keeps plant, relink and keep.

Condition (from the review): do it only if no coverage of our own code is lost. Before dropping a step, check that nothing ours is covered only there (for example that the clone is a normal repo the user can push from, which `bp-update-practice` relies on). Moved steps keep their assertions unchanged. Needs a `./host-test.sh` run.
