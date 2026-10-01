# sbx sandbox (new layout)

An sbx sandbox is one Docker container per project that sees exactly two folders on your Mac: the code in `workspace/` and Claude's login, settings and history in `state/claude/`. Nothing is mounted over the container's home directory, so everything the image provides stays visible.

It runs side by side with the old `ClaudeCode/` layout, which keeps working and stays documented in `README.md`.

## Requirements

- Docker Desktop on the Mac.
- Compose v2. Run `docker compose version` and note the version for the host checklist.
- `SBX_NAME` may use lowercase letters, digits, `-` and `_`, and must start with a letter or digit. Compose project names follow that rule, so `MyProject` is rejected and `myproject` works.

## Build the images

From the repo root. The base image must be built first, because the Claude image starts FROM it.

```bash
docker build -t sbx-base:local base/
docker build -t sbx-claude:local claude/
```

## Create a sandbox folder

Once per terminal, export both variables. Every compose subcommand (up, down, ps, config) needs both, because Compose interpolates the whole file before it runs anything.

```bash
export SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo
```

Once per sandbox, create the two folders the container mounts:

```bash
mkdir -p "$SBX_DIR"/workspace "$SBX_DIR"/state/{claude,shell,gh,git}
```

What lives where:

| On the Mac | In the container | Env var |
|---|---|---|
| `$SBX_DIR/workspace` | `/home/sandbox/workspace` | |
| `$SBX_DIR/state/claude` | `/home/sandbox/.claude` | `CLAUDE_CONFIG_DIR` |
| `$SBX_DIR/state/shell` (holds `bash_history`) | `/home/sandbox/.local/state/sbx/shell` | `HISTFILE` |
| `$SBX_DIR/state/gh` (holds `hosts.yml`) | `/home/sandbox/.local/state/sbx/gh` | `GH_CONFIG_DIR` |
| `$SBX_DIR/state/git` (holds `config`) | `/home/sandbox/.local/state/sbx/git` | `GIT_CONFIG_GLOBAL` |

Everything else in `/home/sandbox` (`.bashrc`, `.local`, ...) comes from the image and is visible, not hidden by a mount.

Bash history is written on every prompt, not when the shell exits. A command you typed is on the Mac at once, still there after `docker compose down` and a fresh `up`, and shared between all open shells.

### gh and git identity

- Run `gh auth login` once in the sandbox and it persists. With no keyring in the container, gh stores its token as plain text in `state/gh/hosts.yml`. That is why `state/` lives outside `workspace/`: the token never ends up in a git repo.
- `git config --global user.name "Your Name"` and `git config --global user.email you@example.com` persist in `state/git/config`. The Mac's own `~/.gitconfig` is never read or touched.

## Start, enter, stop

Start the sandbox from the repo root. `--wait` makes Compose report a container that fails to start instead of returning early.

```bash
docker compose up -d --wait
```

Open a shell. This needs no variables if you type the name, and you can open as many shells as you like:

```bash
docker exec -it "sbx-$SBX_NAME" bash
```

Inside the shell, go to a repo under the workspace and start Claude:

```bash
cd ~/workspace/REPO
claude
```

Log in once with a claude.ai account: Claude prints a URL, the browser shows a code, and you paste it at the prompt. The login is written to `$SBX_DIR/state/claude` on the Mac.

Sessions are keyed by directory, so start `claude --continue` or `claude --resume` from the same repo directory you used before.

Stop the sandbox with:

```bash
docker compose down
```

This keeps everything in `workspace/` and `state/`. Never ask down to remove volumes. This layout uses no volumes at all, and that request is how the old layout lost data.

## Rebuild without losing login

Stop the sandbox, rebuild both images (add `--no-cache` to force a clean build), then start it again:

```bash
docker compose down
docker build -t sbx-base:local base/
docker build -t sbx-claude:local claude/
docker compose up -d --wait
```

The login and history live in `state/` on the Mac, so the new container picks them up unchanged.

## Safety checks

The container refuses to run unless every folder it should write to is a real bind mount to a folder on the Mac. Otherwise your work would land in the container's own layer and disappear when the container is recreated.

### Image-only smoke tests

A plain `docker run` of either image, without the compose mounts, is refused by design with an `[sbx] ERROR` line and exit status 1. To check an image on its own, bypass the entrypoint:

```bash
docker run --rm --entrypoint claude sbx-claude:local --version
```

### Before every start: check the sandbox folder

Compose is told not to create missing folders, but some Compose versions ignore that (docker/compose issue 13602). A mistyped `SBX_DIR` could then silently get empty folders, and Claude would ask you to log in again.

Paste this one line right before `docker compose up -d --wait`. If it prints anything, fix `SBX_DIR` or run the `mkdir` from the quick-start above, and do not start:

```bash
for d in workspace state/claude state/shell state/gh state/git; do [ -d "$SBX_DIR/$d" ] || echo "MISSING: $SBX_DIR/$d"; done
```

