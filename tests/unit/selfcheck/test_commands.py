# --------------------------------------------------------------------------------
# Tests of the command runner
# --------------------------------------------------------------------------------

import commands
from helpers import environment_with, write_stand_in


# --------------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------------

def test_run_command_captures_text_output_and_closes_stdin():
    completed = commands.run_command(["cat"])

    assert completed.returncode == 0
    assert completed.stdout == ""


def test_run_command_passes_the_given_environment():
    completed = commands.run_command(["env"], {"NAME1": "value1"})

    assert completed.stdout.strip() == "NAME1=value1"


def test_first_output_line_takes_stdout_then_stderr(bin1):
    write_stand_in(bin1, "tool1", 'echo; echo "out1"; echo "err1" >&2')
    write_stand_in(bin1, "tool2", 'echo "err2" >&2')
    environment1 = environment_with(bin1)

    assert commands.first_output_line(commands.run_command(["tool1"], environment1)) == "out1"
    assert commands.first_output_line(commands.run_command(["tool2"], environment1)) == "err2"
