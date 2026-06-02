#!/bin/bash
set -e

# Check if this is first run (no .initialized file)
if [ ! -f /home/sandbox/.initialized ]; then
    echo "First run detected, setting up environment..."

    # All tooling is baked into the image at build time.
    # Add any first-run user-state setup here if needed in the future.

    # Mark as initialized
    touch /home/sandbox/.initialized
    echo "Environment setup complete!"
fi

# Execute the command
exec "$@"
