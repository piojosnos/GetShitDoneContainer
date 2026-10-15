# ------------------------------------------------------------------------------
# The Claude agent image: Claude Code, GSD, ccusage and the bundle on sbx-base
# ------------------------------------------------------------------------------
# BASE_IMAGE keeps a default because it names the local base tag, not a version.
# Pins come from versions.env through build.sh; no other ARG has a default.
# ------------------------------------------------------------------------------
ARG BASE_IMAGE=sbx-base:local
FROM ${BASE_IMAGE}

# ------------------------------------------------------------------------------
# Claude Code: exact npm version, as root into /usr/local (no mount hides it)
# ------------------------------------------------------------------------------
# The build uses a throwaway npm cache: the image's is under the mount.
# ~/.claude links to state/claude only for tools that ignore CLAUDE_CONFIG_DIR.
# ------------------------------------------------------------------------------
USER root
ARG CLAUDE_CODE_VERSION
RUN : "${CLAUDE_CODE_VERSION:?CLAUDE_CODE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g --allow-scripts=@anthropic-ai/claude-code "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && rm -rf /tmp/npm-cache \
    && ln -s /home/sandbox/workspace/state/claude /home/sandbox/.claude \
    && chown -h sandbox:sandbox /home/sandbox/.claude

# ------------------------------------------------------------------------------
# GSD from @opengsd/gsd-core at the exact pin
# ------------------------------------------------------------------------------
# The start hook 05-gsd reruns its installer at every start, so the image's
# GSD wins over what state/claude holds.
# ------------------------------------------------------------------------------
ARG GSD_CORE_VERSION
RUN : "${GSD_CORE_VERSION:?GSD_CORE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g "@opengsd/gsd-core@${GSD_CORE_VERSION}" \
    && rm -rf /tmp/npm-cache

# ------------------------------------------------------------------------------
# ccusage for usage reports (daily, monthly, session)
# ------------------------------------------------------------------------------
# The package ships its native binary without the execute bit, so root adds it;
# the glob fails the build if the binary is missing.
# ------------------------------------------------------------------------------
ARG CCUSAGE_VERSION
RUN : "${CCUSAGE_VERSION:?CCUSAGE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g "ccusage@${CCUSAGE_VERSION}" \
    && chmod 755 "$(npm root -g)"/ccusage/node_modules/@ccusage/*/bin/ccusage \
    && rm -rf /tmp/npm-cache

# ------------------------------------------------------------------------------
# Claude settings as image ENV
# ------------------------------------------------------------------------------
# So every docker exec shell gets them. SBX_STATE_DIRS keeps the base list
# and appends claude.
# ------------------------------------------------------------------------------
ENV CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude \
    SBX_STATE_DIRS="${SBX_STATE_DIRS} claude" \
    DISABLE_UPDATES=1

# ------------------------------------------------------------------------------
# Best-practices bundle in /opt/sbx (outside the mount) and managed settings
# ------------------------------------------------------------------------------
# Managed settings deny Claude's Edit tool on the synced rules, the skill list
# and every skill folder. This is not a security boundary.
# ------------------------------------------------------------------------------
COPY best-practices /opt/sbx/best-practices
COPY claude/start.d/ /etc/sbx/start.d/
COPY claude/managed-settings.json /etc/claude-code/managed-settings.json
RUN chmod -R u=rwX,go=rX /opt/sbx/best-practices \
    && chmod 755 /etc/sbx/start.d/* \
    && chmod 644 /etc/claude-code/managed-settings.json \
    && node -e 'JSON.parse(require("fs").readFileSync("/etc/claude-code/managed-settings.json", "utf8"))'

USER sandbox

# ------------------------------------------------------------------------------
# Build-time smoke test: the installed versions must equal the pins
# ------------------------------------------------------------------------------
# Last RUN: the mount point must stay empty; a mount hides what the image holds.
# ------------------------------------------------------------------------------
RUN test "$(claude --version)" = "${CLAUDE_CODE_VERSION} (Claude Code)" \
    && test "$(gsd-tools runtime-identity --raw)" = "{\"packageName\":\"@opengsd/gsd-core\",\"version\":\"${GSD_CORE_VERSION}\"}" \
    && test "$(ccusage --version)" = "ccusage ${CCUSAGE_VERSION}" \
    && { test -z "$(ls -A /home/sandbox/workspace)" || { echo "Files under the mount point:"; find /home/sandbox/workspace; exit 1; }; }

# ------------------------------------------------------------------------------
# Pin record: a copy of versions.env
# ------------------------------------------------------------------------------
# Last, so a pin bump changes only this layer. Nothing reads it at runtime.
# ------------------------------------------------------------------------------
COPY --chmod=644 versions.env /etc/sbx/versions.env
