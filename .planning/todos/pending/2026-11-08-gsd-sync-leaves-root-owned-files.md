---
created: 2026-11-08
title: The GSD sync leaves files owned by root in state/claude at every start
area: claude
source: sanity check after moving this repo's sandbox (conversation)
---

After each start, 313 of the 820 files the GSD sync writes under `state/claude` (`gsd-core/`, `hooks/`, `scripts/`) show owner `root`, mode 644 or 755. Everything in the container runs as `sandbox` (uid 1000). A `chown` of `state/claude` to 1000 followed by `sbx-stop` and `sbx-start` brought the same 313 back, with the restart's timestamp.

Effect today: none seen. The files are readable, their folders stay owned by `sandbox`, so the next sync replaces them; it succeeded on the restart. `sandbox` cannot edit them in place.

Cause (the installer running as `sandbox` and the chown behaviour are tested; the copy step is inferred from the code, not traced): for these files the installer uses Node's `fs.copyFileSync`, which copies and then tries to give the copy the source's owner (root: the image's `@opengsd/gsd-core` is installed as root). On a normal Linux disk that `chown` fails quietly; on Docker Desktop's file sharing ownership is only the `user.containers.override_stat` attribute, so it succeeds. A test showed `sandbox` can set a file's owner to root and back there. The root-owned `state/claude/sessions` seen after the first migration is likely the same mechanism.

Harmless: root ownership is no protection (only part of the files, the folders belong to `sandbox`, and `sandbox` can change the owner back). What keeps GSD as the image has it is the resync at every start.

Decision (2026-11-08): leave it for now; handle it in phase 5.1 (sandbox doctor). Either the doctor reports these files as expected, or `05-gsd` gives them back to the running user after the sync (about ten lines and a self-test case). Do not make the image's GSD package owned by `sandbox`: the agent could then edit it, and the next start would sync those edits into `state/claude`.
