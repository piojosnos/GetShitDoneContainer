# ------------------------------------------------------------------------------
# The Claude image: Claude Code, GSD, ccusage and the sbx-* wrappers on sbx-base
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
# So every docker exec shell gets them. SBX_BUNDLE_DIR is where this sandbox
# keeps its clone of BUNDLE_REPO_URL; SBX_STATE_DIRS appends claude.
# ------------------------------------------------------------------------------
ARG BUNDLE_REPO_URL
RUN : "${BUNDLE_REPO_URL:?BUNDLE_REPO_URL is not set; build with ./build.sh}"
ENV CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude \
    SBX_STATE_DIRS="${SBX_STATE_DIRS} claude" \
    SBX_BUNDLE_DIR=/home/sandbox/workspace/best-practices \
    BUNDLE_REPO_URL=${BUNDLE_REPO_URL} \
    DISABLE_UPDATES=1

# ------------------------------------------------------------------------------
# Start hooks, the sbx-* wrappers and managed settings
# ------------------------------------------------------------------------------
# Managed settings let Claude edit the clone and deny its Edit tool on the skill
# list and on every path under state/claude/skills. Not a security boundary.
# ------------------------------------------------------------------------------
COPY claude/start.d/ /etc/sbx/start.d/
COPY --chmod=755 claude/bin/ /usr/local/bin/
COPY claude/managed-settings.json /etc/claude-code/managed-settings.json
RUN chmod 755 /etc/sbx/start.d/* \
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
