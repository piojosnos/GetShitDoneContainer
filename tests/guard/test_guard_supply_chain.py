# ------------------------------------------------------------------------------
# Guard rules on the supply chain: one GSD package, exact pins, no pipes
# ------------------------------------------------------------------------------

import re
from pathlib import Path

from guard_helpers import (
    REPO_DIR,
    dockerfile_list,
    host_python_list,
    image_script_list,
    launcher_list,
    line_list,
    nowhere_matches,
    relative_name,
    sandbox_file_list,
    test_python_list,
)

_PIPE_PATTERN = r"(curl|wget)[^|]*\|\s*(sudo\s+)?(ba)?sh(\s|$)"
_SUBSTITUTION_PATTERN = (
    r"(^|[^A-Za-z_])((ba)?sh|source|eval|\.)\s+(-[A-Za-z]+\s+)*\"?(<|\$)\(\s*(curl|wget)"
)
_NPM_INSTALL_PATTERN = r"npm (install|i|add) "
_NPM_ARGUMENT_PATTERN = r"npm (install|i|add)( +-[^ ]+)* +[^- \\&;|]"
_NPM_PINNED_PATTERN = r"\"[@A-Za-z0-9._/-]+@\$\{[A-Z_]+_VERSION\}\""
_UNPINNED_TOOL_PATTERN = (
    r"(^|[\s;&(])(npx|uvx)\s|npm\s+exec|pip3?\s+install|uv\s+(tool|pip)\s+install"
)
_VERSION_PATTERN = (
    r"^[A-Z_]+_VERSION=([0-9]+\.[0-9]+\.[0-9]+|[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9a-f]{7,40})$"
)
_IMAGE_PATTERN = r"^[A-Z_]+_IMAGE=[a-z0-9][a-z0-9./-]*:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$"
_URL_PATTERN = r"^[A-Z_]+_URL=https://[^@\s]+$"


# ------------------------------------------------------------------------------
# Helpers: the lines of the pin file, a glob of files, the download context
# ------------------------------------------------------------------------------

def _pin_line_list() -> list[str]:
    versions_file = REPO_DIR / "versions.env"

    if not versions_file.is_file():
        return []

    pin_list = []

    for line in line_list(versions_file):
        if not re.match(r"^\s*(#.*)?$", line):
            pin_list.append(line)

    return pin_list


def _glob_file_list(pattern_list: list[str]) -> list[Path]:
    file_list = []

    for pattern in pattern_list:
        for path in sorted(REPO_DIR.glob(pattern)):
            if path.is_file():
                file_list.append(path)

    return file_list


def _download_context_text(dockerfile_path: Path) -> str:
    line_value_list = line_list(dockerfile_path)
    chosen_index_list = []
    index = 0

    for line in line_value_list:
        if re.search(r"curl|wget", line):
            for chosen in (index, index + 1):
                if chosen < len(line_value_list) and chosen not in chosen_index_list:
                    chosen_index_list.append(chosen)

        index += 1

    context_list = []

    for chosen in chosen_index_list:
        context_list.append(line_value_list[chosen])

    return " ".join(context_list)


# ------------------------------------------------------------------------------
# Rule no_compromised_gsd_package: GSD comes only from @opengsd/gsd-core
# ------------------------------------------------------------------------------
# The list is every file that ships, documents or tests the sandbox, so the old
# package name in new host code or a new test fails here too.
# ------------------------------------------------------------------------------

def test_no_compromised_gsd_package():
    file_list = sandbox_file_list() + image_script_list()
    file_list += _glob_file_list([
        "base/init/sbx-init",
        "base/init/*.py",
        "base/init/steps/*.py",
        "claude/init/*.py",
        "cursor/init/*.py",
        "base/selfcheck/sbx-selfcheck",
        "base/selfcheck/*.py",
        "claude/selfcheck/*.py",
        "cursor/selfcheck/*.py",
        "claude/managed-settings.json",
        "README.md",
        "MIGRATION.md",
        "tests/host-checklist.md",
        "tests/integration/support/**/*",
        "tests/host/support/**/*",
        "tests/host/*.sh",
        "pyproject.toml",
        "uv.lock",
    ])
    file_list += test_python_list()

    hit_list = nowhere_matches(r"get-shit-done-cc|gsd-build", sorted(set(file_list)))

    assert not hit_list, "\n".join(hit_list)


