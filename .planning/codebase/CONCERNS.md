---
last_mapped_commit: 031448ea8249fe34f6bd172818ba1c2807eaed35
last_mapped_at: 2026-11-16
---
# Codebase Concerns

**Analysis Date:** 2026-11-16

## Tech Debt

**Bundle hook atomicity and verification:**
- Issue: The best-practices bundle linking process in `claude/start.d/10-best-practices` is not atomic. Files are processed sequentially; if an error occurs midway (via `set -e`), the start stops with partial state: some skill links created, others missing, and the skill list incomplete.
- Files: `base/bin/sbx-link-bundle:50-111`, `tests/selftest/entrypoint/bundle-hook.sh`
- Impact: A dangling skill link remains in `state/claude/skills` permanently; the next start does not remove unlisted links because the old links were never listed.
- Fix approach: Build the skill list in a temporary file written at the end, and verify the clone directory before making any changes. Create new links first, then remove only the old names no longer in the clone. Reference: `.planning/todos/pending/2026-10-24-bundle-hook-atomic-and-verified.md`
- Resolves: Phase 9 (`sbx-init replaces the start hooks`)

**Silent deletion of user skills in bundle linking:**
- Issue: When a bundle skill and a user's own skill share the same name, the hook silently deletes the user's skill with no warning or backup.
- Files: `base/bin/sbx-link-bundle:109-110`, `claude/start.d/10-best-practices`
- Impact: A user's customized or personal skill folder is removed at every start; `SANDBOX.md` promises user skills are never touched.
- Fix approach: Check whether each target is a symlink before removing it. If a real folder exists with that name, refuse the relink with an error message pointing the user to move it or rename the bundle skill.
- Resolves: Phase 9 (`sbx-init replaces the start hooks`)

**GSD sync leaves root-owned files in state/claude:**
- Issue: After each container start, 313 of 820 files under `state/claude` (in `gsd-core/`, `hooks/`, `scripts/`) are owned by root with mode 644 or 755. The npm installer uses `fs.copyFileSync`, which copies then attempts to give the copy the source's owner. The source is root-owned in the image; on Docker Desktop the chown succeeds via `user.containers.override_stat` attributes.
- Files: `claude/Dockerfile` (GSD installed as root), `state/claude/` (sync destination)
- Impact: No breakage observed; the files are readable, folders stay owned by sandbox, and resyncs replace them. However, sandbox cannot edit files in place.
- Fix approach: Either the sandbox doctor reports these files as expected (Phase 9), or the sync gives them back to the running user after copying (10 lines and a self-test case). Do not change the image's GSD ownership to sandbox; that would let the agent edit GSD, and resync would propagate edits into state.
- Decision made: Handle in Phase 9 (`sbx-init replaces the start hooks`)
- Reference: `.planning/todos/pending/2026-11-08-gsd-sync-leaves-root-owned-files.md`

## Known Bugs

**sbx-claude sleeps 5 seconds even in non-interactive use:**
- Symptoms: Running `sbx-claude -p "..."` or `sbx-claude --version` in a script or pipeline gets a no-clone banner on stderr and a mandatory 5 second delay.
- Files: `claude/bin/sbx-claude:23`
- Trigger: Any use of sbx-claude when the bundle is not linked, including scripted or piped calls.
- Fix approach: Sleep only when stdin and stderr are terminals (both must be a terminal). Check with `[ -t 0 ] && [ -t 2 ]`. H-27 runs with stdin from `/dev/null` so it still sees the warning.
- Resolves: Phase 9 (`sbx-init replaces the start hooks`)
- Reference: `.planning/todos/pending/2026-10-24-sbx-claude-no-wait-when-non-interactive.md`

