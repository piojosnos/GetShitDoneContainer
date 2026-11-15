# ------------------------------------------------------------------------------
# Check: Claude left no copy of itself in the home
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from paths import HOME_DIR, path_is_present

_HOME_COPY_PATH_LIST = [
    HOME_DIR / ".local" / "share" / "claude",
    HOME_DIR / ".local" / "bin" / "claude",
]


# ------------------------------------------------------------------------------
# No home copy
# ------------------------------------------------------------------------------

def no_home_copy_result(copy_path_list: list[Path] = _HOME_COPY_PATH_LIST) -> CheckResult:
    found_path_list = []

    for copy_path in copy_path_list:
        if path_is_present(copy_path):
            found_path_list.append(str(copy_path))

    if found_path_list:
        return failed(
            f"Claude left a copy of itself in the home: {', '.join(found_path_list)}",
            "Claude installed a copy of itself in the home: in this sandbox remove ~/.local/share/claude and ~/.local/bin/claude",
        )

    return passed("no copy of Claude under the home")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_no_home_copy() -> CheckResult:
    return no_home_copy_result()


CHECK_LIST = [Check("claude-no-home-copy", _check_claude_no_home_copy)]
