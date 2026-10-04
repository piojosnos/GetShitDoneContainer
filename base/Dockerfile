# Shared base for every sbx agent image.
# - Holds nothing agent-specific.
# - Build from the repo root: docker build -f base/Dockerfile -t sbx-base:local .
FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Pinned versions. Override for one build with --build-arg NAME=VERSION.
ARG NODE_VERSION=24.21.0
ARG GH_VERSION=2.102.0

# --- OS packages ---
# - One layer, no recommended extras.
# - apt lists are removed in the same layer, so the cache never lands in the image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git less procps xz-utils \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js ---
# - Official tarball, checked against nodejs.org's SHASUMS256.txt.
# - dpkg arch names (amd64, arm64) map to Node's (x64, arm64).
# - No arch override anywhere, so Apple Silicon builds natively.
RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in amd64) node_arch=x64 ;; arm64) node_arch=arm64 ;; *) echo "unsupported arch: $arch" >&2; exit 1 ;; esac \
    && f="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${f}" \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" | grep " ${f}\$" | sha256sum -c - \
    && tar -xJf "$f" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "$f"

# --- GitHub CLI ---
# - Release tarball, checked against the release's checksums file.
# - Why a tarball: the cli.github.com apt repo serves only the latest version, so it can't be pinned.
# - dpkg arch names match the release asset names, so arm64 gets the native build.
# - Only the gh binary is extracted, owned by root.
RUN arch="$(dpkg --print-architecture)" \
    && d="gh_${GH_VERSION}_linux_${arch}" \
    && curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${d}.tar.gz" \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt" | grep " ${d}.tar.gz\$" | sha256sum -c - \
    && tar -xzf "${d}.tar.gz" -C /usr/local/bin --strip-components=2 --no-same-owner "${d}/bin/gh" \
    && rm "${d}.tar.gz"

# --- The sandbox user ---
# - ubuntu:24.04 ships an "ubuntu" user at UID/GID 1000; it is removed first.
# - The build fails unless sandbox ends up as 1000:1000.
# - Why: predictable file ownership on the mounted folder.
RUN (userdel -r ubuntu || true) \
    && useradd -m -u 1000 -s /bin/bash sandbox \
    && test "$(id -u sandbox):$(id -g sandbox)" = "1000:1000"

# --- git safe.directory ---
# - Set in /etc/gitconfig, which belongs to the image, not to the mount.
# - Repos created on the Mac never trigger "dubious ownership".
RUN git config --system safe.directory '*'

# --- Per-shell settings ---
# - Image ENV, because docker exec shells get image ENV but never run the entrypoint.
# - All paths are inside the mounted folder (state/), so they survive recreate.
# - Bash history: each command is written to the file right after it runs (history -a).
# - gh: login and config in state/gh.
# - git: global config in state/git. git writes the file itself (lock file plus rename),
#   which is why the folder is mounted, never the single file.
ENV HISTFILE=/home/sandbox/workspace/state/shell/bash_history \
    PROMPT_COMMAND="history -a" \
    GH_CONFIG_DIR=/home/sandbox/workspace/state/gh \
    GIT_CONFIG_GLOBAL=/home/sandbox/workspace/state/git/config \
    LANG=C.UTF-8

# --- Entrypoint ---
# - Copied while still root: owned by root, mode 755.
# - At start it checks the mount, then runs the command. See the script itself.
COPY base/sbx-entrypoint /usr/local/bin/sbx-entrypoint
RUN chmod 755 /usr/local/bin/sbx-entrypoint

# --- Start hooks ---
# - The entrypoint runs every executable here at container start, in name order.
# - Root-owned and outside the mount.
# - Agent images add their scripts here.
RUN mkdir -p /etc/sbx/start.d

# --- Home folders ---
# - Runs at build time, inside the image. No mount exists yet.
# - Creates the empty mount target (workspace) and ~/.local/state.
# - Created as sandbox, so every level, including ~/.local, is owned by sandbox.
# - At container start, compose mounts $SBX_DIR from the Mac over workspace.
# - It never creates anything on the Mac.
USER sandbox
RUN mkdir -p /home/sandbox/workspace /home/sandbox/.local/state

WORKDIR /home/sandbox/workspace
ENTRYPOINT ["/usr/local/bin/sbx-entrypoint"]
CMD ["bash"]