**sbx-bundle-clone misleading error and unguarded arguments:**
- Symptoms: Any `git clone` failure (no network, dangling symlink, read-only mount, bad URL) prints "A private repo needs sbx-gh-login first," regardless of the real cause. The git error message above it is the actual clue but the hint points at the wrong fix.
- Files: `base/bin/sbx-bundle-clone:22-24`
- Trigger: Running clone when the network is down, the bundle directory has an issue, or any other git error occurs.
- Workaround: Look at the actual git error above the misleading hint; run `git clone -- $URL $DIR` by hand to see the real problem.
- Fix approach: Use `git clone -- "$BUNDLE_REPO_URL" "$SBX_BUNDLE_DIR"` to guard against URLs starting with `-`. Test directory existence with `[ -e "$SBX_BUNDLE_DIR" ] || [ -L "$SBX_BUNDLE_DIR" ]`. Rephrase the error as "cannot clone $URL; if the repo is private, run sbx-gh-login first."
- Resolves: Phase 9 (`sbx-init replaces the start hooks`)
- Reference: `.planning/todos/pending/2026-10-24-bundle-clone-error-hint-and-option-guard.md`

**sbx-gh-login runs device login again when already logged in:**
- Symptoms: A second run of `sbx-gh-login` in the same sandbox starts a fresh device login (generates a new one-time code) instead of noticing the existing session.
- Files: `claude/bin/sbx-gh-login:51`
- Trigger: Run `sbx-gh-login` a second time in a sandbox where you previously logged in.
- Workaround: Press Ctrl-C to stop the second login attempt.
- Fix approach: Check if already logged in with `gh auth status --hostname github.com` before running `gh auth login`. Always run `gh auth setup-git` and the identity questions.
- Resolves: Phase 9 (`sbx-init replaces the start hooks`)
- Reference: `.planning/todos/pending/2026-10-26-sbx-gh-login-skip-when-logged-in.md`

## Security Considerations

**Token exposure when Claude runs with permissions bypassed:**
- Risk: With `sbx-claude --dangerously-skip-permissions`, Claude can read and transmit every token in `state/`: the Claude login (`state/claude/.credentials.json`), the gh token (`state/gh/hosts.yml`, plain text), and `state/git/config`. Deny rules do not help; bash (as the sandbox user) can read any file the sandbox user can read. Claude must be able to read its own login, so that cannot be hidden.
- Files: `state/claude/`, `state/gh/`, `state/git/`
- Current mitigation: A leaked token reaches only the subscriptions and repositories the full gh token permits; it expires only when revoked.
- Recommendations: Implement one of (in priority order):
  - B (docs-only, low cost): Use fine-grained GitHub tokens per sandbox with scoped permissions (one repo, contents and pull requests only) and short expiry. Documented in README recipe; tokens created on github.com.
  - A (larger change): Keep gh tokens out of sandboxes; push and open PRs from the Mac instead. Requires alternate approach to `sbx-bundle-clone` for cloning private repos.
  - C (project-sized): Add outbound network allowlist (Anthropic, GitHub, npm). Stops sending tokens to arbitrary hosts but requires significant infrastructure.
- Reference: `.planning/todos/pending/2026-11-08-limit-token-exposure-in-bypass-mode.md`

## Fragile Areas

**Test hygiene and state isolation:**
- Files: `tests/host/h34-selfcheck.sh`, `tests/host/run-all.sh`, `clean.sh`
- Why fragile: H-34 plants a git identity and fake `.credentials.json` in the shared Claude test sandbox and leaves them; later test checks start from non-clean state. The root certificate folder is reused from `$TMPDIR` without ownership checks (harmless on per-user macOS `/tmp`, but risky on shared Linux `/tmp`). The certificate folder is removed only because its name matches a glob in `clean.sh`, not by explicit cleanup.
- Safe modification: Remove planted state at the end of H-34, or document that later checks tolerate it. Test folder ownership before reuse. Give the certificate folder an explicit name and cleanup line in `clean.sh`.
- Test coverage: H-34 grep for the `no-root-owned-state` FAIL checks only one failure case; another FAIL caused by chown or a changed count passes silently.
- Resolves: Phase 10 (`Host side to Python`)
- Reference: `.planning/todos/pending/2026-11-14-h34-host-check-hygiene.md` and `.planning/todos/pending/2026-11-14-selfcheck-review-follow-ups.md`

