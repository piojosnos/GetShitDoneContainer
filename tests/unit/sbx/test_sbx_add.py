# --------------------------------------------------------------------------------
# Tests of sbx-add: the entry, the directories, every refusal and every overlap
# --------------------------------------------------------------------------------
# Real directories, symlinks and registry files under tmp_path. sbx-add calls no
# Docker, so there is no Docker parameter to pass.
# --------------------------------------------------------------------------------

import json

import pytest

from sbx import add as add_module
from sbx_helpers import environ_for, write_json_entry

USAGE_TEXT = "Usage: sbx-add NAME HOST_PATH [claude|cursor]"
RULE_TEXT = "breaks the sandbox name rule"


@pytest.fixture
def repo_dir(tmp_path):
    tools_dir = tmp_path / "tools1"
    tools_dir.mkdir()

    return tools_dir


# --------------------------------------------------------------------------------

@pytest.fixture
def run_add(config_dir, repo_dir, capsys):
    def run(argument_list, extra_map=None):
        exit_code = add_module.main(argument_list, environ_for(config_dir, extra_map), repo_dir=repo_dir)
        captured = capsys.readouterr()

        return exit_code, captured.out, captured.err

    return run


# --------------------------------------------------------------------------------

def _entry_of(registry, name):
    return json.loads((registry / f"{name}.json").read_text(encoding="utf-8"))


# --------------------------------------------------------------------------------

def _registry_names(registry):
    name_list = []

    for file in registry.iterdir():
        name_list.append(file.name)

    return sorted(name_list)


# --------------------------------------------------------------------------------
# Registering
# --------------------------------------------------------------------------------

def test_a_sandbox_is_registered_and_its_directories_are_made(run_add, registry, tmp_path):
    path = tmp_path / "sbx one"

    exit_code, out, err = run_add(["sbx1", str(path)])

    assert exit_code == 0
    assert err == ""
    assert _entry_of(registry, "sbx1") == {"path": str(path), "agent": "claude"}
    assert (path / "sbx1").is_dir()
    assert (path / "state").is_dir()
    assert out.splitlines() == [
        f"sbx-add: registered sbx1 at {path} (agent claude)",
        "sbx-add: next, sbx-upgrade sbx1 builds the images and starts it; "
        "sbx-start sbx1 starts it on the images you have",
    ]


# --------------------------------------------------------------------------------

def test_a_trailing_slash_is_not_stored(run_add, registry, tmp_path):
    exit_code, _, _ = run_add(["sbx1", f"{tmp_path}/sbx two//"])

    assert exit_code == 0
    assert _entry_of(registry, "sbx1")["path"] == f"{tmp_path}/sbx two"


# --------------------------------------------------------------------------------

def test_the_third_argument_picks_the_agent(run_add, registry, tmp_path):
    exit_code, out, _ = run_add(["sbx1", str(tmp_path / "x1"), "cursor"])

    assert exit_code == 0
    assert _entry_of(registry, "sbx1")["agent"] == "cursor"
    assert "(agent cursor)" in out


# --------------------------------------------------------------------------------

def test_claude_as_the_third_argument_is_the_same_as_none(run_add, registry, tmp_path):
    run_add(["sbx1", str(tmp_path / "x1"), "claude"])

    assert _entry_of(registry, "sbx1")["agent"] == "claude"


# --------------------------------------------------------------------------------

def test_a_path_with_a_space_and_a_non_ascii_letter_is_stored_as_given(run_add, registry, tmp_path):
    path = f"{tmp_path}/one dir/caf\u00e9"

    exit_code, _, _ = run_add(["sbx1", path])

    assert exit_code == 0
    assert _entry_of(registry, "sbx1")["path"] == path


# --------------------------------------------------------------------------------

def test_an_existing_directory_and_its_files_are_kept(run_add, tmp_path):
    keep_file = tmp_path / "sbx3" / "state" / "keep.txt"
    keep_file.parent.mkdir(parents=True)
    keep_file.write_text("keep")

    exit_code, _, _ = run_add(["sbx1", str(tmp_path / "sbx3")])

    assert exit_code == 0
    assert keep_file.read_text() == "keep"


# --------------------------------------------------------------------------------

def test_the_entry_goes_under_home_when_the_config_directory_is_unset(tmp_path, repo_dir, capsys):
    home_dir = tmp_path / "home1"
    home_dir.mkdir()

    exit_code = add_module.main(["sbx1", str(tmp_path / "x1")], {"HOME": str(home_dir)}, repo_dir=repo_dir)

    assert exit_code == 0
    assert (home_dir / ".config" / "sbx" / "sandboxes" / "sbx1.json").is_file()


