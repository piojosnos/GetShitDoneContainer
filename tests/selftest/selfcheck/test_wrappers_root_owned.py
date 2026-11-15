# ------------------------------------------------------------------------------
# Tests of the wrappers root-owned check
# ------------------------------------------------------------------------------
# The list must name every file the image copies, so a new file cannot go unchecked.
# ------------------------------------------------------------------------------

from helpers import REPO_DIR, SHARED_CHECKS_DIR, load_shared_check

wrappers_root_owned = load_shared_check("250_wrappers_root_owned")


# ------------------------------------------------------------------------------
# Wrappers root-owned
# ------------------------------------------------------------------------------

def listed_path_set() -> set[str]:
    path_set = set()

    for path, _ in wrappers_root_owned._BASE_WRAPPER_MODE_LIST:
        path_set.add(path)

    return path_set


def test_the_list_names_every_library_and_check_file_with_mode_644():
    listed_set = listed_path_set()

    for library_file in (REPO_DIR / "base" / "selfcheck").glob("*.py"):
        assert f"/usr/local/lib/sbx-selfcheck/{library_file.name}" in listed_set, library_file.name

    for check_file in SHARED_CHECKS_DIR.glob("*.py"):
        assert f"/usr/local/lib/sbx-selfcheck/checks/{check_file.name}" in listed_set, check_file.name

    for path, mode in wrappers_root_owned._BASE_WRAPPER_MODE_LIST:
        if path.endswith(".py"):
            assert mode == 0o644, path


def test_the_list_names_the_launcher_and_the_selfcheck_folders_with_mode_755():
    mode_by_path_map = dict(wrappers_root_owned._BASE_WRAPPER_MODE_LIST)

    assert mode_by_path_map["/usr/local/bin/sbx-selfcheck"] == 0o755
    assert mode_by_path_map["/usr/local/lib/sbx-selfcheck"] == 0o755
    assert mode_by_path_map["/usr/local/lib/sbx-selfcheck/checks"] == 0o755
    assert mode_by_path_map["/etc/sbx/selfcheck.d"] == 0o755