**Bundle and image configuration hardcoding:**
- Files: `tests/host/h34-selfcheck.sh`, `base/selfcheck/checks/`
- Why fragile: The self-check runner's error messages hardcode `sbx-base:local` and container names; when a sandbox uses `SBX_IMAGE_TAG=test`, the hints name the wrong images. The hints cannot be made correct without passing the tag into the container at runtime.
- Safe modification: Pass the image tag through Compose as an environment variable and build the image name from it in the selfcheck code. Or add a comment naming the constants the hints assume.
- Resolves: Phase 10 (`Host side to Python`)
- Reference: `.planning/todos/pending/2026-11-14-selfcheck-review-follow-ups.md` (IN-02)

**Selfcheck file readability and error reporting:**
- Files: `base/selfcheck/checks/040_root_owned_state.py`, `claude/selfcheck/`, `cursor/selfcheck/` (the settings and config checks)
- Why fragile: The owner fix hint does not distinguish between unreadable folders owned by sandbox (user can chmod) and root-owned folders (requires Mac chown). Settings and credentials files report parse errors as "not valid JSON" when the real issue is the file cannot be read.
- Safe modification: Keep unreadable sandbox-owned folders out of the report, or give that case its own hint. For file read errors, use the OSError to say the file cannot be read and why; preserve the JSONDecodeError wording for parse failures.
- Resolves: Phase 10 (`Host side to Python`)
- Reference: `.planning/todos/pending/2026-11-14-selfcheck-review-follow-ups.md` (IN-01, IN-03)

## Test Coverage Gaps

**Test redundancy with guard checks:**
- Issue: Some host checks and selftest cases re-prove facts the guard already verifies, adding cost without catching new failures. Example: H-34 ran the owner fix round trip on every Mac run (about 100 lines and a throwaway root container) to prove a fixed recipe that pytest already pins; it was removed in review.
- Files: `tests/host/`, `tests/selftest/`
- Fix approach: At the end of each milestone, audit every host check and selftest case. For each, ask what failure it catches today that nothing cheaper (pytest, the guard) catches. Remove or shrink tests that only re-prove settled facts, test a library instead of our code, or duplicate another check.
- Resolves: Ongoing; documented in `.planning/todos/pending/2026-11-15-recurring-test-audit.md`

**Unnamed temporary containers left running:**
- Issue: `root_run` in `tests/host/h34-selfcheck.sh` starts an unnamed `docker run --rm` container; when the timeout kills the docker CLI the container keeps running because it has the test sandbox's volumes attached.
- Files: `tests/host/h34-selfcheck.sh`
- Impact: Orphaned test containers accumulate if a host check times out.
- Fix approach: Name the container and call `docker rm -f` on that name in cleanup. Or document the leftover in the H-34 failure notes of `tests/host-checklist.md`.
- Resolves: Phase 10 (`Host side to Python`)
- Reference: `.planning/todos/pending/2026-11-14-selfcheck-review-follow-ups.md` (IN-05)

## Missing Critical Features

**Explicit bundle initialization user command:**
- Problem: Containers run start hooks that initialize the bundle on first start. This couples container startup to GSD and bundle state; if either initialization fails or hangs, the container never becomes usable. The user has no signal that initialization is needed or complete.
- Blocks: Clean separation of container lifecycle from tooling setup; atomic GSD and bundle sync; clear user feedback on initialization.
- Fix approach: Phase 9 (`sbx-init replaces the start hooks`) removes all hooks from the entrypoint. The user runs `sbx-init` explicitly to sync GSD and link the bundle; each step prints OK or FAIL with no waits or polls. A second run when all is done is a quick no-op.
- Status: Planned for Phase 9

