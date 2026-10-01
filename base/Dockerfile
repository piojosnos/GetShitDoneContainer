# Shared base for every sbx agent image. Nothing agent-specific belongs here.
# Build from the repo root:  docker build -t sbx-base:local base/
FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG NODE_VERSION=24.21.0
ARG GH_VERSION=2.102.0

# --------------------------------------------------------------------------------
# OS packages
#
# One layer, no recommended extras, apt lists removed at the end of the same chain
# so the cache never lands in the image.
# --------------------------------------------------------------------------------

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git less procps xz-utils \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------------
# Node.js from the official tarball, checked against nodejs.org's SHASUMS256.txt.
#
# dpkg's architecture names (amd64/arm64) are mapped to Node's (x64/arm64). There is
# no architecture override anywhere, so Apple Silicon builds natively.
# --------------------------------------------------------------------------------

RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in amd64) node_arch=x64 ;; arm64) node_arch=arm64 ;; *) echo "unsupported arch: $arch" >&2; exit 1 ;; esac \
    && f="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${f}" \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" | grep " ${f}\$" | sha256sum -c - \
    && tar -xJf "$f" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "$f"

# --------------------------------------------------------------------------------
# GitHub CLI from the release tarball, checked against the release's checksums file.
#
# The tarball is pinned and checksum-verified, while the cli.github.com apt repo only
# serves the current version and cannot be pinned. dpkg's architecture names
# (amd64/arm64) match the release asset names, so arm64 gets the native build.
# Only the gh binary is extracted, owned by root.
# --------------------------------------------------------------------------------

RUN arch="$(dpkg --print-architecture)" \
    && d="gh_${GH_VERSION}_linux_${arch}" \
    && curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${d}.tar.gz" \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt" | grep " ${d}.tar.gz\$" | sha256sum -c - \
    && tar -xzf "${d}.tar.gz" -C /usr/local/bin --strip-components=2 --no-same-owner "${d}/bin/gh" \
    && rm "${d}.tar.gz"

# --------------------------------------------------------------------------------
# The sandbox user.
#
# ubuntu:24.04 already ships an "ubuntu" user and group at UID/GID 1000, so remove
# it first. The assertion fails the build if sandbox does not end up as 1000:1000,
# which keeps file ownership on the bind mounts predictable.
# --------------------------------------------------------------------------------

RUN (userdel -r ubuntu || true) \
    && useradd -m -u 1000 -s /bin/bash sandbox \
    && test "$(id -u sandbox):$(id -g sandbox)" = "1000:1000"

# safe.directory lives in /etc/gitconfig (owned by the image, not by any mount), so
# repos created on the Mac and bind-mounted in never trigger "dubious ownership".
RUN git config --system safe.directory '*'

# Per-shell configuration lives in image ENV, not in the entrypoint or a dotfile:
# docker exec shells inherit image ENV but never run the entrypoint. "history -a" on
# every prompt appends each command to the file on the Mac at once, so a shell that is
# still open when the container is removed loses nothing, and concurrent shells see
# each other's history. gh and git read their config location from the same ENV. Only
# the git directory is mounted: git creates the config file itself (lock file plus
# rename in the same directory), so a single-file mount is never needed.
ENV HISTFILE=/home/sandbox/.local/state/sbx/shell/bash_history \
    PROMPT_COMMAND="history -a" \
    GH_CONFIG_DIR=/home/sandbox/.local/state/sbx/gh \
    GIT_CONFIG_GLOBAL=/home/sandbox/.local/state/sbx/git/config \
    LANG=C.UTF-8

# --------------------------------------------------------------------------------
# Home directories and mount targets.
#
# Created AFTER switching to sandbox so every level, including /home/sandbox/.local,
# is owned by sandbox. These dirs are mount targets, and ~/.local must stay writable
# by sandbox so tools can create ~/.local/share and ~/.local/bin later.
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
# Entrypoint: a mount check, then exec.
#
# Installed while still root so the file is owned by root and mode 755. It refuses to
# start the container unless every mount target is a real, writable bind mount. It
# installs nothing and sets no environment (see the comments in the script itself).
# --------------------------------------------------------------------------------

COPY sbx-entrypoint /usr/local/bin/sbx-entrypoint
RUN chmod 755 /usr/local/bin/sbx-entrypoint

USER sandbox
RUN mkdir -p /home/sandbox/workspace /home/sandbox/.local/state/sbx /home/sandbox/.local/state/sbx/shell /home/sandbox/.local/state/sbx/gh /home/sandbox/.local/state/sbx/git

WORKDIR /home/sandbox/workspace
ENTRYPOINT ["/usr/local/bin/sbx-entrypoint"]
CMD ["bash"]
