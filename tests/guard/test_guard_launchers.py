# --------------------------------------------------------------------------------
# Guard rule on the host launchers: two lines into an existing module, mode 755
# --------------------------------------------------------------------------------
# A launcher holds no logic: it only hands off to one Python module through uv, so
# no other program or branch can hide in it. The exec bit is read from git, not
# from the disk, because an edit from the dev sandbox can drop it on the host.
# --------------------------------------------------------------------------------

import re
import subprocess

from guard_helpers import REPO_DIR, ROOT_SCRIPT_NAME_LIST, launcher_list, relative_name, relative_name_list

_SHEBANG_LINE = "#!/bin/sh"
_EXEC_PATTERN = re.compile(
    r'^exec uv run --directory "\$\(dirname "\$0"\)(/\.\.)?" '
    r"(--no-project --python 3\.12|--isolated --frozen) "
    r'--quiet python -m sbx\.([a-z_]+) "\$@"$'
)
_EXECUTABLE_MODE = "100755"
_STAND_IN_NAME_LIST = ["docker", "xattr", "shellcheck", "hadolint"]


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


# --------------------------------------------------------------------------------
# Rule every_launcher_is_two_lines_into_an_existing_module
# --------------------------------------------------------------------------------

def test_every_launcher_is_two_lines_into_an_existing_module():
    path_list = launcher_list()

    assert path_list, "no file to scan"

    problem_list = []

    for path in path_list:
        problem_list += _launcher_problem_list(path)

    assert not problem_list, "\n".join(problem_list)


# --------------------------------------------------------------------------------
# Rule no_host_logic_in_shell
# --------------------------------------------------------------------------------
# "Host script" means a shell file the host runs that holds logic. The agent
# wrappers and the image commands run in the image and stay shell; the launchers
# hold no logic. No shell file and no stand-in for a tool is tracked under tests/.
# --------------------------------------------------------------------------------

def _tracked_name_list(directory: str) -> list[str]:
    completed = subprocess.run(
        ["git", "ls-files", directory],
        cwd=REPO_DIR,
        capture_output=True,
        text=True,
        check=False,
    )

    return completed.stdout.splitlines()


def _root_script_problem_list(launcher_name_list: list[str]) -> list[str]:
    problem_list = []

    for name in ROOT_SCRIPT_NAME_LIST:
        path = REPO_DIR / name

        if not path.is_file():
            problem_list.append(f"{name}: the root script is missing")
        elif not path.read_text(encoding="utf-8", errors="replace").startswith(_SHEBANG_LINE + "\n"):
            problem_list.append(f"{name}: line 1 is not {_SHEBANG_LINE}, so the launcher rule would not check it")
        elif name not in launcher_name_list:
            problem_list.append(f"{name}: not in the launcher list")

    return problem_list


def _tests_shell_problem_list() -> list[str]:
    problem_list = []

    for name in _tracked_name_list("tests"):
        if name.endswith(".sh"):
            problem_list.append(f"{name}: no shell file is tracked under tests/")

        if name.rsplit("/", 1)[-1] in _STAND_IN_NAME_LIST:
            problem_list.append(f"{name}: no stand-in for {', '.join(_STAND_IN_NAME_LIST)} is tracked under tests/")

    return problem_list


def test_no_host_logic_in_shell():
    launcher_name_list = relative_name_list(launcher_list())
    problem_list = _root_script_problem_list(launcher_name_list)

    for name in _tracked_name_list("bin"):
        if name not in launcher_name_list:
            problem_list.append(f"{name}: a file in bin/ must be a launcher")

    problem_list += _tests_shell_problem_list()

    assert not problem_list, "\n".join(problem_list)
