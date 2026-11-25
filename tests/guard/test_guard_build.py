# --------------------------------------------------------------------------------
# Guard rules on the image build: what a build without options still needs
# --------------------------------------------------------------------------------

from pathlib import Path

from guard_helpers import REPO_DIR, line_list

_SBX_ETC_DIR = "/etc/sbx"


# --------------------------------------------------------------------------------
# Rule etc_sbx_exists_before_its_first_write: no optional step makes it
# --------------------------------------------------------------------------------
# The steps of the optional root certificate create /etc/sbx only when a
# certificate is given. A later step that writes there must find a folder that
# an unconditional step created, or a build without a certificate fails.
# --------------------------------------------------------------------------------

def test_etc_sbx_exists_before_its_first_write():
    created = False
    problem_list = []

    for line_number, instruction in _final_stage_instruction_list(REPO_DIR / "base" / "Dockerfile"):
        if _is_conditional_run(instruction):
            continue

        for command in _command_list(instruction):
            if _creates_etc_sbx(command):
                created = True
            elif not created and _writes_into_etc_sbx(command):
                problem_list.append(f"base/Dockerfile:{line_number}: writes into {_SBX_ETC_DIR} before it is created")

    assert not problem_list, "\n".join(problem_list)


# --------------------------------------------------------------------------------
# TDL
# --------------------------------------------------------------------------------

def _final_stage_instruction_list(path: Path) -> list[tuple[int, str]]:
    instruction_list = []
    current_text = ""
    current_line_number = 0
    line_number = 0

    for line in line_list(path):
        line_number += 1

        if not current_text:
            current_line_number = line_number

        current_text += line.rstrip("\\").strip() + " "

        if line.endswith("\\"):
            continue

        if current_text.startswith("FROM "):
            instruction_list = []
        elif current_text.strip() and not current_text.startswith("#"):
            instruction_list.append((current_line_number, current_text.strip()))

        current_text = ""

    return instruction_list


# --------------------------------------------------------------------------------

def _is_conditional_run(instruction: str) -> bool:
    if not instruction.startswith("RUN "):
        return False

    word_list = instruction.split()[1:]

    while word_list and word_list[0].startswith("--"):
        word_list = word_list[1:]

    return bool(word_list) and word_list[0] == "if"


# --------------------------------------------------------------------------------

def _command_list(instruction: str) -> list[str]:
    command_list = []

    for command in instruction.replace(";", "&&").split("&&"):
        word_list = command.split()

        if word_list[:1] == ["RUN"]:
            word_list = word_list[1:]

        command_list.append(" ".join(word_list))

    return command_list


# --------------------------------------------------------------------------------

def _writes_into_etc_sbx(command: str) -> bool:
    return f"> {_SBX_ETC_DIR}/" in command


# --------------------------------------------------------------------------------

def _creates_etc_sbx(command: str) -> bool:
    word_list = command.split()

    if word_list[:1] == ["COPY"]:
        return f" {_SBX_ETC_DIR}/" in command

    if word_list[:1] != ["mkdir"]:
        return False

    for word in word_list:
        if word == _SBX_ETC_DIR or word.startswith(f"{_SBX_ETC_DIR}/"):
            return True

    return False
