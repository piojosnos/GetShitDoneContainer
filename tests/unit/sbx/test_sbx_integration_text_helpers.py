# --------------------------------------------------------------------------------
# Tests of the text and plan helpers in the first-run, owner-fix, image and pin
# digest scenarios
# --------------------------------------------------------------------------------
# The scenarios themselves need Docker. The pure helpers they read command output
# and versions.env with are checked here without it, so a mistake in one shows in
# the dev sandbox and not only on the host.
# --------------------------------------------------------------------------------

import subprocess

import claude_shared
import cursor_shared
import test_first_run_and_relink as first_run
import test_images_match_versions as images_match
import test_owner_fix as owner_fix
import test_pin_digests as pin_digests
from agent_specs import CLAUDE_SPEC, CURSOR_SPEC
from sbx.build import read_pins
from scenario_helpers import REPO_DIR

_DIGEST_1 = "sha256:" + "1" * 64
_DIGEST_2 = "sha256:" + "2" * 64


# --------------------------------------------------------------------------------
# Reading command output
# --------------------------------------------------------------------------------

def test_last_line_is_the_final_non_blank_line():
    assert first_run._last_line("a\nb\n\n") == "b"
    assert first_run._last_line("") == ""
    assert first_run._last_line("only") == "only"


# --------------------------------------------------------------------------------

def test_line_starting_with_finds_the_first_match_or_none():
    text = "OK: step-1: fine\nFAIL: step-2: broken\nFAIL: step-3: also broken\n"

    assert first_run._line_starting_with(text, "FAIL: step-") == "FAIL: step-2: broken"
    assert first_run._line_starting_with(text, "FAIL: step-9") is None


# --------------------------------------------------------------------------------

def test_fix_line_must_be_a_fix_line_that_names_the_word():
    text = "FAIL: step-1: run word-1 first\n  fix: run word-1, then word-2\n"

    assert first_run._fix_line_naming(text, "word-2") == "fix: run word-1, then word-2"
    assert first_run._fix_line_naming(text, "word-3") is None
    assert first_run._fix_line_naming("FAIL: step-1: run word-1 first\n", "word-1") is None


# --------------------------------------------------------------------------------
# What a link reaches
# --------------------------------------------------------------------------------

def test_live_target_exists_in_the_fixture_for_each_agent():
    for agent in [CLAUDE_SPEC, CURSOR_SPEC]:
        live_dir, live_file = first_run._live_target(agent)
        live_path = first_run._SUPPORT_DIR / first_run._generated_dir(agent) / live_dir / live_file

        assert live_path.is_file(), f"{agent.name}: {live_dir}/{live_file}"


# --------------------------------------------------------------------------------

def test_the_generated_live_file_differs_from_the_master_for_each_agent():
    master_text = (first_run._SUPPORT_DIR / "rules" / "sbx-fixture-always.md").read_text(encoding="utf-8")

    for agent in [CLAUDE_SPEC, CURSOR_SPEC]:
        live_dir, live_file = first_run._live_target(agent)
        live_path = first_run._SUPPORT_DIR / first_run._generated_dir(agent) / live_dir / live_file

        assert live_path.read_text(encoding="utf-8") != master_text, agent.name


# --------------------------------------------------------------------------------

def test_kept_and_dropped_skills_are_the_fixture_skills():
    for agent in [CLAUDE_SPEC, CURSOR_SPEC]:
        assert first_run._fixture_skill_name_list(agent) == [first_run._KEPT_SKILL, first_run._DROPPED_SKILL], agent.name


# --------------------------------------------------------------------------------

def test_each_agent_spec_names_the_agent_of_its_image():
    assert CLAUDE_SPEC.name == claude_shared.AGENT_NAME
    assert CURSOR_SPEC.name == cursor_shared.AGENT_NAME


# --------------------------------------------------------------------------------

