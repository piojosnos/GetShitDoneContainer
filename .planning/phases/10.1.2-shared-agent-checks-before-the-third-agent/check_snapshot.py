# ------------------------------------------------------------------------------
# Check snapshot: print every agent check result of a tree, one sorted line each
# ------------------------------------------------------------------------------
# Usage: python3 -I -B check_snapshot.py TREE_ROOT, where TREE_ROOT holds base/,
# claude/ and cursor/. The lines are sorted, so a change in the order of the checks
# does not show; a change in a name, passed flag, detail or hint does.
# ------------------------------------------------------------------------------

import json
import sys
from pathlib import Path

AGENT_NAME_LIST = ["claude", "cursor"]


# ------------------------------------------------------------------------------
# Making the tree importable
# ------------------------------------------------------------------------------

def put_tree_on_path(tree_root: Path) -> None:
    path_list = [
        tree_root / "base" / "selfcheck",
        tree_root / "base" / "init",
        tree_root / "claude" / "selfcheck" / "lib",
        tree_root / "cursor" / "selfcheck" / "lib",
    ]

    for path in reversed(path_list):
        sys.path.insert(0, str(path))


# ------------------------------------------------------------------------------
# Running the checks
# ------------------------------------------------------------------------------

def snapshot_line_list(tree_root: Path) -> list[str]:
    import runner
    import step_files

    line_list = []

    for agent_name in AGENT_NAME_LIST:
        for check in runner.dir_check_list(tree_root / agent_name / "selfcheck"):
            result = step_files.run_one(check, runner._FILE_KIND)
            line_list.append(json.dumps([agent_name, check.name, result.passed, result.detail, result.hint]))

    return sorted(line_list)


# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------

def main(argument_list: list[str]) -> int:
    if len(argument_list) != 1:
        print("Usage: check_snapshot.py TREE_ROOT", file=sys.stderr)

        return 2

    tree_root = Path(argument_list[0]).resolve()
    put_tree_on_path(tree_root)

    for line in snapshot_line_list(tree_root):
        print(line)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
