#!/bin/bash
set -e

# Check if this is first run (no .initialized file)
if [ ! -f /home/sandbox/.initialized ]; then
    echo "First run detected, setting up environment..."

    # Add .local/bin to PATH in .bashrc
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/sandbox/.bashrc

    chmod 755 /home/sandbox/.bashrc

    # Install opencode-ai CLI
    curl -fsSL https://opencode.ai/install | bash >> log 2>&1

    # Install get-shit-done-cc
    npx -y get-shit-done-cc --opencode --global >> log 2>&1

    # Mark as initialized
    touch /home/sandbox/.initialized
    echo "Environment setup complete!"
fi

# Execute the command
exec "$@"
