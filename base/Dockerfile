# check=skip=InvalidDefaultArgInFrom
# Shared base for every sbx agent image: Linux tools and toolchains, nothing agent-specific.
# Build with ./build.sh. No ARG has a default, so a bare build names the missing pin.
# Official JDK and uv images, pinned in versions.env; the final stage copies only their files.
ARG TEMURIN_IMAGE
ARG UV_IMAGE
ARG UBUNTU_IMAGE
FROM ${TEMURIN_IMAGE} AS jdk
FROM ${UV_IMAGE} AS uv
FROM ${UBUNTU_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- OS packages ---
# Apt lists go in the same layer. Packages follow the pinned Ubuntu release.
# Python comes from apt; uv handles projects and other Python versions.
# No ARG above this RUN, so a pin bump never invalidates it.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates curl git less procps xz-utils \
       jq ripgrep unzip zip openssh-client make build-essential tzdata \
       python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js ---
# Official tarball, checked against nodejs.org SHASUMS256.txt; builds natively on arm64.
ARG NODE_VERSION
RUN : "${NODE_VERSION:?NODE_VERSION is not set; build with ./build.sh}" \
    && arch="$(dpkg --print-architecture)" \
    && case "$arch" in amd64) nodeArch=x64 ;; arm64) nodeArch=arm64 ;; *) echo "unsupported arch: $arch" >&2; exit 1 ;; esac \
    && nodeArchive="node-v${NODE_VERSION}-linux-${nodeArch}.tar.xz" \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${nodeArchive}" \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" | grep " ${nodeArchive}\$" | sha256sum -c - \
    && tar -xJf "$nodeArchive" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "$nodeArchive"

# --- GitHub CLI ---
# Release tarball plus checksums file; the cli.github.com apt repo cannot pin a version.
ARG GH_VERSION
RUN : "${GH_VERSION:?GH_VERSION is not set; build with ./build.sh}" \
    && arch="$(dpkg --print-architecture)" \
    && ghArchiveDir="gh_${GH_VERSION}_linux_${arch}" \
    && ghArchive="${ghArchiveDir}.tar.gz" \
    && curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${ghArchive}" \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt" | grep " ${ghArchive}\$" | sha256sum -c - \
    && tar -xzf "$ghArchive" -C /usr/local/bin --strip-components=2 --no-same-owner "${ghArchiveDir}/bin/gh" \
    && rm "$ghArchive"

# --- JDK (Temurin) ---
# Linked into /usr/local/bin because a login shell may reset PATH.
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk
RUN for tool in /opt/java/openjdk/bin/*; do ln -s "$tool" "/usr/local/bin/$(basename "$tool")"; done

# --- Maven ---
# Maven Central keeps every release, so an old pin stays buildable.
ARG MAVEN_VERSION
RUN : "${MAVEN_VERSION:?MAVEN_VERSION is not set; build with ./build.sh}" \
    && mavenArchive="apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    && mavenUrl="https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/${MAVEN_VERSION}" \
    && curl -fsSLO "${mavenUrl}/${mavenArchive}" \
    && echo "$(curl -fsSL "${mavenUrl}/${mavenArchive}.sha512")  ${mavenArchive}" | sha512sum -c - \
    && mkdir -p /opt/maven \
    && tar -xzf "$mavenArchive" -C /opt/maven --strip-components=1 --no-same-owner \
    && rm "$mavenArchive" \
    && ln -s /opt/maven/bin/mvn /usr/local/bin/mvn

# --- uv ---
COPY --from=uv /uv /uvx /usr/local/bin/

# --- The sandbox user ---
# Replaces the ubuntu user at 1000:1000, so files on the mounted folder keep predictable owners.
RUN (userdel -r ubuntu || true) \
    && useradd -m -u 1000 -s /bin/bash sandbox \
    && test "$(id -u sandbox):$(id -g sandbox)" = "1000:1000"

# --- git safe.directory ---
# In /etc/gitconfig (image, not mount), so repos made on the Mac never hit "dubious ownership".
RUN git config --system safe.directory '*'

# --- Per-shell settings ---
# Image ENV, because docker exec shells never run the entrypoint.
# Everything writable lives under state/ in the mount, so it survives recreate and rebuild.
# GIT_CONFIG_GLOBAL points into a folder, never a single file: git replaces the file by rename.
# SBX_STATE_DIRS lists the state folders the entrypoint creates; agent images append to it.
ENV HISTFILE=/home/sandbox/workspace/state/shell/bash_history \
    PROMPT_COMMAND="history -a" \
    GH_CONFIG_DIR=/home/sandbox/workspace/state/gh \
    GIT_CONFIG_GLOBAL=/home/sandbox/workspace/state/git/config \
    JAVA_HOME=/opt/java/openjdk \
    NPM_CONFIG_CACHE=/home/sandbox/workspace/state/cache/npm \
    UV_CACHE_DIR=/home/sandbox/workspace/state/cache/uv \
    UV_LINK_MODE=copy \
    SBX_STATE_DIRS="cache/npm cache/uv m2" \
    LANG=C.UTF-8

# --- Entrypoint ---
# Copied as root: the script is mode 755, the library it sources is 644.
COPY base/sbx-entrypoint /usr/local/bin/sbx-entrypoint
COPY base/sbx-start-lib.sh /usr/local/bin/sbx-start-lib.sh
RUN chmod 755 /usr/local/bin/sbx-entrypoint \
    && chmod 644 /usr/local/bin/sbx-start-lib.sh

# --- Start hooks ---
# The entrypoint runs these in name order at start; a bad entry stops the start. Agent images add theirs.
RUN mkdir -p /etc/sbx/start.d

# --- Home folders ---
# Build time, so no mount exists yet: creates the empty mount target and ~/.local/state as sandbox.
# ~/.m2 links into state/m2 (Maven has no clean variable for its repository).
USER sandbox
RUN mkdir -p /home/sandbox/workspace /home/sandbox/.local/state \
    && ln -s /home/sandbox/workspace/state/m2 /home/sandbox/.m2

# --- Build-time smoke test ---
# Runs as sandbox; each version must match its pin.
# Last RUN: the mount point must be empty, because the mount hides anything the image holds there.
RUN test "$(node -v)" = "v${NODE_VERSION}" \
    && gh --version | grep -F "gh version ${GH_VERSION} " >/dev/null \
    && mvn -v | grep -F "Apache Maven ${MAVEN_VERSION} " >/dev/null \
    && java -version 2>&1 | grep -F "Temurin" >/dev/null \
    && uv --version \
    && python3 --version \
    && { test -z "$(ls -A /home/sandbox/workspace)" || { echo "Files under the mount point:"; find /home/sandbox/workspace; exit 1; }; }

WORKDIR /home/sandbox/workspace
ENTRYPOINT ["/usr/local/bin/sbx-entrypoint"]
CMD ["bash"]
