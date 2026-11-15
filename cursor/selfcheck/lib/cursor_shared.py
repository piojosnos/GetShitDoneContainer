# ------------------------------------------------------------------------------
# What the Cursor checks share
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/agents/, which the
# launcher puts on the import path. The runner does not load it as a check.
# ------------------------------------------------------------------------------

from paths import STATE_DIR

CONFIG_DIR = STATE_DIR / "cursor"
