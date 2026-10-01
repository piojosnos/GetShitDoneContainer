ARG BASE_IMAGE=sbx-base:local
FROM ${BASE_IMAGE}

ARG CLAUDE_CODE_VERSION=2.1.285

# --------------------------------------------------------------------------------
# Claude Code, installed from npm at an exact version, as root, into /usr/local.
#
# /usr/local lives OUTSIDE /home/sandbox, so no bind mount can hide it, and the
# version only changes when this image is rebuilt (updates are switched off below).
# The package postinstall links the native arm64/x64 binary; --allow-scripts limits
# script execution to this one package if a newer npm blocks unlisted scripts.
#
# GSD is deliberately NOT here yet: it arrives in Phase 2, baked into this image.
# Nothing is installed when the container starts.
# --------------------------------------------------------------------------------

USER root
RUN npm install -g --allow-scripts=@anthropic-ai/claude-code "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && rm -rf /root/.npm \
    && install -d -o sandbox -g sandbox /home/sandbox/.claude

# Image ENV, not the entrypoint, so every docker exec shell sees these too.
# CLAUDE_CONFIG_DIR is the target of the state/claude bind mount in compose.yml.
ENV CLAUDE_CONFIG_DIR=/home/sandbox/.claude \
    DISABLE_UPDATES=1

USER sandbox

# Build-time smoke test as the runtime user: the pin must match what got installed.
RUN test "$(claude --version)" = "${CLAUDE_CODE_VERSION} (Claude Code)"
