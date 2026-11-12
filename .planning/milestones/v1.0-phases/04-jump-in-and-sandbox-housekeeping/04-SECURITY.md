---
phase: "04"
slug: "jump-in-and-sandbox-housekeeping"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-11-08"
---

# Phase 04: Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| command line to sbx-shell and sbx-rm | the typed name becomes a registry path, a container name, a Compose project and the `-w` folder | sandbox name |
| registry file to the scripts | the entry decides which folder a start mounts; SBX_DIR goes to Compose, never read as a folder | host paths |
| Mac terminal to the container | the interactive exec gives the container's bash the user's terminal | terminal input and output |
| registry folder and Docker to sbx-list | file names, SBX_DIR values and container states decide what the user believes | sandbox names, paths, states |
| bin/ to the user's data | sbx-rm is the one script allowed to take a sandbox down and delete a file | registry entry |
| docs to the user's hands | the user copies commands from SANDBOX.md into the Mac shell | shell commands |
| test code to the user's Mac | self-tests, H-31 to H-33 and the helper run next to the real registry, sandboxes and Docker | test registry, test login (secret) |
| dev sandbox to GitHub | a push publishes the code branch; only the user approves it | repo content |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-04-01 | Tampering | a name such as `../x` building a path, container name or `-w` folder | high | mitigate | `check_name` runs first: `bin/sbx-shell:29`, `bin/sbx-rm:197`, `bin/sbx-list:103`; self-test cases in `tests/selftest/sbx/shell.sh` | closed |
| T-04-02 | Spoofing | entering a container that is not this registered sandbox | medium | mitigate | `read_registry_entry` runs before the running check (`bin/sbx-shell:30`); the container is always `sbx-NAME` (`bin/sbx-shell:21`) | closed |
| T-04-03 | Denial of service | entering recreates or restarts a running sandbox | medium | mitigate | `bin/sbx-shell:32-36`: `bring_up_sandbox` only when not running, else the exec alone; H-31 compares container id and start time | closed |
| T-04-04 | Elevation of privilege | a registry value turned into code or a mount of the Mac home | high | mitigate | unchanged reader; `bin/sbx-lib.sh:119` reads the entry as text, never as code | closed |
| T-04-05 | Information disclosure | terminal escape sequences from the container's bash | low | accept | see Accepted Risks | closed |
| T-04-06 | Tampering | sbx-shell tests reaching the real registry, Docker or sandboxes | high | mitigate | refusing docker stand-in and work-folder registry in `tests/selftest/sbx/shell.sh`; `sbx_test_setup` and only sbx-hosttest in `tests/host/h31-sbx-shell.sh` | closed |
| T-04-07 | Spoofing | a failed `docker ps` shown as an empty list | medium | mitigate | `bin/sbx-list:28-29` errors and exits with no table; self-test case plus mutant | closed |
| T-04-08 | Tampering | sbx-list changing state while it looks | medium | mitigate | its only docker calls are `ps` and `inspect` (grep: no compose, exec, rm, stop or down); guard rule `host_scripts_keep_sandbox_data` covers it | closed |
| T-04-09 | Spoofing | a container whose name only starts like a registered name | low | mitigate | exact match `[ "$containerName" = "sbx-$1" ]` at `bin/sbx-list:59`; adjacency case plus prefix-match mutant | closed |
| T-04-10 | Spoofing | escape sequences in a registry file name or SBX_DIR | low | accept | see Accepted Risks | closed |
| T-04-11 | Information disclosure | old-layout `cc_` or other containers listed or touched | low | mitigate | `--filter label=sbx.name` at `bin/sbx-list:28`; H-32 asserts no `cc_` line | closed |
| T-04-12 | Tampering | sbx-list tests reaching the real registry or Docker | high | mitigate | refusing stand-in in `tests/selftest/sbx/list.sh`; `sbx_test_setup` in `tests/host/h32-sbx-list.sh` | closed |
| T-04-13 | Tampering | data loss through a volume take-down, image removal or folder delete | high | mitigate | `bin/sbx-rm:132` runs a plain `run_compose NAME down`; the `--unregister` path for a broken entry removes only the container by name (`bin/sbx-rm:168`, no `-v`); the guard at `tests/guard/isolation.sh:55-62` refuses `-v`, `--volumes`, `--rmi`, `--remove-orphans`, options after down and any other delete; H-33 compares sentinels, volumes and images | closed |
| T-04-14 | Tampering | a name such as `../x` reaching another file or project | high | mitigate | `check_name` at `bin/sbx-rm:197` before any read or delete; the delete operand is `"$entryFile"` after `--` (`bin/sbx-rm:180`), pinned by the guard | closed |
| T-04-15 | Repudiation | the entry deleted although the down failed | medium | mitigate | `bin/sbx-rm:132-133` stops with "the registry entry stays" on a failed down; the same for a failed container remove (`:168-169`); self-test with a failing compose plus mutant | closed |
| T-04-16 | Elevation of privilege | the sbx-rm guard exemption widened, or another bin/ script gaining a delete | medium | mitigate | `tests/guard/isolation.sh:43-55`: a missing sbx-rm fails, every other bin/ file keeps the broad rule; planted cases in `tests/selftest/guard/sandbox-rules.sh` | closed |
| T-04-17 | Tampering | a registry entry that is a symlink | low | accept | see Accepted Risks | closed |
| T-04-18 | Tampering | sbx-rm tests acting on the user's sandboxes, volumes or registry | high | mitigate | `sbx_test_setup` and only Compose project sbx-hosttest in `tests/host/h33-sbx-rm.sh`; refusing stand-in in `tests/selftest/sbx/rm.sh` | closed |
| T-04-19 | Tampering | a documented command that removes volumes or images or deletes a folder | medium | mitigate | grep of `SANDBOX.md` finds no `down -v`, `--volumes`, `--rmi` or `rm -rf` | closed |
| T-04-20 | Information disclosure | planning IDs or internal notes in the user docs | low | mitigate | scan of every file changed on `feat/sbx-shell-list-rm` finds only the public `H-xx` host-check IDs | closed |
| T-04-21 | Tampering | README.md or the old layout edited | low | mitigate | `git diff --quiet main -- README.md ClaudeCode OpenCode` is clean; guard rule `old_layout_untouched` | closed |
| T-04-22 | Repudiation | an unreviewed push, PR or merge of the code branch | medium | mitigate | `feat/sbx-shell-list-rm` has no upstream; `gh pr list --head feat/sbx-shell-list-rm --state all` is empty | closed |
| T-04-23 | Information disclosure | planning IDs or planning files on the code branch | low | mitigate | same scan as T-04-20; 04-05 SUMMARY records the branch path check | closed |
| T-04-24 | Information disclosure | the helper's real Claude login left in the run folder | medium | mitigate | the printed cleanup removes the run folder; 04-05 SUMMARY records that it ran | closed |
| T-04-25 | Tampering | the optional real-use step removing a real sandbox | low | accept | see Accepted Risks | closed |
| T-04-SC | Tampering | npm/pip/cargo installs | high | mitigate | no package added in this phase; host-test.sh's pin digests step passed (04-05 SUMMARY) | closed |

*Status: open · closed · open (below high threshold, non-blocking)*
*Severity: critical > high > medium > low; only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-04-01 | T-04-05 | inherent to any interactive shell, the same as the documented raw `docker exec -it`; the agent already runs in that terminal through sbx-claude | plan 04-01 threat model | 2026-11-08 |
| AR-04-02 | T-04-10 | the registry lives outside every sandbox mount, so only the user writes it; sbx-add refuses a line break in a path | plan 04-02 threat model | 2026-11-08 |
| AR-04-03 | T-04-17 | rm deletes the link, never its target; the registry folder is the user's own, outside every sandbox mount | plan 04-03 threat model | 2026-11-08 |
| AR-04-04 | T-04-25 | the step names only `try-sbx`, which it registers itself; sbx-rm never touches a folder, so a wrong name loses no file | plan 04-05 threat model | 2026-11-08 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-08 | 26 | 26 | 0 | /gsd-secure-phase (L1 grep-depth; plan-time register, auditor not needed) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-08
