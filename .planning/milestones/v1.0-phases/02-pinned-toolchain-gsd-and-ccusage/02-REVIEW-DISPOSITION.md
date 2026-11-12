---
phase: 02-pinned-toolchain-gsd-and-ccusage
source: 02-REVIEW.md
updated: 2026-10-09
---

# Phase 2 review disposition

One row per finding in 02-REVIEW.md. Status is open until the user decides. 2026-10-09: the user approved fixing every other finding now.

| ID | Severity | Finding | Status |
|---|---|---|---|
| CR-01 | critical | The isolation guard cannot see privilege escalation or short-form mounts, and no host check backs it up | fixed: 39da0bc |
| WR-01 | warning | The supply chain guard does not scan the hook that runs GSD and can be evaded by simple rewrites | fixed: 7a763dc |
| WR-02 | warning | H-25 can pass its "stops naming the missing pin" assertion without the guard firing | fixed: f1251e1 |
| WR-03 | warning | H-23's "real Maven download" can pass without downloading, and resolves an unpinned plugin | fixed: 221f2e8 |
| WR-04 | warning | `docker compose up -d --wait` returns before the start hooks finish, and SANDBOX.md still promises otherwise | deferred: Phase 7 (Start readiness); SANDBOX.md sentence corrected in a420956 |
| WR-05 | warning | Toolchain tarball checksums come from the same origin as the artifact | accepted: decided in 02-PINS.md (checksums share an origin) |
| WR-06 | warning | npm tools are pinned by version only; transitive dependencies float and install scripts run as root | accepted: recorded in 02-PINS.md reviewer notes (transitive versions float) |
| WR-07 | warning | `clean.sh` force-removes any container named `sbx-hosttest` without checking it is the test sandbox | fixed: 261e1a6 |
| IN-01 | info | `clean.sh` dry run does not show what `--yes` would delete from the image store | fixed: 261e1a6 |
| IN-02 | info | H-24 matches numbers by prefix and has a very weak table assertion | fixed: 8297f4f |
| IN-03 | info | `--allow-scripts` is an unverified npm flag and the ccusage comment promises something no flag enforces | fixed: 552dc25 (--allow-scripts is a real npm option; ccusage comment corrected) |
| IN-04 | info | The "mount point stays empty" rule ignores `COPY` after the last `RUN` | fixed: 35d2c43 |
| IN-05 | info | The attended GSD bump helper leaves the repo and images in the bumped state on failure | fixed: 3be080f |
| IN-06 | info | H-16's "hand edit is undone" check passes when the skill file is gone | fixed: 914e910 |
| IN-07 | info | Single-letter variable names in the base Dockerfile | fixed: 8de98bc |
