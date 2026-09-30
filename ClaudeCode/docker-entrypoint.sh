#!/bin/bash
set -e

# First-run setup, gated by the .initialized marker in the mounted home.
#
# GSD installs HERE, not in the Dockerfile, because ~/.claude is covered by the
# host bind mount at runtime -- anything baked into the image home is invisible.
# Installing from the entrypoint populates the LIVE mounted home as the sandbox
# user, so --global resolves to /home/sandbox/.claude correctly.
#
# To force a fresh GSD install, delete /home/sandbox/.initialized on the host
# and bring the container back up. The installer upgrades in place and preserves
# your Claude login (which lives in ~/.claude.json and ~/.claude/.credentials.json).
if [ ! -f /home/sandbox/.initialized ]; then
    echo "Fresh home detected -- installing GSD into ~/.claude ..."

    npx -y @opengsd/gsd-core@latest --claude --global

    touch /home/sandbox/.initialized
    echo "GSD install complete."
fi

# Execute the command
exec "$@"