# --------------------------------------------------------------------------------

def test_a_relative_config_directory_is_refused_and_nothing_is_made(run_add, tmp_path):
    exit_code, _, err = run_add(["sbx1", str(tmp_path / "x1")], {"SBX_CONFIG_DIR": "cfg"})

    assert exit_code == 1
    assert "SBX_CONFIG_DIR must be an absolute path" in err
    assert not (tmp_path / "x1").exists()


# --------------------------------------------------------------------------------
# Usage
# --------------------------------------------------------------------------------

@pytest.mark.parametrize(
    "argument_list",
    [[], ["sbx1"], ["sbx1", "/x/a", "cursor", "extra"], ["sbx1", "/x/a", "opencode"], ["sbx1", "/x/a", ""]],
)
def test_a_wrong_argument_count_or_agent_prints_the_usage_and_makes_nothing(run_add, registry, tmp_path, argument_list):
    exit_code, out, err = run_add(argument_list)

    assert exit_code == 2
    assert out == ""
    assert err == USAGE_TEXT + "\n"
    assert _registry_names(registry) == []


# --------------------------------------------------------------------------------

def test_an_unknown_agent_is_a_usage_error_before_any_other_refusal(run_add, tmp_path):
    exit_code, _, err = run_add(["Bad_Name", "rel/x", "opencode"])

    assert exit_code == 2
    assert err == USAGE_TEXT + "\n"


# --------------------------------------------------------------------------------
# The image tag and the name
# --------------------------------------------------------------------------------

def test_the_test_tag_prints_its_notice_and_registers(run_add, registry, tmp_path):
    exit_code, _, err = run_add(["sbx1", str(tmp_path / "x1")], {"SBX_IMAGE_TAG": "test"})

    assert exit_code == 0
    assert err == (
        "sbx-add: using the test images because SBX_IMAGE_TAG=test; "
        "unset it to use the local images your sandboxes run\n"
    )
    assert (registry / "sbx1.json").is_file()


# --------------------------------------------------------------------------------

def test_a_tag_other_than_local_or_test_is_refused_before_anything_is_made(run_add, registry, tmp_path):
    exit_code, _, err = run_add(["sbx1", str(tmp_path / "x1")], {"SBX_IMAGE_TAG": "latest"})

    assert exit_code == 1
    assert err == "sbx-add: SBX_IMAGE_TAG must be local or test, not 'latest'\n"
    assert not (tmp_path / "x1").exists()
    assert _registry_names(registry) == []


# --------------------------------------------------------------------------------

@pytest.mark.parametrize(
    "name",
    ["MyProject", "my_project", "../x", "", "abcdefghijklmnopqrstuvwxyzabcdef", "ok\nbad", "caf\u00e9", "1abc"],
)
def test_a_name_that_breaks_the_rule_is_refused_and_nothing_is_made(run_add, registry, tmp_path, name):
    exit_code, _, err = run_add([name, str(tmp_path / "x1")])

    assert exit_code == 1
    assert RULE_TEXT in err
    assert not (tmp_path / "x1").exists()
    assert _registry_names(registry) == []


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("name", ["state", "best-practices"])
def test_a_reserved_name_is_refused(run_add, registry, tmp_path, name):
    exit_code, _, err = run_add([name, str(tmp_path / "x1")])

    assert exit_code == 1
    assert f"'{name}' is taken" in err
    assert _registry_names(registry) == []


# --------------------------------------------------------------------------------
# A name that is already registered
# --------------------------------------------------------------------------------

def test_a_second_add_of_a_registered_name_leaves_the_file_bytes_unchanged(run_add, registry, tmp_path):
    run_add(["sbx1", str(tmp_path / "x1")])
    entry = registry / "sbx1.json"
    before = entry.read_bytes()

    exit_code, _, err = run_add(["sbx1", str(tmp_path / "x2")])

    assert exit_code == 1
    assert err == f"sbx-add: sbx1 is already registered in {entry}; nothing was changed\n"
    assert entry.read_bytes() == before
    assert not (tmp_path / "x2").exists()


# --------------------------------------------------------------------------------

def test_the_registered_check_comes_before_the_host_path_check(run_add, registry, tmp_path):
    run_add(["sbx1", str(tmp_path / "x1")])

    exit_code, _, err = run_add(["sbx1", "rel/path"])

    assert exit_code == 1
    assert "is already registered" in err


