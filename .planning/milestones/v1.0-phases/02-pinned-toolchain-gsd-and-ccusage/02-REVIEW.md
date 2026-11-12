---
phase: 02-pinned-toolchain-gsd-and-ccusage
reviewed: 2026-10-09T00:00:00Z
depth: standard
files_reviewed: 52
files_reviewed_list:
  - .dockerignore
  - SANDBOX.md
  - base/Dockerfile
  - build.sh
  - claude/Dockerfile
  - claude/start.d/05-gsd
  - clean.sh
  - compose.yml
  - tests/guard/bundle-wiring.sh
  - tests/guard/host-tests.sh
  - tests/guard/isolation.sh
  - tests/guard/lib.sh
  - tests/guard/start.sh
  - tests/guard/supply-chain.sh
  - tests/host-checklist.md
  - tests/host/h12-plain-run-refused-pin-installed.sh
  - tests/host/h13-env-and-no-self-update.sh
  - tests/host/h14-bundle-in-image.sh
  - tests/host/h16-sync-refreshes-and-spares.sh
  - tests/host/h17-start-offline-and-failing-hook.sh
  - tests/host/h22-toolchain-in-base.sh
  - tests/host/h23-caches-survive-recreate.sh
  - tests/host/h24-ccusage-reports-usage.sh
  - tests/host/h25-images-match-versions.sh
  - tests/host/lib-docker.sh
  - tests/host/lib-sandbox.sh
  - tests/host/manual/h07-login.sh
  - tests/host/manual/h16-gsd-bump.sh
  - tests/host/run-all.sh
  - tests/host/support/toolchain-probe.sh
  - tests/selftest/bundle/claude-probe.sh
  - tests/selftest/entrypoint/gsd-hook.sh
  - tests/selftest/entrypoint/run-all.sh
  - tests/selftest/entrypoint/start-folders.sh
  - tests/selftest/guard/host-rules.sh
  - tests/selftest/guard/sandbox-rules.sh
  - tests/selftest/host/build-wiring.sh
  - tests/selftest/host/h13-env-and-no-self-update.sh
  - tests/selftest/host/h16-sync-refreshes-and-spares.sh
  - tests/selftest/host/h17-start-offline-and-failing-hook.sh
  - tests/selftest/host/h22-toolchain-in-base.sh
  - tests/selftest/host/h23-caches-survive-recreate.sh
  - tests/selftest/host/h24-ccusage-reports-usage.sh
  - tests/selftest/host/h25-images-match-versions.sh
  - tests/selftest/host/lib.sh
  - tests/selftest/host/run-all.sh
  - tests/selftest/host/runner-failures.sh
  - tests/selftest/host/runner-healthy.sh
  - tests/selftest/host/support/fake-docker
  - tests/selftest/host/support/fake-gsd
  - tests/selftest/host/units.sh
  - versions.env
findings:
  critical: 1
  warning: 7
  info: 7
  total: 15
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-10-09
**Depth:** standard
**Files Reviewed:** 52
**Status:** issues_found

## Summary

The shipped build path is sound where it was exercised: `build.sh` is bash 3.2 safe, the Dockerfiles take every version from `versions.env` and fail closed without it, `05-gsd` fails closed on a stuck, failed or wrong-version sync, and `compose.yml` itself has exactly one bind mount, `cap_drop: ALL` and `no-new-privileges`. The Mac and Linux suites passing is consistent with that.

The defects are mostly in what protects those properties from regression, and in two places where a test can pass without proving its claim. I reproduced the guard gaps in a scratch copy of the tree (nothing in the repo was modified):

