---
created: 2026-11-24
title: Give our practices a common name prefix and an experimental marker
area: best-practices
source: User request during Phase 10.1 execution (2026-11-24)
---

Do this after Phase 10.1 and before Phase 10.1.1 links the generated output into sandboxes, so the linker and its tests use the final names.

1. Common prefix: every rule and skill master in the best-practices repo gets one short prefix (for example `bp-`), so our practices are easy to find next to GSD skills (`gsd-*`) and an agent's built-in ones. A skill's folder name and its `name` key change together; the generated output follows on the next `practices.generate`.
2. Experimental marker: a second prefix marks a practice as experimental (for example `bpx-` next to `bp-`). Promoting it to production is a rename. A name marker shows in the agent's skill list and needs no change to the strict frontmatter (rules allow only `paths`, skills only `name` and `description`).

Update the `update-practice` skill, the README and the reader tests (a master without the prefix could be refused) in the same change.
