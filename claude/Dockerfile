# ------------------------------------------------------------------------------
# The Claude image: Claude Code, ccusage, sbx-claude and the managed settings
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
# Claude Code stays in /usr/local; only its link moves to the agents folder, off
# the PATH, so only sbx-claude starts it.
# ------------------------------------------------------------------------------
USER root
ARG CLAUDE_CODE_VERSION
RUN : "${CLAUDE_CODE_VERSION:?CLAUDE_CODE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g --allow-scripts=@anthropic-ai/claude-code "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && rm -rf /tmp/npm-cache \
    && ln -s "$(readlink -f /usr/local/bin/claude)" /opt/sbx/agents/bin/claude \
    && rm /usr/local/bin/claude \
    && ln -s /home/sandbox/workspace/state/claude /home/sandbox/.claude \
    && chown -h sandbox:sandbox /home/sandbox/.claude

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
# So every docker exec shell gets them; SBX_STATE_DIRS appends claude.
# ------------------------------------------------------------------------------
ENV CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude \
    SBX_STATE_DIRS="${SBX_STATE_DIRS} claude" \
    DISABLE_UPDATES=1

# ------------------------------------------------------------------------------
# sbx-init steps, sbx-claude and managed settings
# ------------------------------------------------------------------------------
# Managed settings let Claude edit the clone and deny its Edit tool on every path
# under state/claude/skills. Not a security boundary. A syntax error in a step
# file stops the build here.
# ------------------------------------------------------------------------------
RUN mkdir -p /etc/sbx/init.d/claude
COPY --chmod=644 claude/init/*.py /etc/sbx/init.d/claude/
COPY --chmod=755 claude/bin/ /usr/local/bin/
COPY claude/managed-settings.json /etc/claude-code/managed-settings.json
RUN PYTHONPYCACHEPREFIX=/tmp/sbx-pycache python3 -m py_compile /etc/sbx/init.d/claude/*.py \
    && rm -rf /tmp/sbx-pycache \
    && chmod 644 /etc/claude-code/managed-settings.json \
    && node -e 'JSON.parse(require("fs").readFileSync("/etc/claude-code/managed-settings.json", "utf8"))'

# ------------------------------------------------------------------------------
# The Claude checks for sbx-selfcheck
# ------------------------------------------------------------------------------
# The runner in the base image runs every file in each folder under
# /etc/sbx/selfcheck.d, here /etc/sbx/selfcheck.d/claude. What those checks share
# goes to /usr/local/lib/sbx-selfcheck/agents, which the runner never loads as a
# check; the launcher puts it on the import path.
# ------------------------------------------------------------------------------
RUN mkdir -p /etc/sbx/selfcheck.d/claude /usr/local/lib/sbx-selfcheck/agents
COPY --chmod=644 claude/selfcheck/*.py /etc/sbx/selfcheck.d/claude/
COPY --chmod=644 claude/selfcheck/lib/*.py /usr/local/lib/sbx-selfcheck/agents/
RUN PYTHONPYCACHEPREFIX=/tmp/sbx-pycache python3 -m py_compile /etc/sbx/selfcheck.d/claude/*.py /usr/local/lib/sbx-selfcheck/agents/*.py \
    && rm -rf /tmp/sbx-pycache

# ------------------------------------------------------------------------------
# The tool versions line: the Claude fields go in front of the base fields
# ------------------------------------------------------------------------------
# From the same pins the smoke test below checks, so the line cannot disagree.
# ------------------------------------------------------------------------------
RUN { printf 'claude %s | ccusage %s | ' "${CLAUDE_CODE_VERSION}" "${CCUSAGE_VERSION}"; cat /etc/sbx/tool-versions; } > /tmp/tool-versions \
    && mv /tmp/tool-versions /etc/sbx/tool-versions \
    && chmod 644 /etc/sbx/tool-versions \
    && grep -Eq '^claude [0-9.]+ \| ccusage [0-9.]+ \| gsd [0-9.]+ \| node [0-9.]+ \| jdk [0-9.]+ \| mvn [0-9.]+ \| python [0-9.]+$' /etc/sbx/tool-versions

USER sandbox

# ------------------------------------------------------------------------------
# Build-time smoke test: the installed versions must equal the pins
# ------------------------------------------------------------------------------
# The agent must not be on the PATH, so it runs by full path. Last RUN: the mount
# point must stay empty; a mount hides what the image holds.
# ------------------------------------------------------------------------------
RUN test "$(/opt/sbx/agents/bin/claude --version)" = "${CLAUDE_CODE_VERSION} (Claude Code)" \
    && ! command -v claude >/dev/null \
    && test "$(ccusage --version)" = "ccusage ${CCUSAGE_VERSION}" \
    && { test -z "$(ls -A /home/sandbox/workspace)" || { echo "Files under the mount point:"; find /home/sandbox/workspace; exit 1; }; }

# ------------------------------------------------------------------------------
# Pin record: a copy of versions.env
# ------------------------------------------------------------------------------
# Last, so a pin bump changes only this layer. sbx-selfcheck reads the pins.
# ------------------------------------------------------------------------------
COPY --chmod=644 versions.env /etc/sbx/versions.env
