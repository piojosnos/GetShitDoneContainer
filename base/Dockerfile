# check=skip=InvalidDefaultArgInFrom
# ------------------------------------------------------------------------------
# Shared base for every sbx agent image: Linux tools, toolchains and GSD
# ------------------------------------------------------------------------------
# Build with ./build.sh. No ARG has a default, so a bare build names the pin.
# The stages copy only files from official images pinned in versions.env.
# ------------------------------------------------------------------------------
ARG TEMURIN_IMAGE
ARG UV_IMAGE
ARG UBUNTU_IMAGE
ARG SHELLCHECK_IMAGE
ARG HADOLINT_IMAGE
FROM ${TEMURIN_IMAGE} AS jdk
FROM ${UV_IMAGE} AS uv
FROM ${SHELLCHECK_IMAGE} AS shellcheck
FROM ${HADOLINT_IMAGE} AS hadolint
FROM scratch AS cacert
FROM ${UBUNTU_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ------------------------------------------------------------------------------
# OS packages: apt tools and Python
# ------------------------------------------------------------------------------
# Apt lists go in the same layer. No ARG above this RUN, so a pin bump keeps it.
# ------------------------------------------------------------------------------
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates curl git less procps xz-utils \
       jq ripgrep unzip zip openssh-client make build-essential tzdata \
       python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------------------
# Optional extra root certificate: the system store, before any download
# ------------------------------------------------------------------------------
# build.sh mounts a directory of one-certificate .crt files as the cacert context
# when SBX_CA_CERT is set; without it the empty stage above is mounted and this
# step changes nothing.
# ------------------------------------------------------------------------------
RUN --mount=type=bind,from=cacert,target=/mnt \
    if compgen -G '/mnt/*.crt' >/dev/null; then \
      install -m 644 /mnt/*.crt /usr/local/share/ca-certificates/ \
      && update-ca-certificates \
      && mkdir -p /etc/sbx \
      && cat /mnt/*.crt > /etc/sbx/extra-ca.pem \
      && chmod 644 /etc/sbx/extra-ca.pem; \
    fi

# ------------------------------------------------------------------------------
# Optional extra root certificate: the fingerprints sbx-selfcheck expects
# ------------------------------------------------------------------------------
# build.sh computes them from the same file and passes them as a space separated
# list, apart from the mounted directory, so a lost certificate cannot take its
# expectation with it. Empty means no certificate was requested.
# ------------------------------------------------------------------------------
ARG EXTRA_CA_FINGERPRINTS
RUN if [ -n "$EXTRA_CA_FINGERPRINTS" ]; then \
      mkdir -p /etc/sbx \
      && printf '%s\n' "$EXTRA_CA_FINGERPRINTS" | tr ' ' '\n' > /etc/sbx/extra-ca-fingerprints \
      && chmod 644 /etc/sbx/extra-ca-fingerprints; \
    fi

# ------------------------------------------------------------------------------
# Node.js from the official tarball
# ------------------------------------------------------------------------------
# Checked against nodejs.org SHASUMS256.txt; builds natively on arm64.
# ------------------------------------------------------------------------------
ARG NODE_VERSION
RUN : "${NODE_VERSION:?NODE_VERSION is not set; build with ./build.sh}" \
    && arch="$(dpkg --print-architecture)" \
    && case "$arch" in amd64) nodeArch=x64 ;; arm64) nodeArch=arm64 ;; *) echo "unsupported arch: $arch" >&2; exit 1 ;; esac \
    && nodeArchive="node-v${NODE_VERSION}-linux-${nodeArch}.tar.xz" \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${nodeArchive}" \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" | grep " ${nodeArchive}\$" | sha256sum -c - \
    && tar -xJf "$nodeArchive" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "$nodeArchive"

# ------------------------------------------------------------------------------
# GitHub CLI from the release tarball, checked against its checksums
# ------------------------------------------------------------------------------
# The cli.github.com apt repo cannot pin a version.
# ------------------------------------------------------------------------------
ARG GH_VERSION
RUN : "${GH_VERSION:?GH_VERSION is not set; build with ./build.sh}" \
    && arch="$(dpkg --print-architecture)" \
    && ghArchiveDir="gh_${GH_VERSION}_linux_${arch}" \
    && ghArchive="${ghArchiveDir}.tar.gz" \
    && curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${ghArchive}" \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt" | grep " ${ghArchive}\$" | sha256sum -c - \
    && tar -xzf "$ghArchive" -C /usr/local/bin --strip-components=2 --no-same-owner "${ghArchiveDir}/bin/gh" \
    && rm "$ghArchive"

# ------------------------------------------------------------------------------
# JDK (Temurin) copied from the official image
# ------------------------------------------------------------------------------
# Linked into /usr/local/bin because a login shell may reset PATH.
# ------------------------------------------------------------------------------
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk
RUN for tool in /opt/java/openjdk/bin/*; do ln -s "$tool" "/usr/local/bin/$(basename "$tool")"; done

# ------------------------------------------------------------------------------
# Maven from Maven Central
# ------------------------------------------------------------------------------
# Maven Central keeps every release, so an old pin stays buildable.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Optional extra root certificate: the tools that keep their own store
# ------------------------------------------------------------------------------
# Only when the step above found a certificate. Java: cacerts. npm: cafile.
# pip and uv: their own config files. Node programs: the variable, for
# interactive shells.
# ------------------------------------------------------------------------------
RUN if [ -f /etc/sbx/extra-ca.pem ]; then \
      for certFile in /usr/local/share/ca-certificates/sbx-extra-ca-*.crt; do \
        keytool -importcert -noprompt -cacerts -storepass changeit -alias "$(basename "$certFile" .crt)" -file "$certFile" || exit 1; \
      done \
      && mkdir -p /usr/local/etc /etc/uv \
      && echo 'cafile=/etc/ssl/certs/ca-certificates.crt' >> /usr/local/etc/npmrc \
      && printf '[global]\ncert = /etc/ssl/certs/ca-certificates.crt\n' > /etc/pip.conf \
      && echo 'system-certs = true' > /etc/uv/uv.toml \
      && echo 'export NODE_EXTRA_CA_CERTS=/etc/sbx/extra-ca.pem' >> /etc/bash.bashrc; \
    fi

# ------------------------------------------------------------------------------
# uv from the pinned image
# ------------------------------------------------------------------------------
COPY --from=uv /uv /uvx /usr/local/bin/

# ------------------------------------------------------------------------------
# shellcheck and hadolint: one static binary from each pinned image
# ------------------------------------------------------------------------------
# So the checks run the same in every sandbox.
# ------------------------------------------------------------------------------
COPY --from=shellcheck --chmod=755 /bin/shellcheck /usr/local/bin/shellcheck
COPY --from=hadolint --chmod=755 /bin/hadolint /usr/local/bin/hadolint

# ------------------------------------------------------------------------------
# The sandbox user, replacing the ubuntu user at 1000:1000
# ------------------------------------------------------------------------------
# So files on the mounted directory keep predictable owners.
# ------------------------------------------------------------------------------
RUN (userdel -r ubuntu || true) \
    && useradd -m -u 1000 -s /bin/bash sandbox \
    && test "$(id -u sandbox):$(id -g sandbox)" = "1000:1000"

# ------------------------------------------------------------------------------
# git safe.directory for every directory
# ------------------------------------------------------------------------------
# In /etc/gitconfig (image, not mount): repos made on the host never hit "dubious ownership".
# ------------------------------------------------------------------------------
RUN git config --system safe.directory '*'

# ------------------------------------------------------------------------------
# Per-shell settings as image ENV
# ------------------------------------------------------------------------------
# Every shell, docker exec ones included, gets these from ENV.
# GIT_CONFIG_GLOBAL points into a directory: git replaces the file by rename.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# GSD from @opengsd/gsd-core at the exact pin
# ------------------------------------------------------------------------------
# sbx-init syncs it into the agent config directory (its GSD step), so the
# image's GSD wins. Late in this file, so a GSD bump rebuilds only the layers
# below it.
# ------------------------------------------------------------------------------
ARG GSD_CORE_VERSION
RUN : "${GSD_CORE_VERSION:?GSD_CORE_VERSION is not set; build with ./build.sh}" \
    && export NPM_CONFIG_CACHE=/tmp/npm-cache \
    && npm install -g "@opengsd/gsd-core@${GSD_CORE_VERSION}" \
    && rm -rf /tmp/npm-cache

# ------------------------------------------------------------------------------
# Best-practices clone settings
# ------------------------------------------------------------------------------
# SBX_BEST_PRACTICES_DIR is where a sandbox keeps its clone of BEST_PRACTICES_REPO_URL;
# sbx-init links the clone.
# ------------------------------------------------------------------------------
ARG BEST_PRACTICES_REPO_URL
RUN : "${BEST_PRACTICES_REPO_URL:?BEST_PRACTICES_REPO_URL is not set; build with ./build.sh}"
ENV SBX_BEST_PRACTICES_DIR=/home/sandbox/workspace/best-practices \
    BEST_PRACTICES_REPO_URL=${BEST_PRACTICES_REPO_URL}

# ------------------------------------------------------------------------------
# Shared helpers: sbx-gh-login, sbx-best-practices-clone and sbx-run-agent
# ------------------------------------------------------------------------------
# Copied as root into /usr/local/bin, mode 755, so the sandbox user cannot
# change them. Same paths for every agent.
# ------------------------------------------------------------------------------
COPY --chmod=755 base/bin/ /usr/local/bin/

# ------------------------------------------------------------------------------
# The tool versions line, printed by every interactive shell
# ------------------------------------------------------------------------------
# Written once here, so a shell never waits for java or mvn. The agent images
# add their own fields in front.
# ------------------------------------------------------------------------------
RUN mkdir -p /etc/sbx \
    && printf 'gsd %s | node %s | jdk %s | mvn %s | python %s\n' \
       "${GSD_CORE_VERSION}" \
       "${NODE_VERSION}" \
       "$(java -version 2>&1 | sed -n '1s/.*"\(.*\)".*/\1/p')" \
       "${MAVEN_VERSION}" \
       "$(python3 --version | sed 's/^Python //')" \
       > /etc/sbx/tool-versions \
    && chmod 644 /etc/sbx/tool-versions \
    && grep -Eq '^gsd [0-9.]+ \| node [0-9.]+ \| jdk [0-9.]+ \| mvn [0-9.]+ \| python [0-9.]+$' /etc/sbx/tool-versions \
    && printf '%s\n' 'cat /etc/sbx/tool-versions' >> /etc/bash.bashrc

# ------------------------------------------------------------------------------
# sbx-selfcheck: the runner, its libraries and the shared checks
# ------------------------------------------------------------------------------
# Root-owned and read-only to the sandbox user. Each agent image adds its checks
# directory to /etc/sbx/selfcheck.d. A syntax error in any file stops the build here.
# ------------------------------------------------------------------------------
RUN mkdir -p /usr/local/lib/sbx-selfcheck/checks /etc/sbx/selfcheck.d
COPY --chmod=755 base/selfcheck/sbx-selfcheck /usr/local/lib/sbx-selfcheck/sbx-selfcheck
COPY --chmod=644 base/selfcheck/*.py /usr/local/lib/sbx-selfcheck/
COPY --chmod=644 base/selfcheck/checks/*.py /usr/local/lib/sbx-selfcheck/checks/
RUN ln -s /usr/local/lib/sbx-selfcheck/sbx-selfcheck /usr/local/bin/sbx-selfcheck \
    && PYTHONPYCACHEPREFIX=/tmp/sbx-pycache python3 -m py_compile /usr/local/lib/sbx-selfcheck/sbx-selfcheck /usr/local/lib/sbx-selfcheck/*.py /usr/local/lib/sbx-selfcheck/checks/*.py \
    && rm -rf /tmp/sbx-pycache

# ------------------------------------------------------------------------------
# sbx-init: the runner, its libraries and the shared steps
# ------------------------------------------------------------------------------
# Root-owned and read-only to the sandbox user. Each agent image adds its steps
# directory to /etc/sbx/init.d. A syntax error in any file stops the build here.
# ------------------------------------------------------------------------------
RUN mkdir -p /usr/local/lib/sbx-init/steps /etc/sbx/init.d /opt/sbx/agents/bin
COPY --chmod=755 base/init/sbx-init /usr/local/lib/sbx-init/sbx-init
COPY --chmod=644 base/init/*.py /usr/local/lib/sbx-init/
COPY --chmod=644 base/init/steps/*.py /usr/local/lib/sbx-init/steps/
RUN ln -s /usr/local/lib/sbx-init/sbx-init /usr/local/bin/sbx-init \
    && PYTHONPYCACHEPREFIX=/tmp/sbx-pycache python3 -m py_compile /usr/local/lib/sbx-init/sbx-init /usr/local/lib/sbx-init/*.py /usr/local/lib/sbx-init/steps/*.py \
    && rm -rf /tmp/sbx-pycache

# ------------------------------------------------------------------------------
# Home directories: the empty mount target and ~/.local/state
# ------------------------------------------------------------------------------
# Build time, so no mount exists yet. ~/.m2 links into state/m2: Maven has no
# clean variable for its repository.
# ------------------------------------------------------------------------------
USER sandbox
RUN mkdir -p /home/sandbox/workspace /home/sandbox/.local/state \
    && ln -s /home/sandbox/workspace/state/m2 /home/sandbox/.m2

# ------------------------------------------------------------------------------
# Build-time smoke test: each version must match its pin
# ------------------------------------------------------------------------------
# Last RUN: the mount point must stay empty; a mount hides what the image holds.
# ------------------------------------------------------------------------------
RUN test "$(node -v)" = "v${NODE_VERSION}" \
    && test "$(gsd-tools runtime-identity --raw)" = "{\"packageName\":\"@opengsd/gsd-core\",\"version\":\"${GSD_CORE_VERSION}\"}" \
    && gh --version | grep -F "gh version ${GH_VERSION} " >/dev/null \
    && mvn -v | grep -F "Apache Maven ${MAVEN_VERSION} " >/dev/null \
    && java -version 2>&1 | grep -F "Temurin" >/dev/null \
    && uv --version \
    && python3 --version \
    && shellcheck --version >/dev/null \
    && hadolint --version >/dev/null \
    && { test -z "$(ls -A /home/sandbox/workspace)" || { echo "Files under the mount point:"; find /home/sandbox/workspace; exit 1; }; }

WORKDIR /home/sandbox/workspace
CMD ["bash"]
