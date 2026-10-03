# Host checklist (H-00..H-13)

The manual test plan for the sbx sandbox: checks that can only be proven on your Mac, because Docker does not run in the dev sandbox.

- **IDs:** each check has an ID, H-00 to H-13 (H for host), so results can be reported by ID ("H-10 failed").
- **When:** once after building a new version of the images or `compose.yml`.
- **Setup and daily use:** see [`SANDBOX.md`](../SANDBOX.md).
- Commands run from the repo root.

How to run it:

- Run the setup block, then each check top to bottom.
- Each check has the commands to paste and a pass condition.
- Write each outcome into "Record your results" below.

What each check proves:

| Proves | Checks |
|---|---|
| Builds natively; the Claude image sits on the base | H-00, H-01, H-02, H-03 |
| Non-root user; workspace and home layout; git works | H-04, H-05, H-06 |
| Claude login survives recreate and rebuild | H-07, H-09 |
| Shell history persists | H-08 |
| Nothing deletes code or state | H-09, H-11 |
| Safety layers: missing folder refused, start check, pinned Claude with updates off | H-10, H-12, H-13 |

## Setup (once)

Replace `/Users/you/sbx-demo` with a folder on your Mac that Docker Desktop can share.

```bash
cd /path/to/this/repo
docker compose version
docker build -t sbx-base:local base/
docker build -t sbx-claude:local claude/
export SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo
mkdir -p "$SBX_DIR/$SBX_NAME" "$SBX_DIR/state"
for d in "$SBX_NAME" state; do [ -d "$SBX_DIR/$d" ] || echo "MISSING: $SBX_DIR/$d"; done
docker compose config | head -3
docker compose up -d --wait
```

- The `for` loop must print nothing.
- The container is named `sbx-demo`. Every command below assumes `SBX_NAME=demo`.

## H-00: Compose v2

```bash
docker compose version
```

Pass: prints a Compose v2 version. Write down that version and the Docker Desktop version (Docker Desktop, About).

## H-01: native arm64

```bash
docker image inspect sbx-base:local sbx-claude:local --format '{{.Architecture}}'
docker exec sbx-demo uname -m
```

Pass:

- `arm64` twice, then `aarch64`.
- No "requested image's platform ... does not match" warning during the builds or `up`.

## H-02: the Claude image is built on the base

```bash
docker history sbx-claude:local | head -30
grep '^FROM' claude/Dockerfile
```

Pass: the Claude layers sit on top of the base layers, and the only `FROM` line is `FROM ${BASE_IMAGE}`.

## H-03: variable interpolation

```bash
docker compose config | head -3
SBX_NAME=demo docker compose config
```

Pass:

- The first command shows `name: sbx-demo`.
- The second, run where `SBX_DIR` is not exported (a fresh terminal, or prefix it with `env -u SBX_DIR`), fails with the "SBX_DIR is required" message.

## H-04: non-root user

```bash
docker exec sbx-demo id
```

Pass: `uid=1000(sandbox) gid=1000(sandbox)`.

## H-05: workspace and home layout

```bash
docker exec sbx-demo sh -c 'touch x.txt; ls -a /home/sandbox'
ls "$SBX_DIR/demo"
docker exec sbx-demo stat -c '%U %n' /home/sandbox/.local /home/sandbox/.local/state
```

Pass:

- `x.txt` shows up in `$SBX_DIR/demo` on the Mac.
- `ls -a` shows `.bashrc` and `.local`.
- Both `stat` lines start with `sandbox`.

## H-06: git works and the identity persists

```bash
git init "$SBX_DIR/demo"
docker exec sbx-demo git status
docker exec sbx-demo git config --system --get-all safe.directory
docker exec sbx-demo sh -c 'git config --global user.name T && cat $GIT_CONFIG_GLOBAL'
cat "$SBX_DIR/state/git/config"
```

Pass:

- No "dubious ownership" error.
- The system `safe.directory` value is `*`.
- The identity file appears at `$SBX_DIR/state/git/config` on the Mac.

## H-07: Claude login

```bash
docker exec -it sbx-demo claude
```

Log in with a claude.ai account, then `/exit`. Then:

```bash
ls -la "$SBX_DIR/state/claude"
docker exec sbx-demo claude auth status
docker exec sbx-demo sh -c 'ls -a $HOME | grep -c "^\.claude\.json$"'
```

Pass:

