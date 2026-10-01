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