# ------------------------------------------------------------------------------
# Rule gsd_installs_only_the_official_package: the base image installs pinned GSD
# ------------------------------------------------------------------------------

def test_gsd_installs_only_the_official_package():
    base_text = (REPO_DIR / "base" / "Dockerfile").read_text(encoding="utf-8")

    assert 'npm install -g "@opengsd/gsd-core@${GSD_CORE_VERSION}"' in base_text, (
        'base/Dockerfile does not install "@opengsd/gsd-core@${GSD_CORE_VERSION}"'
    )


# ------------------------------------------------------------------------------
# Rule no_pipe_to_shell_installers: nothing is installed by piping a download to sh
# ------------------------------------------------------------------------------
# Each download line is read with the next one, so a pipe two lines down is not
# seen. Refused: a pipe into sh or bash, and a shell run on a download. The image
# scripts, the launchers, the build and clean scripts and the host modules are
# read line by line.
# ------------------------------------------------------------------------------

def test_no_pipe_to_shell_installers():
    problem_list = []

    for dockerfile_path in dockerfile_list():
        context_text = _download_context_text(dockerfile_path)

        if re.search(_PIPE_PATTERN, context_text) or re.search(_SUBSTITUTION_PATTERN, context_text):
            problem_list.append(f"{relative_name(dockerfile_path)}: a download is piped into a shell")
            problem_list += nowhere_matches(r"curl|wget", [dockerfile_path])

    file_list = image_script_list() + launcher_list() + host_python_list()
    file_list += _glob_file_list(["build.sh", "clean.sh"])
    problem_list += nowhere_matches(
        f"{_PIPE_PATTERN}|{_SUBSTITUTION_PATTERN}", sorted(set(file_list))
    )

    assert not problem_list, "\n".join(problem_list)


# ------------------------------------------------------------------------------
# Rule installs_use_pins: every install is NAME@${X_VERSION}, so versions.env decides
# ------------------------------------------------------------------------------
# A pin with no ARG expands empty, and each install RUN's own ${X_VERSION:?}
# check stops the build. npx, npm exec, pip and uv installs have no pin at all.
# ------------------------------------------------------------------------------

def test_installs_use_pins():
    problem_list = []

    for dockerfile_path in dockerfile_list():
        for line in line_list(dockerfile_path):
            if not re.search(_NPM_INSTALL_PATTERN, line):
                continue

            left_over = re.sub(_NPM_PINNED_PATTERN, "", line)

            if re.search(_NPM_ARGUMENT_PATTERN, left_over):
                problem_list.append(
                    f'an npm install argument that is not "NAME@${{X_VERSION}}": {left_over}'
                )

    problem_list += nowhere_matches(_UNPINNED_TOOL_PATTERN, dockerfile_list())

    assert not problem_list, "\n".join(problem_list)


# ------------------------------------------------------------------------------
# Rule no_floating_latest_versions: what is in the image changes only with a pin
# ------------------------------------------------------------------------------

def test_no_floating_latest_versions():
    hit_list = nowhere_matches(r":latest|@latest", sandbox_file_list())

    assert not hit_list, "\n".join(hit_list)


# ------------------------------------------------------------------------------
# Rule versions_file_has_one_pin_per_line: NAME=value lines, no name set twice
# ------------------------------------------------------------------------------

def test_versions_file_has_one_pin_per_line():
    assert (REPO_DIR / "versions.env").is_file(), "versions.env is missing"

    problem_list = []
    name_count_map: dict[str, int] = {}

    for line in _pin_line_list():
        if not re.match(r"^[A-Z_]+=\S+$", line):
            problem_list.append(f"versions.env: not a NAME=value line: {line}")

        name = line.split("=", 1)[0]
        name_count_map[name] = name_count_map.get(name, 0) + 1

    for name, count in name_count_map.items():
        if count > 1:
            problem_list.append(f"versions.env: set on more than one line: {name}")

    assert not problem_list, "\n".join(problem_list)


# ------------------------------------------------------------------------------
# Rule pins_are_exact: _VERSION x.y.z or a dated build, _IMAGE tag@sha256, _URL https
# ------------------------------------------------------------------------------

