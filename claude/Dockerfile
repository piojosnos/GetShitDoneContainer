# BASE_IMAGE keeps a default because it names the local base tag, not a version.
ARG BASE_IMAGE=sbx-base:local
FROM ${BASE_IMAGE}

# Pins come from versions.env through build.sh; no ARG below has a default.

# --- Claude Code ---
# Exact npm version, installed as root into /usr/local, which no mount can hide.
# The build uses a throwaway npm cache, because the image NPM_CONFIG_CACHE points under the mount point.
# ~/.claude links to state/claude only for tools that ignore CLAUDE_CONFIG_DIR.
USER root
ARG CLAUDE_CODE_VERSION
RUN : "${CLAUDE_CODE_VERSION:?CLAUDE_CODE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g --allow-scripts=@anthropic-ai/claude-code "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && rm -rf /tmp/npm-cache \
    && ln -s /home/sandbox/workspace/state/claude /home/sandbox/.claude \
    && chown -h sandbox:sandbox /home/sandbox/.claude

# --- GSD ---
# Only from @opengsd/gsd-core, at the exact pin. The start hook 05-gsd reruns its installer at every start,
# so the image GSD wins over what state/claude holds.
ARG GSD_CORE_VERSION
RUN : "${GSD_CORE_VERSION:?GSD_CORE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g "@opengsd/gsd-core@${GSD_CORE_VERSION}" \
    && rm -rf /tmp/npm-cache

# --- ccusage ---
# Usage reports (ccusage daily, monthly, session). The package ships its native binary without the
# execute bit, so it is added here as root; the glob fails the build if the binary is missing.
ARG CCUSAGE_VERSION
RUN : "${CCUSAGE_VERSION:?CCUSAGE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g "ccusage@${CCUSAGE_VERSION}" \
    && chmod 755 "$(npm root -g)"/ccusage/node_modules/@ccusage/*/bin/ccusage \
    && rm -rf /tmp/npm-cache

# --- Claude settings ---
# Image ENV, so every docker exec shell gets it. SBX_STATE_DIRS keeps the base list and appends claude.
ENV CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude \
    SBX_STATE_DIRS="${SBX_STATE_DIRS} claude" \
    DISABLE_UPDATES=1

# --- Best-practices bundle ---
# Lives in /opt/sbx, outside the mount, root-owned. Start hooks run in name order: 05-gsd, then
# 10-best-practices, which syncs the bundle into CLAUDE_CONFIG_DIR at every start.
# Managed settings deny Claude's edit tools on the synced copies (a guard against accidents, not a boundary).
# Invalid managed settings stop Claude from starting, so the build parses the file.
COPY best-practices /opt/sbx/best-practices
COPY claude/start.d/ /etc/sbx/start.d/
COPY claude/managed-settings.json /etc/claude-code/managed-settings.json
RUN chmod -R u=rwX,go=rX /opt/sbx/best-practices \
    && chmod 755 /etc/sbx/start.d/* \
    && chmod 644 /etc/claude-code/managed-settings.json \
    && node -e 'JSON.parse(require("fs").readFileSync("/etc/claude-code/managed-settings.json", "utf8"))'

USER sandbox

# --- Build-time smoke test ---
# Runs as sandbox; the installed versions must equal the pins.
# Last RUN: the mount point must be empty, because the mount hides anything the image holds there.
RUN test "$(claude --version)" = "${CLAUDE_CODE_VERSION} (Claude Code)" \
    && test "$(gsd-tools runtime-identity --raw)" = "{\"packageName\":\"@opengsd/gsd-core\",\"version\":\"${GSD_CORE_VERSION}\"}" \
    && test "$(ccusage --version)" = "ccusage ${CCUSAGE_VERSION}" \
    && { test -z "$(ls -A /home/sandbox/workspace)" || { echo "Files under the mount point:"; find /home/sandbox/workspace; exit 1; }; }

# --- Pin record ---
# A copy of versions.env, last so a pin bump changes only this layer. Nothing reads it at runtime.
COPY --chmod=644 versions.env /etc/sbx/versions.env
