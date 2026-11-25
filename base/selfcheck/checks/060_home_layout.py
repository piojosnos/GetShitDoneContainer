# --------------------------------------------------------------------------------
# Check: the home holds its base files
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import rebuild_hint
from paths import HOME_DIR


# --------------------------------------------------------------------------------
# Home layout
# --------------------------------------------------------------------------------

def home_layout_result(home_dir: Path = HOME_DIR) -> CheckResult:
    missing_list = []

    for name in [".bashrc", ".local"]:
        if not (home_dir / name).exists():
            missing_list.append(name)

    if missing_list:
        return failed(f"missing in {home_dir}: {', '.join(missing_list)}", rebuild_hint())

    return passed(f".bashrc and .local exist in {home_dir}")


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_home_layout() -> CheckResult:
    return home_layout_result()


CHECK_LIST = [Check("home-layout", _check_home_layout)]