**Python host side with JSON registry:**
- Problem: Every Mac command and test is bash. Bash scripts are fragile across BSD and GNU tools; the host tests duplicate code; adding a new sandbox requires manual list maintenance.
- Blocks: Scalable Mac tooling; shared test harness; correct behavior on macOS and Linux test runners.
- Fix approach: Phase 10 (`Host side to Python`) rewrites every `sbx-*` command, `build.sh` and `./host-test.sh` in Python run through `uv`. A single JSON registry file per sandbox (`~/.config/sbx/sandboxes/NAME.json`) holds path and agent; all commands read from it. Test harness is written once; small diffs cover agent differences.
- Status: Planned for Phase 10

**Mac run validation glue script:**
- Problem: Every Mac checkpoint asks the user to paste boilerplate by hand: restore exec bits, show git status, record image IDs, run host tests, record IDs and containers again, grep logs.
- Blocks: Fast and reliable Mac gate process.
- Fix approach: A small glue script runs those steps in one line. It calls helpers (one exec-bit restorer that works in any git repo, `host-test.sh`, image/container snapshot tools). Default run does the common checks; `--grep` and `--` arguments customize it.
- Status: Planned as separate quick task after Phase 8
- Reference: `.planning/todos/pending/2026-11-14-mac-run-glue-script.md`

## Scaling Limits

**Docker Desktop file ownership semantics:**
- Current capacity: Containers run as non-root (uid 1000); host files mounted with bind mounts.
- Limit: Docker Desktop on macOS maps file ownership through `user.containers.override_stat`. A file copied by root-owned code in the container can appear root-owned on the Mac, and `chown` from inside the container can change ownership on the Mac. This is not true on Linux or on containers run with proper namespace mappings.
- Scaling path: When tests or sandboxes move to non-Docker Desktop environments, the GSD sync and file ownership model must account for uid mismatch and stricter ownership enforcement.

## Dependencies at Risk

**Fixed npm package versions without security scanning:**
- Risk: `@opengsd/gsd-core` and other npm packages are pinned by digest in `versions.env` but not scanned for security vulnerabilities. If a digest remains pinned after a CVE is published, the fix is not picked up until a manual digest update.
- Impact: Security fixes in dependencies are not automatically applied.
- Migration plan: Phase 10 adds Python-based tooling; if npm scanning is needed, it can be added to the build and CI pipeline. For now, rely on GitHub's Dependabot scanning for this repo and periodic manual digest updates.

## Performance Bottlenecks

**Image layer count and cache invalidation:**
- Problem: Every `RUN` command in the Dockerfile creates a layer. Build steps that are unlikely to change (system packages, static tools) sit below steps that change frequently (package versions, script updates). A single version change in `versions.env` invalidates the entire cache.
- Files: `base/Dockerfile`, `claude/Dockerfile`, `cursor/Dockerfile`
- Cause: Sequential chained RUN commands without layer grouping by change frequency.
- Improvement path: Reorganize Dockerfile RUN statements to place stable, large caches early and volatile, small updates late. Use BuildKit cache mounts for package manager caches. Consider multi-stage builds to keep build tools out of the final image.
- Priority: Low; builds run on developer's Mac and once per test run; the current 2-3 minute build time is acceptable.

## Documentation Gaps

**MIGRATION.md follow-ups from EmailIntel move:**
- Issue: Two migration edge cases were handled by hand during Phase 5; they should be documented in MIGRATION.md for the next user.
- Files: `MIGRATION.md`
- Gaps:
  - Projects with files outside the code folder that the code uses through relative paths (like EmailIntel's `docs/`, `emails/`, `storage/` beside `project/`). The whole old home must become the project folder with careful cleanup.
  - Old homes without `.gitconfig` bring no git name or email; the new sandbox must set them.
- Fix approach: Add a "project layout" case to MIGRATION.md with the full procedure. Add one line for the git config case.
- Reference: `.planning/todos/pending/2026-11-08-migration-recipe-follow-ups.md`

---

*Concerns audit: 2026-11-16*
