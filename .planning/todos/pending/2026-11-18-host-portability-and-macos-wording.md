---
created: 2026-11-18
title: Understand what makes the sandbox host-specific, and whether "macOS" wording can go
area: portability
source: Glossary review in the vocabulary alignment phase (2026-11-18)
---

The glossary says "the host" everywhere, and keeps "macOS" (phrased "on a macOS host") only where a fact holds only there:

- the BSD tools and bash 3.2 portability rules (no `sed -i`, no `readlink -f`);
- the Keychain;
- the case-insensitive default disk;
- the `user.containers.override_stat` attribute (Docker Desktop on macOS);
- the `### Mac OS ###` header in `.gitignore` (third-party template text).

Revisit after OpenCode support (Phase 10.2) and the other cleanups. The user wants to understand the implications of making the sandbox portable across hosts: which of these facts the code still depends on once the host side is Python (Phase 10 removes most of the BSD shell concerns), what a Linux or Windows host would need, and whether the code can then drop host-specific language entirely, keeping it only in user documentation.

Update `GLOSSARY.md` with the outcome.
