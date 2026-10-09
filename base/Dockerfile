# check=skip=InvalidDefaultArgInFrom
# Shared base for every sbx agent image.
# - Holds the Linux tools and the toolchains (git, gh, Node.js, Python with uv, Temurin JDK, Maven)
#   and nothing agent-specific.
# - Build with ./build.sh from the repo root.
#
# Versions live only in versions.env and reach this file through build.sh.
# - No ARG has a default, so a build without build.sh stops and names the missing pin.
# - The FROM images are pins too; the directive on line 1 silences the build check
#   that warns about an ARG without a default in FROM.
#
# The JDK and uv come from their official images, each pinned by tag and digest.
# - The two stages below only hold files; the final stage copies them out.
ARG TEMURIN_IMAGE
ARG UV_IMAGE
ARG UBUNTU_IMAGE
FROM ${TEMURIN_IMAGE} AS jdk
FROM ${UV_IMAGE} AS uv
FROM ${UBUNTU_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- OS packages ---
# - One layer, no recommended extras.
# - apt lists are removed in the same layer, so the cache never lands in the image.
# - Plain apt packages are not pinned: they follow the pinned Ubuntu release and pick up
#   security fixes at each rebuild.
# - DEBIAN_FRONTEND is set on this command only, so tzdata never asks a question.
# - Python comes from apt (3.12 on noble); uv handles projects and other Python versions.
# - No ARG above this RUN, so a pin bump never invalidates this layer.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates curl git less procps xz-utils \
       jq ripgrep unzip zip openssh-client make build-essential tzdata \
       python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js ---
# - Official tarball, checked against nodejs.org's SHASUMS256.txt.
# - dpkg arch names (amd64, arm64) map to Node's (x64, arm64).
# - No arch override anywhere, so Apple Silicon builds natively.
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
# - Release tarball, checked against the release's checksums file.
# - Why a tarball: the cli.github.com apt repo serves only the latest version, so it can't be pinned.
# - dpkg arch names match the release asset names, so arm64 gets the native build.
# - Only the gh binary is extracted, owned by root.
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
# - Copied from the pinned Temurin image.
# - Linked into /usr/local/bin because a login shell may reset PATH and /usr/local/bin is in every PATH.
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk
RUN for tool in /opt/java/openjdk/bin/*; do ln -s "$tool" "/usr/local/bin/$(basename "$tool")"; done

# --- Maven ---
# - Release tarball from Maven Central, checked against the .sha512 file published next to it.
# - Maven Central keeps every release, so an old pin stays buildable.
# - The checksum file holds only the hash; the file name is appended for sha512sum.
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
# - Copied from the pinned uv image.
COPY --from=uv /uv /uvx /usr/local/bin/

# --- The sandbox user ---
# - ubuntu:24.04 ships an "ubuntu" user at UID/GID 1000; it is removed first.
# - The build fails unless sandbox ends up as 1000:1000.
# - Why: predictable file ownership on the mounted folder.
RUN (userdel -r ubuntu || true) \
    && useradd -m -u 1000 -s /bin/bash sandbox \
    && test "$(id -u sandbox):$(id -g sandbox)" = "1000:1000"

# --- git safe.directory ---
# - Set in /etc/gitconfig, which belongs to the image, not to the mount.
# - Repos created on the Mac never trigger "dubious ownership".
RUN git config --system safe.directory '*'

# --- Per-shell settings ---
# - Image ENV, because docker exec shells get image ENV but never run the entrypoint.
# - All paths are inside the mounted folder (state/), so they survive recreate.
# - Bash history: each command is written to the file right after it runs (history -a).
# - gh: login and config in state/gh.
# - git: global config in state/git. git writes the file itself (lock file plus rename),
#   which is why the folder is mounted, never the single file.
# - JAVA_HOME: where the JDK was copied; Maven and other Java tools read it.
# - The npm, uv and Maven caches live in state/ on the Mac, so they survive a recreate and a rebuild.
# - uv copies files instead of hardlinking, because a link between the cache and a project over
#   the Mac file sharing is not reliable.
# - SBX_STATE_DIRS asks the entrypoint to create these folders at start; agent images append to it.
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
# - Copied while still root: owned by root. The entrypoint is mode 755; its library,
#   which it sources from the same folder, is mode 644.
# - At start it checks the mount, then runs the command. See the script itself.
COPY base/sbx-entrypoint /usr/local/bin/sbx-entrypoint
COPY base/sbx-start-lib.sh /usr/local/bin/sbx-start-lib.sh
RUN chmod 755 /usr/local/bin/sbx-entrypoint \
    && chmod 644 /usr/local/bin/sbx-start-lib.sh

# --- Start hooks ---
# - The entrypoint runs the entries here at container start, in name order.
#   Folders and dotfiles are skipped. A file that is not executable, or an entry that is
#   not a regular file (a link that points nowhere, a fifo), stops the start.
# - Root-owned and outside the mount.
# - Agent images add their scripts here.
RUN mkdir -p /etc/sbx/start.d

# --- Home folders ---
# - Runs at build time, inside the image. No mount exists yet.
# - Creates the empty mount target (workspace) and ~/.local/state.
# - Created as sandbox, so every level, including ~/.local, is owned by sandbox.
# - At container start, compose mounts $SBX_DIR from the Mac over workspace.
# - Compose is asked not to create a missing $SBX_DIR on the Mac, but some versions ignore that; the entrypoint then refuses to start.
# - ~/.m2 is a link into state/m2, because Maven has no clean variable for its local repository.
#   A settings.xml kept there lives in state/m2 too. The link points nowhere until the
#   entrypoint creates state/m2 at start.
USER sandbox
RUN mkdir -p /home/sandbox/workspace /home/sandbox/.local/state \
    && ln -s /home/sandbox/workspace/state/m2 /home/sandbox/.m2

# --- Build-time smoke test ---
# - Runs as the runtime user, so a tool the sandbox user cannot run stops the build.
# - Each version must match its pin in versions.env.
# - grep -F writes to /dev/null instead of using -q, which can end the pipe early under pipefail.
# - Last RUN: the mount point must still be empty, because the mount hides whatever the image holds there.
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
