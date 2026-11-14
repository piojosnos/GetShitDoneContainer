# ------------------------------------------------------------------------------
# The Cursor image: the Cursor CLI (cursor-agent) and sbx-cursor on sbx-base
# ------------------------------------------------------------------------------
# BASE_IMAGE keeps a default because it names the local base tag, not a version.
# Pins come from versions.env through build.sh; no other ARG has a default.
# ------------------------------------------------------------------------------
ARG BASE_IMAGE=sbx-base:local
FROM ${BASE_IMAGE}

# ------------------------------------------------------------------------------
# Cursor CLI: the vendor's versioned package, checked, as root into /usr/local
# ------------------------------------------------------------------------------
# Downloaded at the pinned version and checked against the vendor's .sha256
# before it is unpacked. /tmp is the work folder: the base image ends in the
# mount point. The CLI folder is not writable by the agent process.
# ------------------------------------------------------------------------------
USER root
ARG CURSOR_AGENT_VERSION
WORKDIR /tmp
RUN : "${CURSOR_AGENT_VERSION:?CURSOR_AGENT_VERSION is not set; build with ./build.sh}" \
    && arch="$(dpkg --print-architecture)" \
    && case "$arch" in amd64) cursorArch=x64 ;; arm64) cursorArch=arm64 ;; *) echo "unsupported arch: $arch" >&2; exit 1 ;; esac \
    && cursorUrl="https://downloads.cursor.com/lab/${CURSOR_AGENT_VERSION}/linux/${cursorArch}/agent-cli-package.tar.gz" \
    && curl -fsSLO "${cursorUrl}" \
    && curl -fsSLO "${cursorUrl}.sha256" \
    && sha256sum -c agent-cli-package.tar.gz.sha256 \
    && mkdir -p /usr/local/lib/cursor-agent \
    && tar -xzf agent-cli-package.tar.gz -C /usr/local/lib/cursor-agent --strip-components=1 --no-same-owner \
    && chmod -R go-w /usr/local/lib/cursor-agent \
    && rm agent-cli-package.tar.gz agent-cli-package.tar.gz.sha256 \
    && ln -s /usr/local/lib/cursor-agent/cursor-agent /usr/local/bin/cursor-agent
WORKDIR /home/sandbox/workspace

# ------------------------------------------------------------------------------
# Cursor settings as image ENV
# ------------------------------------------------------------------------------
# So every docker exec shell gets them. The start creates state/cursor.
# ------------------------------------------------------------------------------
ENV CURSOR_CONFIG_DIR=/home/sandbox/workspace/state/cursor \
    SBX_STATE_DIRS="${SBX_STATE_DIRS} cursor"

# ------------------------------------------------------------------------------
# Start hooks (self-update off, the GSD sync, the bundle skills) and sbx-cursor
# ------------------------------------------------------------------------------
# Root-owned, so the sandbox user cannot change them.
# ------------------------------------------------------------------------------
COPY cursor/start.d/ /etc/sbx/start.d/
COPY --chmod=755 cursor/bin/ /usr/local/bin/
RUN chmod 755 /etc/sbx/start.d/*

# ------------------------------------------------------------------------------
# The tool versions line: the Cursor field goes in front of the base fields
# ------------------------------------------------------------------------------
# From the same pin the smoke test below checks, so the line cannot disagree.
# ------------------------------------------------------------------------------
RUN { printf 'cursor-agent %s | ' "${CURSOR_AGENT_VERSION}"; cat /etc/sbx/tool-versions; } > /tmp/tool-versions \
    && mv /tmp/tool-versions /etc/sbx/tool-versions \
    && chmod 644 /etc/sbx/tool-versions \
    && grep -Eq '^cursor-agent [0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9a-f]+ \| gsd [0-9.]+ \| node [0-9.]+ \| jdk [0-9.]+ \| mvn [0-9.]+ \| python [0-9.]+$' /etc/sbx/tool-versions

USER sandbox

# ------------------------------------------------------------------------------
# Home links: the Cursor login and settings live in state/cursor
# ------------------------------------------------------------------------------
# The CLI keeps its login in ~/.config/cursor/auth.json and its settings,
# skills and chats under ~/.cursor. Both links point into one state folder, so
# both survive a recreate and an upgrade. Made as sandbox, so ~/.config is the
# sandbox user's.
# ------------------------------------------------------------------------------
RUN mkdir -p /home/sandbox/.config \
    && ln -s /home/sandbox/workspace/state/cursor /home/sandbox/.cursor \
    && ln -s /home/sandbox/workspace/state/cursor /home/sandbox/.config/cursor

# ------------------------------------------------------------------------------
# Build-time smoke test: the installed version must equal the pin
# ------------------------------------------------------------------------------
# cursor-agent --version writes cli-config.json, so it runs with a throwaway HOME
# and without CURSOR_CONFIG_DIR; otherwise it would write through the dangling
# ~/.cursor link into the mount point. Last RUN: the mount point must stay empty.
# ------------------------------------------------------------------------------
RUN smokeHome="$(mktemp -d)" \
    && test "$(env -u CURSOR_CONFIG_DIR HOME="$smokeHome" cursor-agent --version)" = "${CURSOR_AGENT_VERSION}" \
    && rm -rf "$smokeHome" \
    && { test -z "$(ls -A /home/sandbox/workspace)" || { echo "Files under the mount point:"; find /home/sandbox/workspace; exit 1; }; }

# ------------------------------------------------------------------------------
# Pin record: a copy of versions.env
# ------------------------------------------------------------------------------
# Last, so a pin bump changes only this layer. Nothing reads it at runtime.
# ------------------------------------------------------------------------------
COPY --chmod=644 versions.env /etc/sbx/versions.env
