FROM ubuntu:latest

# --------------------------------------------------------------------------------
# Sandbox + ubuntu packages
# --------------------------------------------------------------------------------

RUN useradd -m -s /bin/bash sandbox && \
    apt-get update && \
    apt-get install -y curl nodejs npm && \
    rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------------
# Copy entrypoint script
# --------------------------------------------------------------------------------

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# --------------------------------------------------------------------------------
# Volume & Switch to sandbox user
# --------------------------------------------------------------------------------

USER sandbox

ENV PATH="/home/sandbox/.opencode/bin:$PATH"

WORKDIR /home/sandbox

VOLUME /home/sandbox

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["/bin/bash"]
