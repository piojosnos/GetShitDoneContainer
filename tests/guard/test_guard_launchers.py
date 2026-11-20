# ------------------------------------------------------------------------------
# Guard rule on the host launchers: two lines into an existing module, mode 755
# ------------------------------------------------------------------------------
# A launcher holds no logic: it only hands off to one Python module through uv, so
# no other program or branch can hide in it. The exec bit is read from git, not
# from the disk, because an edit from the dev sandbox can drop it on the host.
# ------------------------------------------------------------------------------

import re
import subprocess

from guard_helpers import REPO_DIR, launcher_list, relative_name

_SHEBANG_LINE = "#!/bin/sh"
_EXEC_PATTERN = re.compile(
    r'^exec uv run --directory "\$\(dirname "\$0"\)(/\.\.)?" '
    r"(--no-project --python 3\.12|--isolated --frozen) "
    r'--quiet python -m sbx\.([a-z_]+) "\$@"$'
)
_EXECUTABLE_MODE = "100755"


def _git_mode(name: str) -> str:
    completed = subprocess.run(
        ["git", "ls-files", "-s", name],
        cwd=REPO_DIR,
        capture_output=True,
        text=True,
        check=False,
    )
    fields = completed.stdout.split()

    if not fields:
        return "not tracked by git"

    return fields[0]


def _launcher_problem_list(path) -> list[str]:
    name = relative_name(path)
    line_value_list = path.read_text(encoding="utf-8", errors="replace").splitlines()

    if len(line_value_list) != 2:
        return [f"{name}: a launcher has exactly two lines, this one has {len(line_value_list)}"]

    if line_value_list[0] != _SHEBANG_LINE:
        return [f"{name}: line 1 is not {_SHEBANG_LINE}"]

    found = _EXEC_PATTERN.match(line_value_list[1])

    if not found:
        return [f"{name}: line 2 is not the exec uv run line that hands off to an sbx module"]

    problem_list = []
    in_bin = path.parent == REPO_DIR / "bin"

    if in_bin != bool(found.group(1)):
        problem_list.append(f"{name}: the --directory path must end in /.. exactly for files in bin/")

    module_file = REPO_DIR / "sbx" / f"{found.group(3)}.py"

    if not module_file.is_file():
        problem_list.append(f"{name}: sbx/{found.group(3)}.py does not exist")
    elif "def main(" not in module_file.read_text(encoding="utf-8"):
        problem_list.append(f"{name}: sbx/{found.group(3)}.py defines no main")

    mode = _git_mode(name)

    if mode != _EXECUTABLE_MODE:
        problem_list.append(f"{name}: the git mode is {mode}, not {_EXECUTABLE_MODE}")

    return problem_list


# ------------------------------------------------------------------------------
# Rule every_launcher_is_two_lines_into_an_existing_module
# ------------------------------------------------------------------------------

def test_every_launcher_is_two_lines_into_an_existing_module():
    path_list = launcher_list()

    assert path_list, "no file to scan"

    problem_list = []

    for path in path_list:
        problem_list += _launcher_problem_list(path)

    assert not problem_list, "\n".join(problem_list)
