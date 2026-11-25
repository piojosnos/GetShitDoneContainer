# --------------------------------------------------------------------------------
# Tests of run_command, the exit codes every sbx command shares
# --------------------------------------------------------------------------------
# The action is a stand-in function that raises; nothing else is involved.
# --------------------------------------------------------------------------------

from sbx.cli import SbxError, UsageError, run_command


def _raise(error: BaseException):
    def action() -> None:
        raise error

    return action


# --------------------------------------------------------------------------------

def test_an_action_that_returns_exits_0_and_prints_nothing(capsys):
    exit_code = run_command("sbx-cmd1", lambda: None)
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.err == ""


# --------------------------------------------------------------------------------

def test_a_refusal_prints_one_line_and_exits_1(capsys):
    exit_code = run_command("sbx-cmd1", _raise(SbxError("no good")))
    captured = capsys.readouterr()

    assert exit_code == 1
    assert captured.err == "sbx-cmd1: no good\n"


# --------------------------------------------------------------------------------

def test_a_usage_error_prints_the_usage_line_and_exits_2(capsys):
    exit_code = run_command("sbx-cmd1", _raise(UsageError("NAME")))
    captured = capsys.readouterr()

    assert exit_code == 2
    assert captured.err == "Usage: sbx-cmd1 NAME\n"


# --------------------------------------------------------------------------------

def test_an_interrupt_prints_one_line_and_exits_130(capsys):
    exit_code = run_command("sbx-cmd1", _raise(KeyboardInterrupt()))
    captured = capsys.readouterr()

    assert exit_code == 130
    assert captured.out == ""
    assert captured.err == "sbx-cmd1: interrupted\n"


# --------------------------------------------------------------------------------

def test_an_os_error_prints_its_message_on_one_line_and_exits_1(capsys):
    exit_code = run_command("sbx-cmd1", _raise(PermissionError(13, "Permission denied", "/dir1")))
    captured = capsys.readouterr()

    assert exit_code == 1
    assert captured.out == ""
    assert captured.err == "sbx-cmd1: [Errno 13] Permission denied: '/dir1'\n"