Always start with `docker compose up -d --wait`, which reports a container that exits at once. If it fails, `docker compose logs` shows the `[sbx] ERROR` line that says which folder is not mounted.

Phase 3's scripts will run this check for you.

## Host verification checklist (H-00..H-13)

Docker is not available in the dev sandbox, so the proof that this layout works happens on your Mac. Run the setup block, then each check below top to bottom. Every check has the commands to paste and a pass condition. Write the outcome of each into "Record your results" further down.

Which roadmap success criterion each check proves:

- SC1 (builds natively and the Claude image sits on the base): H-00, H-01, H-02, H-03
- SC2 (non-root user, workspace and home layout, git works): H-04, H-05, H-06
- SC3 (Claude login survives recreate and rebuild): H-07, H-09
- SC4 (shell history persists): H-08
- SC5 (nothing deletes workspace or state): H-09, H-11

H-10, H-12 and H-13 prove the safety layers: refusal of a missing folder, the entrypoint mount check, and the pinned Claude Code with updates disabled.

### Setup (once)

Replace `/Users/you/sbx-demo` with a folder on your Mac that Docker Desktop can share.

```bash
cd /path/to/this/repo
docker compose version
docker build -t sbx-base:local base/
docker build -t sbx-claude:local claude/
export SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo
mkdir -p "$SBX_DIR"/workspace "$SBX_DIR"/state/{claude,shell,gh,git}
for d in workspace state/claude state/shell state/gh state/git; do [ -d "$SBX_DIR/$d" ] || echo "MISSING: $SBX_DIR/$d"; done
docker compose config | head -3
docker compose up -d --wait
```

The `for` loop must print nothing. The container is named `sbx-demo`, and every command below assumes `SBX_NAME=demo`.

### H-00: Compose v2

```bash
docker compose version
```

Pass: prints a Compose v2 version. Write down that version and the Docker Desktop version (Docker Desktop, About).

### H-01: native arm64

```bash
docker image inspect sbx-base:local sbx-claude:local --format '{{.Architecture}}'
docker exec sbx-demo uname -m
```

Pass: `arm64` twice, then `aarch64`. No "requested image's platform ... does not match" warning appeared during the builds or `up`.

### H-02: the Claude image is built on the base

```bash
docker history sbx-claude:local | head -30
grep '^FROM' claude/Dockerfile
```

Pass: the Claude layers sit on top of the base layers, and the only `FROM` line is `FROM ${BASE_IMAGE}`.

### H-03: variable interpolation

```bash
docker compose config | head -3
SBX_NAME=demo docker compose config
```

Pass: the first command shows `name: sbx-demo`. The second runs in a terminal where `SBX_DIR` is not exported (use a fresh terminal, or prefix it with `env -u SBX_DIR`), and it fails with the "SBX_DIR is required" message.

### H-04: non-root user

```bash
docker exec sbx-demo id
```

Pass: `uid=1000(sandbox) gid=1000(sandbox)`.

### H-05: workspace and home layout

```bash
docker exec sbx-demo sh -c 'touch /home/sandbox/workspace/x.txt; ls -a /home/sandbox'
ls "$SBX_DIR/workspace"
docker exec sbx-demo stat -c '%U %n' /home/sandbox/.local /home/sandbox/.local/state
```

Pass: `x.txt` shows up on the Mac, `ls -a` shows `.bashrc` and `.local`, and both `stat` lines start with `sandbox`.

### H-06: git works and the identity persists

```bash
git init "$SBX_DIR/workspace/hostrepo"
docker exec -w /home/sandbox/workspace/hostrepo sbx-demo git status
docker exec sbx-demo git config --system --get-all safe.directory
docker exec sbx-demo sh -c 'git config --global user.name T && cat $GIT_CONFIG_GLOBAL'
cat "$SBX_DIR/state/git/config"
```

Pass: no "dubious ownership" error, the system `safe.directory` value is `*`, and the identity file appears at `$SBX_DIR/state/git/config` on the Mac.

### H-07: Claude login

```bash
docker exec -it -w /home/sandbox/workspace/hostrepo sbx-demo claude
```

Log in with a claude.ai account, then `/exit`. Then:

```bash
ls -la "$SBX_DIR/state/claude"
docker exec sbx-demo claude auth status
docker exec sbx-demo sh -c 'ls -a $HOME | grep -c "^\.claude\.json$"'
```

Pass: `.claude.json`, `.credentials.json` and `projects/` are in `$SBX_DIR/state/claude` on the Mac, `claude auth status` shows `"loggedIn": true`, and the last command prints `0` (no `~/.claude.json` in the container home).

### H-08: shell history survives recreate

Open a shell, type a marker command, and **leave this first shell open**:

```bash
docker exec -it sbx-demo bash
echo marker-$RANDOM
```

In another terminal, with the same two exported variables, recreate the container:

