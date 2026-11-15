# ------------------------------------------------------------------------------
# Check: the config folder links the clone's rules and skills
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from bundle_links import bundle_links_result
from check_result import Check, CheckResult
from paths import BUNDLE_DIR, STATE_DIR

_CONFIG_DIR = STATE_DIR / "claude"


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_bundle_links() -> CheckResult:
    return bundle_links_result(_CONFIG_DIR, BUNDLE_DIR, True)


CHECK_LIST = [Check("claude-bundle-links", _check_claude_bundle_links)]