def test_pins_are_exact():
    problem_list = []

    for line in _pin_line_list():
        name = line.split("=", 1)[0]

        if re.match(r"^[A-Z_]+_VERSION=", line):
            if not re.match(_VERSION_PATTERN, line):
                problem_list.append(
                    f"versions.env: not an exact x.y.z or YYYY.MM.DD-hash version: {line}"
                )
        elif re.match(r"^[A-Z_]+_IMAGE=", line):
            if not re.match(_IMAGE_PATTERN, line):
                problem_list.append(f"versions.env: not an image tag with its @sha256 digest: {line}")
        elif re.match(r"^[A-Z_]+_URL=", line):
            if not re.match(_URL_PATTERN, line):
                problem_list.append(f"versions.env: not an https:// URL without credentials: {line}")
        else:
            problem_list.append(f"versions.env: the name must end in _VERSION, _IMAGE or _URL: {name}")

    assert not problem_list, "\n".join(problem_list)


# ------------------------------------------------------------------------------
# Rule dockerfile_args_have_no_defaults: no ARG default, every FROM takes a pin
# ------------------------------------------------------------------------------
# The one literal stage, FROM scratch AS cacert, is the empty default of the
# optional root certificate directory that build.sh passes when SBX_CA_CERT is
# set.
# ------------------------------------------------------------------------------

def test_dockerfile_args_have_no_defaults():
    problem_list = []
    base_dockerfile = REPO_DIR / "base" / "Dockerfile"

    for line in line_list(base_dockerfile):
        if re.match(r"^ARG .*=", line):
            problem_list.append(f"base/Dockerfile: an ARG with a default value: {line}")

    for agent in ("claude", "cursor"):
        for line in line_list(REPO_DIR / agent / "Dockerfile"):
            if re.match(r"^ARG .*=", line) and line != "ARG BASE_IMAGE=sbx-base:local":
                problem_list.append(f"{agent}/Dockerfile: an ARG with a default value: {line}")

    for line in line_list(base_dockerfile):
        if not line.startswith("FROM "):
            continue

        if re.match(r"^FROM \$\{[A-Z_]+\}( AS [a-z]+)?$", line) or line == "FROM scratch AS cacert":
            continue

        problem_list.append(f"base/Dockerfile: FROM must take its image from a pin: {line}")

    assert not problem_list, "\n".join(problem_list)


# ------------------------------------------------------------------------------
# Rule agent_images_have_one_from_line: each agent image is one stage on the base image
# ------------------------------------------------------------------------------
# A second stage could pull an image that no pin in versions.env controls.
# ------------------------------------------------------------------------------

def test_agent_images_have_one_from_line():
    problem_list = []

    for agent in ("claude", "cursor"):
        line_value_list = line_list(REPO_DIR / agent / "Dockerfile")
        from_count = 0

        for line in line_value_list:
            if line.startswith("FROM"):
                from_count += 1

        if from_count != 1 or "FROM ${BASE_IMAGE}" not in line_value_list:
            problem_list.append(
                f"{agent}/Dockerfile must have exactly one FROM line, FROM ${{BASE_IMAGE}} "
                f"(found {from_count} FROM lines)"
            )

    assert not problem_list, "\n".join(problem_list)


# ------------------------------------------------------------------------------
# Rule every_dockerfile_arg_is_pinned: ARGs and versions.env pins match both ways
# ------------------------------------------------------------------------------
# EXTRA_CA_FINGERPRINTS is the one ARG that is not a pin: the build derives it
# from SBX_CA_CERT, and empty means no extra root certificate.
# ------------------------------------------------------------------------------

def test_every_dockerfile_arg_is_pinned():
    problem_list = []
    arg_name_list = []
    dockerfile_text_line_list = []
    versions_name_list = []

    for dockerfile_path in dockerfile_list():
        for line in line_list(dockerfile_path):
            dockerfile_text_line_list.append(line)
            found = re.match(r"^ARG ([^=]*)$", line)

            if found and found.group(1) != "EXTRA_CA_FINGERPRINTS":
                arg_name_list.append(found.group(1))

    for line in line_list(REPO_DIR / "versions.env"):
        versions_name_list.append(line.split("=", 1)[0] if "=" in line else "")

    for arg_name in arg_name_list:
        if arg_name not in versions_name_list:
            problem_list.append(f"a Dockerfile declares ARG {arg_name}, which versions.env does not set")

    for line in _pin_line_list():
        if not re.match(r"^[A-Z_]+=", line):
            continue

        pin_name = line.split("=", 1)[0]

        if f"ARG {pin_name}" not in dockerfile_text_line_list:
            problem_list.append(f"versions.env sets {pin_name}, which no Dockerfile declares")

    assert not problem_list, "\n".join(problem_list)