# --------------------------------------------------------------------------------
# The host path text
# --------------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("path", "text"),
    [
        ("rel/dir", "is not an absolute path"),
        ("", "the host path is empty"),
        ("{tmp}/p\nq", "the host path has a line break"),
        ("{tmp}/p/../q", "has an empty, . or .. part"),
        ("{tmp}/p/./q", "has an empty, . or .. part"),
        ("{tmp}/p//q", "has an empty, . or .. part"),
    ],
)
def test_a_bad_host_path_is_refused_with_the_bash_wording_and_nothing_is_made(
    run_add, registry, tmp_path, path, text
):
    exit_code, _, err = run_add(["sbx1", path.replace("{tmp}", str(tmp_path))])

    assert exit_code == 1
    assert text in err
    assert not (tmp_path / "p").exists()
    assert _registry_names(registry) == []


# --------------------------------------------------------------------------------

def test_the_text_check_runs_before_any_overlap_check(run_add, config_dir, tmp_path):
    exit_code, _, err = run_add(["sbx1", f"{config_dir}/../x"])

    assert exit_code == 1
    assert "has an empty, . or .. part" in err
    assert "overlaps" not in err


# --------------------------------------------------------------------------------
# The registry directory and the tools clone
# --------------------------------------------------------------------------------

def test_the_root_directory_is_refused_because_it_holds_the_registry(run_add, config_dir, registry):
    exit_code, _, err = run_add(["sbx1", "/"])

    assert exit_code == 1
    assert err == (
        f"sbx-add: '/' overlaps the registry directory {config_dir}; "
        "a sandbox there could change the registry. Pick another directory.\n"
    )
    assert _registry_names(registry) == []


# --------------------------------------------------------------------------------

def test_a_directory_that_holds_the_registry_is_refused(run_add, tmp_path, registry):
    exit_code, _, err = run_add(["sbx1", str(tmp_path)])

    assert exit_code == 1
    assert "overlaps the registry directory" in err


# --------------------------------------------------------------------------------

def test_a_directory_inside_the_registry_directory_is_refused_and_not_made(run_add, config_dir, registry):
    exit_code, _, err = run_add(["sbx1", f"{config_dir}/inside"])

    assert exit_code == 1
    assert "overlaps the registry directory" in err
    assert not (config_dir / "inside").exists()


# --------------------------------------------------------------------------------

def test_a_symlink_to_the_registry_directory_is_refused(run_add, config_dir, tmp_path, registry):
    (tmp_path / "link1").symlink_to(config_dir)

    exit_code, _, err = run_add(["sbx1", f"{tmp_path}/link1/inside"])

    assert exit_code == 1
    assert "overlaps the registry directory" in err


# --------------------------------------------------------------------------------

def test_a_registry_directory_not_made_yet_is_compared_without_letter_case(run_add, tmp_path):
    exit_code, _, err = run_add(
        ["sbx1", f"{tmp_path}/CFG-NOTYET/inside"],
        {"SBX_CONFIG_DIR": f"{tmp_path}/cfg-notyet"},
    )

    assert exit_code == 1
    assert "overlaps the registry directory" in err


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("relative_path", ["", "inside"])
def test_the_tools_clone_and_a_directory_inside_it_are_refused_and_nothing_is_made(
    run_add, repo_dir, registry, relative_path
):
    path = f"{repo_dir}/{relative_path}".rstrip("/")

    exit_code, _, err = run_add(["sbx1", path])

    assert exit_code == 1
    assert err == (
        f"sbx-add: '{path}' overlaps the tools clone {repo_dir}; "
        "a sandbox there could change the scripts the host runs. Pick another directory.\n"
    )
    assert not (repo_dir / "state").exists()
    assert not (repo_dir / "inside").exists()
    assert _registry_names(registry) == []


# --------------------------------------------------------------------------------

def test_a_directory_that_holds_the_tools_clone_through_a_symlink_is_refused(run_add, repo_dir, tmp_path):
    (tmp_path / "link1").symlink_to(repo_dir)

    exit_code, _, err = run_add(["sbx1", f"{tmp_path}/link1/inside"])

    assert exit_code == 1
    assert "overlaps the tools clone" in err
    assert not (repo_dir / "inside").exists()


# --------------------------------------------------------------------------------

def test_a_directory_that_only_shares_a_text_prefix_with_the_tools_clone_is_accepted(run_add, tmp_path):
    exit_code, _, _ = run_add(["sbx1", str(tmp_path / "tools1-other")])

    assert exit_code == 0


# --------------------------------------------------------------------------------
# Other sandboxes
# --------------------------------------------------------------------------------

