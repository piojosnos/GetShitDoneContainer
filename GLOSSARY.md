# Glossary

Code, tests and docs use one term per concept, listed here. Review keeps it that way; no automatic check does.

## How a term is picked

1. An industry-standard term always wins.
2. Otherwise the name users type or see (a command, a check or a step name) wins, and the prose follows it.

## The best-practices repo and the host

| Concept | Term | Retired (where it was used) | Kept on purpose (why) |
|---|---|---|---|
| The user's repo of standing rules and skills, and this sandbox's clone of it | best-practices repo (the GitHub repo that `BEST_PRACTICES_REPO_URL` names); best-practices clone (`/home/sandbox/workspace/best-practices`, `$SBX_DIR/best-practices`) | "bundle", "the bundle", "bundle repo", "bundle skill" (the README best-practices section, `prompts/consolidate-memories.md`, `MIGRATION.md`, the clone command, its environment variable and pin, the selfcheck module and check names, test and host check file names) | "CA bundle" and "system bundle" for `/etc/ssl/certs/ca-certificates.crt` and the check `extra-ca-system-bundle` (industry term); "bundled with Node.js" (plain English) |
| The machine that runs Docker and the `sbx-*` commands | the host | "the Mac", "Mac" as a stand-in for the host, "your Mac user", "Mac modes" (README, `bin/` messages and comments, selfcheck hints, `host-test.sh` step names, host checks) | "macOS" (or "Docker Desktop") where a fact holds only there: BSD tools and bash 3.2, the Keychain, the case-insensitive default disk, the `user.containers.override_stat` attribute; the `### Mac OS ###` header in `.gitignore` (third-party template text) |
