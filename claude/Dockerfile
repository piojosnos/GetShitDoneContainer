ARG BASE_IMAGE=sbx-base:local
FROM ${BASE_IMAGE}

# Pinned version. Override for one build with --build-arg CLAUDE_CODE_VERSION=VERSION.
ARG CLAUDE_CODE_VERSION=2.1.285

# --- Claude Code ---
# - Installed from npm at an exact version, as root, into /usr/local.
# - /usr/local is outside the mounted folder, so no mount can hide it.
# - The version changes only on rebuild (self-update is off, see ENV below).
# - The package postinstall links the native arm64/x64 binary.
# - --allow-scripts allows that one package's scripts if npm blocks unlisted ones.
# - Nothing is installed when the container starts.
# - ~/.claude is a symlink to state/claude, only as a fallback for tools that
#   ignore CLAUDE_CONFIG_DIR. Claude itself uses CLAUDE_CONFIG_DIR.
USER root
RUN npm install -g --allow-scripts=@anthropic-ai/claude-code "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && rm -rf /root/.npm \
    && ln -s /home/sandbox/workspace/state/claude /home/sandbox/.claude \
    && chown -h sandbox:sandbox /home/sandbox/.claude

# --- Claude settings ---
# - Image ENV, so every docker exec shell gets them too.
# - CLAUDE_CONFIG_DIR: login, settings and sessions, in state/claude on the Mac.
# - SBX_STATE_DIRS: tells the base entrypoint to create state/claude; the base image
#   never needs to know about Claude.
# - DISABLE_UPDATES: Claude never updates itself.
ENV CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude \
    SBX_STATE_DIRS=claude \
    DISABLE_UPDATES=1

# --- Best-practices bundle ---
# - Copied from best-practices/ in this repo, so the build context is the repo root.
# - Lives in /opt/sbx, outside the mounted folder; root-owned and read-only to sandbox.
# - The start hook in /etc/sbx/start.d copies it into CLAUDE_CONFIG_DIR at every start,
#   so the image version wins.
# - Needs no network.
COPY best-practices /opt/sbx/best-practices
COPY claude/start.d/ /etc/sbx/start.d/
RUN chmod -R u=rwX,go=rX /opt/sbx/best-practices \
    && chmod 755 /etc/sbx/start.d/*

USER sandbox

# Build-time smoke test, as the runtime user: the installed version must equal the pin.
RUN test "$(claude --version)" = "${CLAUDE_CODE_VERSION} (Claude Code)"
