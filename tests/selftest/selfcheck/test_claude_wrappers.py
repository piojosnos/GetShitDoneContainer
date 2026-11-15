# ------------------------------------------------------------------------------
# Tests of the Claude wrappers root-owned check
# ------------------------------------------------------------------------------
# The list must name every file the image copies, so a new file cannot go unchecked.
# ------------------------------------------------------------------------------

from helpers import agent_checks_dir, agent_lib_dir, load_agent_check

wrappers = load_agent_check("claude", "100_wrappers")


# ------------------------------------------------------------------------------
# Claude wrappers root-owned
# ------------------------------------------------------------------------------

def test_the_list_names_the_checks_folder_and_every_check_file_with_the_right_mode():
    mode_by_path_map = dict(wrappers._WRAPPER_MODE_LIST)

    assert mode_by_path_map["/etc/sbx/selfcheck.d/claude"] == 0o755

    for check_file in agent_checks_dir("claude").glob("*.py"):
        assert mode_by_path_map[f"/etc/sbx/selfcheck.d/claude/{check_file.name}"] == 0o644, check_file.name


def test_the_list_names_the_library_folder_and_every_library_file_with_the_right_mode():
    mode_by_path_map = dict(wrappers._WRAPPER_MODE_LIST)

    assert mode_by_path_map["/usr/local/lib/sbx-selfcheck/agents"] == 0o755

    for library_file in agent_lib_dir("claude").glob("*.py"):
        assert mode_by_path_map[f"/usr/local/lib/sbx-selfcheck/agents/{library_file.name}"] == 0o644, library_file.name
