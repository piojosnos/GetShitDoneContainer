FROM ubuntu:latest

# --------------------------------------------------------------------------------
# Sandbox + ubuntu packages
# --------------------------------------------------------------------------------

RUN useradd -m -s /bin/bash sandbox && \
    apt-get update && \
    apt-get install -y curl ca-certificates git wget gpg && \
    # Node 20 from NodeSource
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    # GitHub CLI
    mkdir -p -m 755 /etc/apt/keyrings && \
    wget -nv -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y gh && \
    # Clean
    rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------------
# Install the Claude Code CLI binary into /usr/local/bin.
#
# This path lives OUTSIDE /home/sandbox, so it is NOT shadowed by the host
# bind mount at runtime. The binary survives every container and never needs
# reinstalling per-home.
#
# GSD is deliberately NOT installed here: it lives in ~/.claude, which the host
# bind mount covers at runtime, so anything baked into the image home is
# invisible. GSD is installed into the live mounted home by docker-entrypoint.sh
# on first run instead. See README.md ("Why the entrypoint installs GSD").
# --------------------------------------------------------------------------------

RUN curl -fsSL https://claude.ai/install.sh | bash && \
    cp /root/.local/bin/claude /usr/local/bin/claude

# XXX: Experimental
# RUN curl -LsSf https://astral.sh/uv/install.sh | bash
#    uv tool install claude-monitor && \
#RUN npm install ccusage && \
#    chmod 755 node_modules/@ccusage/ccusage-linux-arm64/bin/ccusage && \
#    mkdir -p $HOME/.local/bin/ && \
#    ln -s $HOME/node_modules/@ccusage/ccusage-linux-arm64/bin/ccusage $HOME/.local/bin/ccusage

# --------------------------------------------------------------------------------
# Copy entrypoint script
# --------------------------------------------------------------------------------

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# --------------------------------------------------------------------------------
# Volume & Switch to sandbox user
# --------------------------------------------------------------------------------

USER sandbox
WORKDIR /home/sandbox

VOLUME /home/sandbox

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["/bin/bash"]