@pytest.fixture
def sandbox_demo(run_add, tmp_path):
    path = tmp_path / "sbx one"
    run_add(["demo", str(path)])

    return path


# --------------------------------------------------------------------------------

def test_the_directory_of_another_sandbox_is_refused(run_add, registry, sandbox_demo):
    exit_code, _, err = run_add(["sbx2", str(sandbox_demo)])

    assert exit_code == 1
    assert err == (
        f"sbx-add: '{sandbox_demo}' overlaps the directory of sandbox demo ({sandbox_demo}); "
        "each sandbox needs its own directory.\n"
    )
    assert _registry_names(registry) == ["demo.json"]


# --------------------------------------------------------------------------------

def test_a_path_inside_another_sandbox_directory_is_refused_and_not_made(run_add, sandbox_demo):
    exit_code, _, err = run_add(["sbx2", str(sandbox_demo / "inner")])

    assert exit_code == 1
    assert "overlaps the directory of sandbox demo" in err
    assert not (sandbox_demo / "inner").exists()


# --------------------------------------------------------------------------------

def test_a_path_that_holds_another_sandbox_directory_is_refused(run_add, tmp_path):
    run_add(["deep", str(tmp_path / "a" / "b" / "c")])

    exit_code, _, err = run_add(["holder", str(tmp_path / "a")])

    assert exit_code == 1
    assert "overlaps the directory of sandbox deep" in err
    assert not (tmp_path / "a" / "state").exists()


# --------------------------------------------------------------------------------

def test_a_symlink_to_another_sandbox_directory_is_refused(run_add, tmp_path, sandbox_demo):
    (tmp_path / "link to one").symlink_to(sandbox_demo)

    exit_code, _, err = run_add(["sbx2", str(tmp_path / "link to one")])

    assert exit_code == 1
    assert "overlaps the directory of sandbox demo" in err


# --------------------------------------------------------------------------------

def test_a_directory_inside_a_symlink_to_another_sandbox_directory_is_refused(run_add, tmp_path, sandbox_demo):
    (tmp_path / "link to one").symlink_to(sandbox_demo)

    exit_code, _, err = run_add(["sbx2", str(tmp_path / "link to one" / "inner")])

    assert exit_code == 1
    assert "overlaps the directory of sandbox demo" in err
    assert not (sandbox_demo / "inner").exists()


# --------------------------------------------------------------------------------

def test_a_path_that_only_shares_a_text_prefix_with_another_sandbox_is_accepted(run_add, tmp_path, sandbox_demo):
    exit_code, _, _ = run_add(["sbx2", str(tmp_path / "sbx one-other")])

    assert exit_code == 0


# --------------------------------------------------------------------------------

def test_a_broken_other_entry_stops_the_add_with_its_own_error(run_add, registry, tmp_path):
    (registry / "broken.json").write_text("not json", encoding="utf-8")

    exit_code, _, err = run_add(["sbx1", str(tmp_path / "x1")])

    assert exit_code == 1
    assert err == f"sbx-add: the entry {registry / 'broken.json'} is not a JSON object\n"
    assert not (tmp_path / "x1").exists()
    assert _registry_names(registry) == ["broken.json"]


# --------------------------------------------------------------------------------

def test_the_first_refusal_in_byte_order_of_the_other_names_is_the_one_printed(run_add, registry, tmp_path):
    write_json_entry(registry, "b-other", str(tmp_path / "x1"), "claude")
    (registry / "a-broken.json").write_text("[]", encoding="utf-8")

    exit_code, _, err = run_add(["sbx1", str(tmp_path / "x1")])

    assert exit_code == 1
    assert "a-broken.json is not a JSON object" in err


# --------------------------------------------------------------------------------

def test_the_registry_overlap_is_checked_before_the_tools_clone_and_the_sandboxes(
    run_add, config_dir, registry
):
    write_json_entry(registry, "other", f"{config_dir}/inside", "claude")

    exit_code, _, err = run_add(["sbx1", f"{config_dir}/inside"])

    assert exit_code == 1
    assert "overlaps the registry directory" in err


# --------------------------------------------------------------------------------
# A directory that cannot be made
# --------------------------------------------------------------------------------

def test_a_directory_that_cannot_be_made_is_refused_and_no_entry_is_written(run_add, registry, tmp_path):
    blocker = tmp_path / "blocker1"
    blocker.write_text("a file, not a directory")

    exit_code, _, err = run_add(["sbx1", str(blocker / "inside")])

    assert exit_code == 1
    assert err == f"sbx-add: could not create {blocker}/inside/sbx1 and {blocker}/inside/state\n"
    assert _registry_names(registry) == []
