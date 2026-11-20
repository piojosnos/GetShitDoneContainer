# ------------------------------------------------------------------------------
# Tests of the names: sandbox name rule, agents, image tag, image names
# ------------------------------------------------------------------------------
# Plain calls with a plain environment mapping; nothing here touches the disk.
# ------------------------------------------------------------------------------

import pytest

from sbx.cli import SbxError
from sbx.names import NAME_RULE_TEXT, agent_image, base_image, check_name, container_name, image_tag, is_known_agent

VALID_NAME_LIST = ["a", "my-project", "a" * 31, "a-1", "a1b2"]
BROKEN_NAME_LIST = [
    "",
    "HostTest",
    "my_project",
    "../x",
    "a" * 32,
    "a\nb",
    "a\n",
    "caf\u00e9",
    "1abc",
    "-a",
    "a b",
]
RESERVED_NAME_LIST = ["state", "best-practices"]


# ------------------------------------------------------------------------------
# The sandbox name rule
# ------------------------------------------------------------------------------

@pytest.mark.parametrize("name", VALID_NAME_LIST)
def test_a_name_that_follows_the_rule_passes(name):
    check_name(name)


@pytest.mark.parametrize("name", BROKEN_NAME_LIST)
def test_a_name_that_breaks_the_rule_is_refused_with_the_rule_text(name):
    with pytest.raises(SbxError) as excinfo:
        check_name(name)

    assert str(excinfo.value) == f"'{name}' breaks the sandbox name rule: {NAME_RULE_TEXT}. Example: my-project."


@pytest.mark.parametrize("name", RESERVED_NAME_LIST)
def test_a_reserved_name_is_refused(name):
    with pytest.raises(SbxError) as excinfo:
        check_name(name)

    assert str(excinfo.value) == (
        f"'{name}' is taken: the sandbox directory uses {name}/ itself. Pick another name."
    )


# ------------------------------------------------------------------------------
# The agent and the image names
# ------------------------------------------------------------------------------

@pytest.mark.parametrize("agent", ["claude", "cursor"])
def test_a_known_agent_is_known(agent):
    assert is_known_agent(agent)


@pytest.mark.parametrize("agent", ["", "Claude", "codex", "claude cursor"])
def test_any_other_agent_is_not_known(agent):
    assert not is_known_agent(agent)


def test_the_image_and_container_names_follow_the_agent_and_tag():
    assert agent_image("claude", "local") == "sbx-claude:local"
    assert agent_image("cursor", "test") == "sbx-cursor:test"
    assert base_image("test") == "sbx-base:test"
    assert container_name("sbx1") == "sbx-sbx1"


# ------------------------------------------------------------------------------
# The image tag
# ------------------------------------------------------------------------------

@pytest.mark.parametrize("environ", [{}, {"SBX_IMAGE_TAG": ""}, {"SBX_IMAGE_TAG": "local"}])
def test_an_unset_empty_or_local_tag_is_local_and_quiet(environ, capsys):
    assert image_tag(environ, "sbx-list") == "local"
    assert capsys.readouterr().err == ""


def test_the_test_tag_is_accepted_and_named_on_stderr(capsys):
    assert image_tag({"SBX_IMAGE_TAG": "test"}, "sbx-list") == "test"
    assert capsys.readouterr().err == (
        "sbx-list: using the test images because SBX_IMAGE_TAG=test; "
        "unset it to use the local images your sandboxes run\n"
    )


@pytest.mark.parametrize("tag", ["latest", "Local", "test "])
def test_any_other_tag_is_refused(tag):
    with pytest.raises(SbxError) as excinfo:
        image_tag({"SBX_IMAGE_TAG": tag}, "sbx-list")

    assert str(excinfo.value) == f"SBX_IMAGE_TAG must be local or test, not '{tag}'"