def test_stand_in_session_script_parses_and_names_the_agent():
    for agent in [CLAUDE_SPEC, CURSOR_SPEC]:
        script = first_run._stand_in_session_script(agent)
        parsed = subprocess.run(["bash", "-n", "-c", script], capture_output=True, text=True)

        assert parsed.returncode == 0, parsed.stderr
        assert f"SBX_AGENT_BIN_DIR={first_run._STAND_IN_DIR} {agent.wrapper}" in script
        assert f"command -v {agent.binary}" in script
        assert "${PATH#" + first_run._STAND_IN_DIR + ":}" in script


# --------------------------------------------------------------------------------
# Root-owned state
# --------------------------------------------------------------------------------

def test_root_owned_search_skips_exactly_the_cache_directories():
    command = owner_fix._root_owned_command()

    assert command.startswith("find /home/sandbox/workspace/state -user 0")

    for skipped_path in ["*/state/cache/npm*", "*/state/cache/uv*", "*/state/m2*"]:
        assert f"-not -path '{skipped_path}'" in command


# --------------------------------------------------------------------------------
# The image record
# --------------------------------------------------------------------------------

def test_diff_text_names_the_image_and_stops_at_the_limit():
    record_text = "".join(f"A_{number}=1\n" for number in range(100))
    repo_text = "".join(f"A_{number}=2\n" for number in range(100))
    diff_text = images_match._diff_text(record_text, repo_text, "image-1")

    assert "image-1:/etc/sbx/versions.env" in diff_text
    assert len(diff_text.splitlines()) == images_match._DIFF_LINE_LIMIT


# --------------------------------------------------------------------------------
# The digest pins
# --------------------------------------------------------------------------------

def test_pinned_image_map_keeps_only_digest_pins():
    pin_map = {
        "IMAGE_A": f"registry-1/name-1:tag-1@{_DIGEST_1}",
        "TOOL_VERSION": "1.2.3",
        "IMAGE_B": f"registry-2/name-2:tag-2@{_DIGEST_2}",
        "IMAGE_C": "registry-3/name-3:tag-3@sha256:abc",
        "image_d": f"registry-4/name-4:tag-4@{_DIGEST_1}",
        "IMAGE_E_1": f"registry-5/name-5:tag-5@{_DIGEST_1}",
    }

    assert pin_digests._pinned_image_map(pin_map) == {
        "IMAGE_A": ("registry-1/name-1:tag-1", _DIGEST_1),
        "IMAGE_B": ("registry-2/name-2:tag-2", _DIGEST_2),
    }


# --------------------------------------------------------------------------------

def test_the_real_versions_file_yields_digest_pins_with_the_digest_split_off():
    pinned_image_map = pin_digests._pinned_image_map(read_pins(REPO_DIR / "versions.env"))

    assert "UBUNTU_IMAGE" in pinned_image_map
    assert "NODE_VERSION" not in pinned_image_map

    for pin_name, (image, digest) in pinned_image_map.items():
        assert "@" not in image, pin_name
        assert digest.startswith("sha256:"), pin_name


# --------------------------------------------------------------------------------

def test_digest_comes_from_the_digest_line_of_the_inspect_output():
    inspect_text = f"Name:      registry-1/name-1:tag-1\nMediaType: type-1\nDigest:    {_DIGEST_1}\n"

    assert pin_digests._digest_from_inspect(inspect_text) == _DIGEST_1
    assert pin_digests._digest_from_inspect("ERROR: not found\n") == ""
    assert pin_digests._digest_from_inspect("") == ""


# --------------------------------------------------------------------------------

def test_pin_result_line_is_a_pass_an_info_or_a_fail():
    same = pin_digests._pin_result_line("PIN_A", "image-1", _DIGEST_1, _DIGEST_1)
    moved = pin_digests._pin_result_line("PIN_A", "image-1", _DIGEST_1, _DIGEST_2)
    gone = pin_digests._pin_result_line("PIN_A", "image-1", _DIGEST_1, "")

    assert same == f"PASS: PIN_A {_DIGEST_1}"
    assert moved.startswith("INFO: PIN_A pins ")
    assert _DIGEST_1 in moved and _DIGEST_2 in moved
    assert gone == "FAIL: PIN_A: the registry did not resolve image-1"
