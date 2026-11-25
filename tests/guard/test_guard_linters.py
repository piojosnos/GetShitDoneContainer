# --------------------------------------------------------------------------------
# Guard rules: shellcheck passes on every script, hadolint on every Dockerfile
# --------------------------------------------------------------------------------
# run_linter runs the tool here when it is installed, else from the test base
# image, so the host needs neither. A missing tool is a failure, never a skip.
# --------------------------------------------------------------------------------

from guard_helpers import dockerfile_list, relative_name_list, run_linter, shell_file_list


# --------------------------------------------------------------------------------
# Rule shellcheck_passes: every script in the shell file list is clean at warning level
# --------------------------------------------------------------------------------
# No -x: following sourced files hangs on this tree, so each file stands alone.
# --------------------------------------------------------------------------------

def test_shellcheck_passes():
    argument_list = ["--rcfile", ".shellcheckrc", "-S", "warning", "-f", "gcc"]
    argument_list += relative_name_list(shell_file_list())

    status, output = run_linter("shellcheck", argument_list)

    assert status == 0, output


# --------------------------------------------------------------------------------
# Rule hadolint_passes: every Dockerfile is clean at warning level
# --------------------------------------------------------------------------------
# --config is explicit, so a stray file in HOME cannot change the result.
# --------------------------------------------------------------------------------

def test_hadolint_passes():
    argument_list = ["--no-color", "--config", ".hadolint.yaml"]
    argument_list += relative_name_list(dockerfile_list())

    status, output = run_linter("hadolint", argument_list)

    assert status == 0, output
