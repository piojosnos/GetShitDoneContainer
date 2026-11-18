# ------------------------------------------------------------------------------
# What the Claude checks share
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/agents/, which the
# launcher puts on the import path. The runner does not load it as a check.
# ------------------------------------------------------------------------------

from pathlib import Path

from paths import STATE_DIR

CONFIG_DIR = STATE_DIR / "claude"

# The directory the image installs the agent in; the ownership check and the protected
# paths check of this image walk it. The sbx commands sit under the base roots.
IMAGE_ROOT_LIST = [Path("/etc/claude-code")]
