# BASE_IMAGE keeps a default because it names the local base tag, not a version.
ARG BASE_IMAGE=sbx-base:local
FROM ${BASE_IMAGE}

# Versions live only in versions.env and reach this file through build.sh.
# - No ARG below has a default, so a build without build.sh stops and names the missing pin.

# --- Claude Code ---
# - Installed from npm at an exact version, as root, into /usr/local.
# - /usr/local is outside the mounted folder, so no mount can hide it.
# - The version changes only on rebuild (self-update is off, see ENV below).
# - The package postinstall links the native arm64/x64 binary.
# - --allow-scripts allows that one package's scripts if npm blocks unlisted ones.
# - Nothing is installed when the container starts.
# - The build uses a throwaway npm cache in /tmp, because the image's NPM_CONFIG_CACHE points
#   under the mount point, where the image must hold nothing.
# - ~/.claude is a symlink to state/claude, only as a fallback for tools that
#   ignore CLAUDE_CONFIG_DIR. Claude itself uses CLAUDE_CONFIG_DIR.
USER root
ARG CLAUDE_CODE_VERSION
RUN : "${CLAUDE_CODE_VERSION:?CLAUDE_CODE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g --allow-scripts=@anthropic-ai/claude-code "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && rm -rf /tmp/npm-cache \
    && ln -s /home/sandbox/workspace/state/claude /home/sandbox/.claude \
    && chown -h sandbox:sandbox /home/sandbox/.claude

# --- GSD ---
# - Installed from npm at the exact version in versions.env, and only from @opengsd/gsd-core,
#   as root into /usr/local, outside the mount.
# - The start hook 05-gsd runs its installer at every start, so the image's GSD wins over
#   what state/claude holds.
# - The package brings a second Claude binary for its agent SDK under /usr/local/lib, not on
#   PATH, which never updates itself.
ARG GSD_CORE_VERSION
RUN : "${GSD_CORE_VERSION:?GSD_CORE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g "@opengsd/gsd-core@${GSD_CORE_VERSION}" \
    && rm -rf /tmp/npm-cache

# --- ccusage ---
# - Usage reports for Claude: ccusage daily, monthly and session.
# - Installed from npm at the exact version in versions.env, as root into /usr/local.
# - Its native binary comes from a per-platform optional dependency, so optional dependencies
#   are never skipped.
# - The package ships that binary without the execute bit, and only its owner could add it at
#   run time, so it is added here as root. The glob fails the build if the binary is missing.
ARG CCUSAGE_VERSION
RUN : "${CCUSAGE_VERSION:?CCUSAGE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g "ccusage@${CCUSAGE_VERSION}" \
    && chmod 755 "$(npm root -g)"/ccusage/node_modules/@ccusage/*/bin/ccusage \
    && rm -rf /tmp/npm-cache

# --- Claude settings ---
# - Image ENV, so every docker exec shell gets them too.
# - CLAUDE_CONFIG_DIR: login, settings and sessions, in state/claude on the Mac.
# - SBX_STATE_DIRS: tells the base entrypoint to create state/claude; the base image
#   never needs to know about Claude. The base list is kept and claude is appended.
# - DISABLE_UPDATES: Claude never updates itself.
ENV CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude \
    SBX_STATE_DIRS="${SBX_STATE_DIRS} claude" \
    DISABLE_UPDATES=1

# --- Best-practices bundle ---
# - Copied from best-practices/ in this repo, so the build context is the repo root.
# - Lives in /opt/sbx, outside the mounted folder; root-owned and read-only to sandbox.
# - The start hooks in /etc/sbx/start.d run in name order: 05-gsd syncs GSD, then
#   10-best-practices syncs the bundle into CLAUDE_CONFIG_DIR at every start, so the image
#   version wins.
# - Needs no network.
# - Managed settings deny Claude's own edit tools on the synced copies and on the skill list.
#   This guards against accidental edits; it is not a security boundary, because a script
#   Claude runs can still write there until the next start.
# - Invalid managed settings stop Claude from starting, so the build parses the file.
COPY best-practices /opt/sbx/best-practices
COPY claude/start.d/ /etc/sbx/start.d/
COPY claude/managed-settings.json /etc/claude-code/managed-settings.json
RUN chmod -R u=rwX,go=rX /opt/sbx/best-practices \
    && chmod 755 /etc/sbx/start.d/* \
    && chmod 644 /etc/claude-code/managed-settings.json \
    && node -e 'JSON.parse(require("fs").readFileSync("/etc/claude-code/managed-settings.json", "utf8"))'

USER sandbox

# --- Build-time smoke test ---
# - Runs as the runtime user: the installed versions must equal the pins.
# - Last RUN: the mount point must still be empty, because the mount hides whatever the image holds there.
RUN test "$(claude --version)" = "${CLAUDE_CODE_VERSION} (Claude Code)" \
    && test "$(gsd-tools runtime-identity --raw)" = "{\"packageName\":\"@opengsd/gsd-core\",\"version\":\"${GSD_CORE_VERSION}\"}" \
    && test "$(ccusage --version)" = "ccusage ${CCUSAGE_VERSION}" \
    && { test -z "$(ls -A /home/sandbox/workspace)" || { echo "Files under the mount point:"; find /home/sandbox/workspace; exit 1; }; }

# --- Pin record ---
# - A copy of versions.env: the pins this image was built with.
# - Nothing reads it at runtime.
# - Last, so a pin bump changes only this layer.
COPY --chmod=644 versions.env /etc/sbx/versions.env
