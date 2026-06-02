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
# Install Claude CLI and get-shit-done-cc as root, baked into the image
# --------------------------------------------------------------------------------

RUN curl -fsSL https://claude.ai/install.sh | bash && \
    cp /root/.local/bin/claude /usr/local/bin/claude && \
    npx -y @opengsd/get-shit-done-redux@latest --claude --global

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