- `compose.yml` with `privileged: true`, `network_mode: host` and two short-form host bind mounts (`/etc`, `/Users/me`) still passes `tests/guard/isolation.sh` in full (the old-layout rule fails only because the scratch copy has no git history).
- `get-shit-done-cc` planted in `claude/start.d/05-gsd` and in `tests/host/manual/h16-gsd-bump.sh` still passes `no_compromised_gsd_package`.
- A `curl ... \` newline `| sh`, a `bash <(curl ...)` and an unpinned `npm install -g leftpad` all still pass the supply chain rules.

The supply chain of the toolchain downloads (checksums from the same origin as the artifact, floating transitive npm dependencies with root install scripts) is weaker than the digest pins on the base images suggest.

## Critical Issues

### CR-01: The isolation guard cannot see privilege escalation or short-form mounts, and no host check backs it up

**File:** `tests/guard/isolation.sh:26-42`
**Issue:** `runs_without_privileges` only requires that `no-new-privileges:true` and `cap_drop: - ALL` are present. It never checks that nothing undoes them. Reproduced: adding `privileged: true`, `network_mode: host`, `cap_add`, `pid: host` or `security_opt: seccomp=unconfined` to the service leaves every isolation rule green. `exactly_one_mount_and_not_over_home` counts only the long-form line `- type: bind`, and its `^volumes:` check matches only a top-level key, so a short-form mount such as `- /etc:/hostetc:rw` or `- /Users/me:/home/sandbox/host-home` is invisible (also reproduced). No host check compensates for the privilege part: `grep` over `tests/host` finds no inspection of `HostConfig.Privileged`, `CapDrop`, `CapAdd` or `NoNewPrivileges` (H-04 only checks the uid). H-09 does count mounts at runtime, so the mount half has a Mac backstop; the privilege half has none. This guard is the only automated protection of the isolation constraint that is the reason the project exists.
**Fix:** Make the rules negative as well as positive, and cover short syntax.
```bash
runs_without_privileges() {
  [ "$(grep -E '^USER' $BASE | tail -n 1)" = "USER sandbox" ] \
    && [ "$(grep -E '^USER' $CLAUDE | tail -n 1)" = "USER sandbox" ] \
    && grep -Fq 'no-new-privileges:true' $COMPOSE \
    && grep -A1 'cap_drop:' $COMPOSE | grep -Fq -- '- ALL' \
    && nowhere_matches '^[[:space:]]*(privileged|cap_add|devices|pid|ipc|userns_mode|network_mode|cgroup_parent|security_opt: .*unconfined)[[:space:]]*:|(seccomp|apparmor)[=:]unconfined' $COMPOSE
}
```
For mounts, extract the service `volumes:` block with an awk block (as `compose_checks_the_name_before_it_acts` does for the name-check service) and fail when any list item in it does not start with `- type: bind`. Keep it stock bash 3.2. Add a self-test case in `tests/selftest/guard/sandbox-rules.sh` for each planted form, as is done for the other rules. Also consider one host check that reads `docker inspect` `HostConfig.Privileged`, `CapDrop` and `SecurityOpt` of the running test sandbox.

## Warnings

### WR-01: The supply chain guard does not scan the hook that runs GSD and can be evaded by simple rewrites

**File:** `tests/guard/supply-chain.sh:12,19,26,33-148`
**Issue:** Four separate gaps, each reproduced:
1. `no_compromised_gsd_package` scans `$SANDBOX_FILES`, the docs and `tests/host/*.sh` and the selftests, but not `claude/start.d/*` (the hook that runs the GSD installer), `tests/host/manual/*.sh`, `tests/host/support/*`, `claude/managed-settings.json` or `best-practices/`. `get-shit-done-cc` appended to `05-gsd` passes this rule (the unrelated `no_installs_at_container_start` happens to catch `npx` there, but a package name in a Dockerfile-free path or a manual helper is invisible).
2. The rule is negative only. Nothing asserts that the GSD install in `claude/Dockerfile` is `@opengsd/gsd-core@${GSD_CORE_VERSION}` and nothing else.
3. `no_pipe_to_shell_installers` matches one line. `curl -fsSL URL \` newline `    | sh`, `bash <(curl ...)` and `sh -c "$(curl ...)"` pass.
4. `versions_are_pinned` only inspects `ARG` lines. A Dockerfile `RUN npm install -g leftpad` (no version at all) or `@next` passes every supply chain rule, so "every tool is pinned in versions.env" is not actually enforced for the install commands themselves.
**Fix:** Add `claude/start.d/*`, `claude/managed-settings.json`, `tests/host/manual/*.sh` and `tests/host/support/*` to the file list of `no_compromised_gsd_package`. Add a positive rule that every `npm install` in `$DOCKERFILES` ends in a `@"${NAME}"` argument whose ARG is declared, for example `nowhere_matches 'npm install[^&]*[[:space:]]"?[^@"[:space:]-][^@[:space:]]*"?([[:space:]]|$)'` after joining continuation lines (the awk used by `npm_builds_keep_their_cache_out_of_the_mount` already joins them). Run the pipe-to-shell regex over the joined step text from the same awk, and add `<(curl|wget)` and `$(curl|wget` to the pattern.

### WR-02: H-25 can pass its "stops naming the missing pin" assertion without the guard firing

**File:** `tests/host/h25-images-match-versions.sh:90,97`
**Issue:** The assertion greps the bare-build log for the text of the guard message (`CLAUDE_CODE_VERSION is not set; build with ./build.sh`, and for the base build any of `TEMURIN_IMAGE|UV_IMAGE|UBUNTU_IMAGE`). With `--progress=plain`, BuildKit prints the whole `RUN` command, including the `${VAR:?message}` text, in the step header and again in its final `process "/bin/bash -o pipefail -c ..." did not complete successfully` line. So any non-zero exit of that `RUN` (a network error, an npm failure) satisfies the grep, whether or not the guard fired. The same applies to the base build: the error snippet prints the `FROM ${TEMURIN_IMAGE}` lines. The fake docker in `tests/selftest/host/support/fake-docker:823` emits the shell's real error form (`CLAUDE_CODE_VERSION: CLAUDE_CODE_VERSION is not set; ...`), which is exactly the string the real check should require, so the selftest does not expose the gap.
**Fix:** Match the shell's own error, which does not occur in the echoed command text:
```bash
if [ "$claudeStatus" -eq 0 ] || ! grep -Fq 'CLAUDE_CODE_VERSION: CLAUDE_CODE_VERSION is not set' "$claudeLog"; then
```
and for the base build match `base name (${TEMURIN_IMAGE}) should not be blank` style text (`should not be blank`) rather than the bare pin names.

### WR-03: H-23's "real Maven download" can pass without downloading, and resolves an unpinned plugin

**File:** `tests/host/h23-caches-survive-recreate.sh:17,78,98`
**Issue:** The jar path is fixed (`state/m2/repository/junit/junit/4.13.2/...`) and the check never confirms it was absent before the run. In a run folder that already holds the jar (run `h23` alone after `run-all.sh`, which the checklist recommends for a closer look) Maven resolves it locally, exits 0 and writes nothing, so the mount write path that fails with Maven 3.9.12 (`.lastUpdated` tracking file, Input/output error) is never exercised, yet H-23 reports PASS. Separately, `dependency:get` with no plugin version resolves `maven-dependency-plugin` from Central metadata at run time, so the result drifts with plugin releases and needs network for more than the jar.
**Fix:** Use a repository path that is new on every run and pin the plugin:
```bash
mavenRepo="$HOME_M2/repository-$marker"   # inside ~/.m2, so the same mount and link are used
mvn -q org.apache.maven.plugins:maven-dependency-plugin:3.8.1:get -Dartifact=junit:junit:4.13.2 -Dmaven.repo.local=/home/sandbox/.m2/repository-$marker
mavenJar="$RUN/state/m2/repository-$marker/junit/junit/4.13.2/junit-4.13.2.jar"
```
(or add a run-unique artifact property). Add a "jar already present before the download" problem if the path is kept.

### WR-04: `docker compose up -d --wait` returns before the start hooks finish, and SANDBOX.md still promises otherwise

**File:** `SANDBOX.md:91-107,230` (cause: `base/sbx-entrypoint`, `tests/host/lib-sandbox.sh:137-169`)
**Issue:** The entrypoint runs the start hooks, now including the GSD installer with a 300 s limit over the bind mount, before it execs `sleep`. The host harness itself documents that `up --wait` returns first, which is why `wait_for_start_hooks` had to be added. The user-facing text still says "`--wait` reports a container that fails to start instead of returning early" and shows `docker exec ... claude` straight after `up`. Consequences: a failing GSD or bundle hook does not make `up --wait` fail (the user sees a green `up` and an exited container later), and a shell opened during the sync can read a half-synced `state/claude` (settings.json is rewritten by the installer). The window grew from milliseconds (bundle copy) to the installer's runtime in this phase.
**Fix:** Make `--wait` mean "ready". Add a healthcheck to the `sandbox` service in `compose.yml` that is true only once the hooks are done and the command is running:
```yaml
    healthcheck:
      test: ["CMD", "pgrep", "-x", "sleep"]
      interval: 2s
      retries: 90
      start_period: 5s
```
(`procps` is in the base image.) Then `up -d --wait` waits for the sync and fails on a hook that kills the container, and the SANDBOX.md sentence becomes true. If a healthcheck is not wanted, state in SANDBOX.md that `up` returns before the hooks finish and show the `docker logs`/`pgrep -x sleep` wait. Either way `wait_for_start_hooks` can then use `--wait` alone.

### WR-05: Toolchain tarball checksums come from the same origin as the artifact

**File:** `base/Dockerfile:47-48,61-63,80-81`
**Issue:** Node's `SHASUMS256.txt`, gh's `checksums.txt` and Maven's `.sha512` are fetched from the same host, in the same build step, as the archive they verify. That detects corruption, not a compromised or substituted release or CDN: an attacker who can swap the tarball can swap the checksum. The project's own constraint is built on a past package compromise, and the JDK and uv are pinned by digest, so these three are the weak links in an otherwise pinned base. `curl -fsSL` also follows redirects to plain http and has no `--proto`/`--tlsv1.2`.
**Fix:** Record the expected SHA-256 per tool and architecture in `versions.env` (the file reviewed with every bump, as SANDBOX.md already requires "the digest or checksum") and verify against that value, for example `NODE_SHA256_X64=...`, `NODE_SHA256_ARM64=...`, `GH_SHA256_AMD64=...`, `MAVEN_SHA512=...`, with `echo "${NODE_SHA256}  ${f}" | sha256sum -c -`. Alternatively verify the release signatures (Node `SHASUMS256.txt.sig`, Maven `.asc`). Add `--proto '=https' --tlsv1.2` to the curl calls. Extend `versions_are_pinned` to require a matching checksum pin for each downloaded tool.

### WR-06: npm tools are pinned by version only; transitive dependencies float and install scripts run as root

**File:** `claude/Dockerfile:23,38,51`
**Issue:** `npm install -g "@opengsd/gsd-core@X"` and `ccusage@X` pin the top-level version only. There is no lockfile, no recorded `dist.integrity`, and dependency ranges resolve to whatever is newest at build time, so two builds of the same `versions.env` can contain different code (the GSD package even brings a second Claude binary for its SDK). Lifecycle scripts of every transitive package run as root during the build, and the result runs against the mounted project folder. This is the same class of risk as the compromise that motivated the `@opengsd/gsd-core` rule. Only the Claude Code install has any script handling (`--allow-scripts`, see IN-03).
**Fix:** Pin what was reviewed. Options in order of strength: commit a lockfile per tool (for example `claude/npm/gsd-core/package.json` plus `package-lock.json`) and install with `npm ci --prefix /usr/local/lib/...`; or record the registry `dist.integrity` of each pinned tarball in `versions.env` and verify it with `npm view <pkg>@<ver> dist.integrity` before install; and add `--ignore-scripts` for packages that do not need scripts (ccusage ships its binary through an optional dependency and already needs only a `chmod`).

### WR-07: `clean.sh` force-removes any container named `sbx-hosttest` without checking it is the test sandbox

**File:** `clean.sh:43-44`
**Issue:** `docker rm -f sbx-hosttest` and `docker network rm sbx-hosttest_default` run unconditionally under `--yes`. The sandbox name rule allows `hosttest`, so a user's real sandbox with `SBX_NAME=hosttest` has exactly this container and project name and is destroyed (its folder stays, the container does not). The test harness already treats this case carefully (`assert_test_sandbox` in `tests/host/lib-sandbox.sh` requires the `sbx.name` label and a mount named `sbx-hosttest-*`; `run-all.sh` refuses a container without the label), but `clean.sh`, which is new and outside the guard's no-delete rules, does not.
**Fix:** Inspect before removing, and skip with a message otherwise:
```bash
mountSource=$(docker container inspect --format '{{range .Mounts}}{{if eq .Destination "/home/sandbox/workspace"}}{{.Source}}{{end}}{{end}}' sbx-hosttest 2>/dev/null)
case "$(basename "$mountSource")" in
  sbx-hosttest-*) docker rm -f sbx-hosttest ;;
  *) echo "sbx-hosttest does not mount a host-test run folder; left alone" ;;
esac
```
Apply the same test before removing the network.

## Info

### IN-01: `clean.sh` dry run does not show what `--yes` would delete from the image store

**File:** `clean.sh:18-34,66-73`
**Issue:** The dry run lists disk use, containers and run folders, but not the images or build cache `--yes` removes. `docker image prune -a -f` removes every image no container uses on the whole Docker host (other projects' images, and the old layout's images once their containers are removed), and `docker builder prune -a -f` removes the entire cache. The doc says so, but a dry run should show it.
**Fix:** In `show_state`, print `docker image ls` (and `docker images -f dangling=true`) under a "would remove if unused" heading, or print the `docker image prune -a` candidates with `docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}'` filtered against `docker ps -a --format '{{.Image}}'`.

### IN-02: H-24 matches numbers by prefix and has a very weak table assertion

**File:** `tests/host/h24-ccusage-reports-usage.sh:77-80`
**Issue:** `grep -F '"inputTokens": 100'` also matches `"inputTokens": 1000`, and likewise 200 and 300, so a doubled or inflated count of 10x would pass. The table check is the bare string `300`, which matches any output containing those digits (a date, a cost, a count of 1300).
**Fix:** Anchor the value: `grep -Eq '"inputTokens": 100([^0-9]|$)'` and equivalents, and assert a second token in the table output (for example the `2020-01-07` or `Total` row text) next to `300`.

### IN-03: `--allow-scripts` is an unverified npm flag and the ccusage comment promises something no flag enforces

**File:** `claude/Dockerfile:13,23,44-47`
**Issue:** `--allow-scripts=@anthropic-ai/claude-code` is described as allowing "that one package's scripts if npm blocks unlisted ones", but I could not confirm that npm 11 (shipped with Node 24) defines this option; an unknown config key gives an "Unknown cli config" warning today and is slated to become an error in a future npm major. The ccusage comment says optional dependencies "are never skipped", but the command carries no `--include=optional`, so a build environment with `omit=optional` would fail at the `chmod` glob (loudly, which is acceptable, but the comment overstates).
**Fix:** Drop the flag unless it is confirmed against `npm help config` of the pinned Node, or replace it with the supported mechanism. Either add `--include=optional` to the ccusage install or reword the comment to say the glob fails the build if the binary is missing.

### IN-04: The "mount point stays empty" rule ignores `COPY` after the last `RUN`

**File:** `tests/guard/isolation.sh:80-103`
**Issue:** The rule asserts that the emptiness check is in the last `RUN`, to guarantee no later step writes under the mount point. A `COPY ... /home/sandbox/workspace/...` placed after that `RUN` (as `COPY --chmod=644 versions.env` already is, in `claude/Dockerfile:98`) would pass, and only the Mac runtime check H-25 would notice.
**Fix:** Also fail when any `COPY`, `ADD` or `RUN` after the check line names `/home/sandbox/workspace` as a destination.

### IN-05: The attended GSD bump helper leaves the repo and images in the bumped state on failure

**File:** `tests/host/manual/h16-gsd-bump.sh:132-152`
**Issue:** `print_restore_steps` runs only at the end. A failed rebuild or restart (`|| exit 1` on lines 146-147) exits before it, leaving `versions.env` edited and `sbx-claude:local` possibly rebuilt at the new pin, with no hint how to restore. The printed `git checkout -- versions.env` also discards any other uncommitted edit to that file, including a pin the user changed on purpose.
**Fix:** Print the restore steps from an `EXIT` trap once the pin change was detected, and tell the user to set `GSD_CORE_VERSION` back to the recorded `$oldPin` instead of running `git checkout`.

### IN-06: H-16's "hand edit is undone" check passes when the skill file is gone

**File:** `tests/host/h16-sync-refreshes-and-spares.sh:115`
**Issue:** `grep -Fq "h16 hand edit" "$syncedDir/skills/$firstGsdSkill/SKILL.md" 2>/dev/null` reports no problem if the file does not exist, because the redirect hides the missing-file error and `grep` exits non-zero either way. A restart that deletes the GSD skill instead of restoring it would pass this assertion (the version check on `gsd-core/VERSION` is the only other GSD signal).
**Fix:** Require the file to exist first:
```bash
if [ ! -f "$syncedDir/skills/$firstGsdSkill/SKILL.md" ]; then
  add_problem "state/claude/skills/$firstGsdSkill/SKILL.md is missing after the restart"
elif grep -Fq "h16 hand edit" "$syncedDir/skills/$firstGsdSkill/SKILL.md"; then
  add_problem "state/claude/skills/$firstGsdSkill still has the hand edit after the restart"
fi
```

### IN-07: Single-letter variable names in the base Dockerfile

**File:** `base/Dockerfile:46,60`
**Issue:** `f` and `d` break the full-name rule in the project conventions (`resourcePath`, not `p`) and are used several times per step, which makes the checksum lines harder to read. `file` is used for Maven, so the three downloads are also inconsistent with each other.
**Fix:** Use `nodeArchive`, `ghArchiveDir`/`ghArchive` and `mavenArchive` consistently.

---

_Reviewed: 2026-10-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