- `.claude.json`, `.credentials.json` and `projects/` are in `$SBX_DIR/state/claude` on the Mac.
- `claude auth status` shows `"loggedIn": true`.
- The last command prints `0` (no `~/.claude.json` in the container home).

## H-08: shell history survives recreate

Open a shell, type a marker command, and **leave this first shell open**:

```bash
docker exec -it sbx-demo bash
echo marker-$RANDOM
```

In another terminal, with the same two variables exported, recreate the container:

```bash
docker compose down && docker compose up -d --wait
```

Open a new shell and look for the marker:

```bash
docker exec -it sbx-demo bash
history | grep marker
```

Pass: the marker is in `history`, and `grep marker "$SBX_DIR/state/shell/bash_history"` on the Mac finds it too.

## H-09: login and files survive a clean rebuild, and no volumes exist

```bash
docker compose down
docker build --no-cache -t sbx-base:local base/ && docker build --no-cache -t sbx-claude:local claude/
docker compose up -d --wait
docker exec sbx-demo claude auth status
docker exec -it sbx-demo claude --continue
ls -R "$SBX_DIR" | head
docker volume ls
docker inspect sbx-demo --format '{{json .Mounts}}'
```

Pass:

- `claude auth status` still shows `"loggedIn": true`.
- `claude --continue` resumes the earlier session.
- Every file in `$SBX_DIR/demo` and `$SBX_DIR/state` is still there on the Mac.
- `docker volume ls` lists no volume holding sandbox data.
- The Mounts JSON has exactly one entry: `"Type":"bind"`, source `$SBX_DIR`, destination `/home/sandbox/workspace`.

## H-10: a missing folder is refused

```bash
docker compose down
SBX_NAME=demo SBX_DIR=/Users/you/does-not-exist docker compose up -d --wait; echo rc=$?; ls /Users/you/does-not-exist
```

Pass: `up` errors, and the `ls` says the path does not exist.

- Write down exactly what happened, with the Compose and Docker Desktop versions.
- If Docker created `/Users/you/does-not-exist`, that is a failure:
  - Remove it: `rm -r /Users/you/does-not-exist`.
  - See the env_file follow-up in [`SANDBOX.md`, Troubleshooting](../SANDBOX.md#troubleshooting-and-known-limits).

Then bring the real sandbox back for the next checks:

```bash
docker compose up -d --wait
```

## H-11: stopping is quick and keeps everything

```bash
time docker compose down
docker ps -a --filter name=sbx-demo
ls "$SBX_DIR/demo" "$SBX_DIR/state"
docker compose up -d --wait
```

Pass:

- `down` returns in a few seconds.
- The container is gone from `docker ps -a`.
- The project and state folders are intact.

## H-12: a plain docker run is refused, and the pinned version is installed

```bash
docker run --rm sbx-claude:local claude --version; echo rc=$?
docker run --rm --entrypoint claude sbx-claude:local --version
```

Pass:

- The first prints `[sbx] ERROR ... not a bind mount` and `rc=1`.
- The second prints `2.1.285 (Claude Code)`: the version you approved. The installed version must equal that pin.

## H-13: environment is visible, and self-update is off

```bash
docker exec sbx-demo env | grep -E '^(CLAUDE_CONFIG_DIR|DISABLE_UPDATES|HISTFILE|GH_CONFIG_DIR|GIT_CONFIG_GLOBAL)='
docker exec sbx-demo claude update
docker exec -it sbx-demo claude doctor
docker exec sbx-demo sh -c 'ls ~/.local/share/claude 2>&1'
```

Pass:

- All five variables are present through `docker exec`.
- `claude update` says "Updates are disabled by your administrator".
- `claude doctor` shows auto-updates disabled.
- `~/.local/share/claude` does not exist.

## Coexistence

```bash
docker ps
git status
```

Pass:

- `docker ps` still lists your old-layout containers, running and untouched.
- `git status` in the repo shows no change under `ClaudeCode/` or `OpenCode/`.

## Record your results

Copy this table and fill it in.

| ID | pass/fail | notes |
|---|---|---|
| H-00 | | |
| H-01 | | |
| H-02 | | |
| H-03 | | |
| H-04 | | |
| H-05 | | |
| H-06 | | |
| H-07 | | |
| H-08 | | |
| H-09 | | |
| H-10 | | |
| H-11 | | |
| H-12 | | |
| H-13 | | |
| Coexistence | | |

- `docker compose version` output:
- Docker Desktop version:
- H-10 observation (what `up` printed, its exit code, whether the folder existed afterwards):

Any failure becomes input for gap-closure planning.