```bash
docker compose down && docker compose up -d --wait
```

Then open a new shell and look for the marker:

```bash
docker exec -it sbx-demo bash
history | grep marker
```

Pass: the marker is in `history`, and `grep marker "$SBX_DIR/state/shell/bash_history"` on the Mac finds it too.

### H-09: login and files survive a clean rebuild, and no volumes exist

```bash
docker compose down
docker build --no-cache -t sbx-base:local base/ && docker build --no-cache -t sbx-claude:local claude/
docker compose up -d --wait
docker exec sbx-demo claude auth status
docker exec -it -w /home/sandbox/workspace/hostrepo sbx-demo claude --continue
ls -R "$SBX_DIR" | head
docker volume ls
docker inspect sbx-demo --format '{{json .Mounts}}'
```

Pass:

- `claude auth status` still shows `"loggedIn": true`.
- `claude --continue` from the same repo directory resumes the earlier session.
- Every file in `workspace/` and `state/` is still there on the Mac.
- `docker volume ls` lists no volume holding sandbox data.
- Every entry in the Mounts JSON has `"Type":"bind"` and a directory source (no single files).

### H-10: a missing folder is refused

```bash
docker compose down
SBX_NAME=demo SBX_DIR=/Users/you/does-not-exist docker compose up -d --wait; echo rc=$?; ls /Users/you/does-not-exist
```

Pass: `up` errors, and the `ls` says the path does not exist. Write down exactly what happened, with the Compose and Docker Desktop versions. If Docker created `/Users/you/does-not-exist` or folders inside it, that is a failure: remove the bogus folder you typed with `rm -r /Users/you/does-not-exist`, and see the env_file follow-up under "Troubleshooting and known limits". Then bring the real sandbox back for the next checks:

```bash
docker compose up -d --wait
```

### H-11: stopping is quick and keeps everything

```bash
time docker compose down
docker ps -a --filter name=sbx-demo
ls "$SBX_DIR/workspace" "$SBX_DIR/state"
docker compose up -d --wait
```

Pass: `down` returns in a few seconds, the container is gone from `docker ps -a`, and workspace and state are intact.

### H-12: a plain docker run is refused, and the pinned version is installed

```bash
docker run --rm sbx-claude:local claude --version; echo rc=$?
docker run --rm --entrypoint claude sbx-claude:local --version
```

Pass: the first prints `[sbx] ERROR ... not a bind mount` and `rc=1`. The second prints `2.1.285 (Claude Code)`, which is the version you approved in plan 01-01. The installed version must equal that pin.

### H-13: environment is visible, and self-update is off

```bash
docker exec sbx-demo env | grep -E '^(CLAUDE_CONFIG_DIR|DISABLE_UPDATES|HISTFILE|GH_CONFIG_DIR|GIT_CONFIG_GLOBAL)='
docker exec sbx-demo claude update
docker exec -it sbx-demo claude doctor
docker exec sbx-demo sh -c 'ls ~/.local/share/claude 2>&1'
```

Pass: all five variables are present through `docker exec`, `claude update` says "Updates are disabled by your administrator", `claude doctor` shows auto-updates disabled, and `~/.local/share/claude` does not exist.

### Coexistence

```bash
docker ps
git status
```

Pass: `docker ps` still lists your old-layout containers, running and untouched, and `git status` in the repo shows no change under `ClaudeCode/` or `OpenCode/`.

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

## Troubleshooting and known limits

- **Claude hangs at start after an unclean stop.** Check that no claude process is running: `docker exec sbx-demo pgrep -a claude` prints nothing. Then delete the leftover `$SBX_DIR/state/claude/.claude.json.lock` directory. Everything Claude had already written stays in `state/claude`, because it is a bind mount on the Mac and a stopped or removed container does not touch it.
- **Console keyless sign-in is not kept.** It is stored outside `CLAUDE_CONFIG_DIR` and is lost when the container is recreated. Log in with a claude.ai account instead.
- **A check fails only because of the capability drop.** Remove the `cap_drop` block from `compose.yml`, keep `no-new-privileges`, and report it.
- **"Mounts denied" or "path is not shared".** Add the parent of `SBX_DIR` in Docker Desktop, Settings, Resources, File sharing.
- **`required variable SBX_DIR is missing a value`.** Export both `SBX_NAME` and `SBX_DIR` in this terminal. Every compose subcommand needs them.
- **Invalid project name.** `SBX_NAME` must be lowercase.
- **`claude --resume` shows nothing.** Sessions are keyed by directory, so start it from the same repo directory you used before.
- **A plain `docker run` is refused.** That is intended. Bypass the entrypoint for smoke tests, as shown under "Image-only smoke tests".
- **H-10 showed Docker creating the missing folders.** The planned follow-up is an `env_file` sentinel file at the root of `SBX_DIR`, which makes Compose fail when the folder is missing. It changes the folder layout, so it waits for your approval and is not part of Phase 1.
