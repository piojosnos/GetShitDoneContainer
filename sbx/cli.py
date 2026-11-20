# ------------------------------------------------------------------------------
# What every sbx command shares: refusals, usage errors and the exit codes
# ------------------------------------------------------------------------------
# A refusal prints "<command>: <text>" on stderr and exits 1; a usage error
# prints one "Usage:" line on stderr and exits 2. An OS error is a refusal too,
# and Ctrl-C prints "interrupted" and exits 130; neither shows a traceback.
# ------------------------------------------------------------------------------

import sys
from pathlib import Path
from typing import Callable


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

REPO_DIR = Path(__file__).resolve().parent.parent
_USAGE_EXIT_CODE = 2
_REFUSAL_EXIT_CODE = 1
_INTERRUPT_EXIT_CODE = 130


# ------------------------------------------------------------------------------
# Errors
# ------------------------------------------------------------------------------

class SbxError(Exception):
    pass


class UsageError(Exception):
    def __init__(self, args_text: str) -> None:
        super().__init__(args_text)
        self.args_text = args_text


# ------------------------------------------------------------------------------
# Running a command
# ------------------------------------------------------------------------------

def print_notice(command_name: str, text: str) -> None:
    print(f"{command_name}: {text}", file=sys.stderr)


def run_command(command_name: str, action: Callable[[], None]) -> int:
    try:
        action()
    except UsageError as e:
        suffix = f" {e.args_text}" if e.args_text else ""
        print(f"Usage: {command_name}{suffix}", file=sys.stderr)

        return _USAGE_EXIT_CODE
    except SbxError as e:
        print_notice(command_name, str(e))

        return _REFUSAL_EXIT_CODE
    except OSError as e:
        print_notice(command_name, str(e))

        return _REFUSAL_EXIT_CODE
    except KeyboardInterrupt:
        print_notice(command_name, "interrupted")

        return _INTERRUPT_EXIT_CODE

    return 0
