# Shared base for every sbx agent image. Nothing agent-specific belongs here.
# Build from the repo root:  docker build -t sbx-base:local base/
FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG NODE_VERSION=24.21.0

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

ENV LANG=C.UTF-8

# --------------------------------------------------------------------------------
# Home directories and mount targets.
#
# Created AFTER switching to sandbox so every level, including /home/sandbox/.local,
# is owned by sandbox. These dirs are mount targets, and ~/.local must stay writable
# by sandbox so tools can create ~/.local/share and ~/.local/bin later.
# --------------------------------------------------------------------------------

USER sandbox
RUN mkdir -p /home/sandbox/workspace /home/sandbox/.local/state/sbx

WORKDIR /home/sandbox/workspace
CMD ["bash"]
