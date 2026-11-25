# --------------------------------------------------------------------------------
# Guard rules on the container start: no entrypoint, agent image, tag
# --------------------------------------------------------------------------------

from guard_helpers import REPO_DIR, compose_file, dockerfile_list, nowhere_matches

_COMPOSE_IMAGE_LINE = 'image: "sbx-${SBX_AGENT:-claude}:${SBX_IMAGE_TAG:-local}"'


# --------------------------------------------------------------------------------
# Rule container_runs_no_entrypoint: a start only keeps the container alive
# --------------------------------------------------------------------------------
# sbx-init, run in a shell, sets the sandbox up. An entrypoint in an image or in
# compose would bring back setup that runs without anyone asking.
# --------------------------------------------------------------------------------

def test_container_runs_no_entrypoint():
    problem_list = []
    compose_text = compose_file().read_text(encoding="utf-8")

    if nowhere_matches(r"^ENTRYPOINT", dockerfile_list()):
        problem_list.append("a Dockerfile sets an entrypoint")

    if nowhere_matches(r"^\s*entrypoint:", [compose_file()]):
        problem_list.append("compose.yml sets an entrypoint")

    if "init: true" not in compose_text:
        problem_list.append('compose.yml does not keep "init: true"')

    if 'command: ["sleep", "infinity"]' not in compose_text:
        problem_list.append('compose.yml does not keep the command ["sleep", "infinity"]')

    assert not problem_list, "\n".join(problem_list)


# --------------------------------------------------------------------------------
# Rule agents_stay_off_the_path: only the agent wrappers start an agent
# --------------------------------------------------------------------------------
# The agents live in /opt/sbx/agents/bin so only their agent wrappers start them;
# a link in /usr/local/bin would let a plain shell run an uninitialized agent.
# --------------------------------------------------------------------------------

def test_agents_stay_off_the_path():
    problem_list = []
    claude_dockerfile = REPO_DIR / "claude" / "Dockerfile"
    cursor_dockerfile = REPO_DIR / "cursor" / "Dockerfile"
    claude_text = claude_dockerfile.read_text(encoding="utf-8")
    cursor_text = cursor_dockerfile.read_text(encoding="utf-8")

    if "/opt/sbx/agents/bin/claude --version" not in claude_text or "! command -v claude" not in claude_text:
        problem_list.append(
            "claude/Dockerfile has no smoke test that runs claude from /opt/sbx/agents/bin "
            "and fails when it is on the PATH"
        )

    if "/opt/sbx/agents/bin/cursor-agent --version" not in cursor_text or "! command -v cursor-agent" not in cursor_text:
        problem_list.append(
            "cursor/Dockerfile has no smoke test that runs cursor-agent from /opt/sbx/agents/bin "
            "and fails when it is on the PATH"
        )

    link_hit_list = nowhere_matches(
        r"ln -s [^ ]+ /usr/local/bin/(claude|cursor-agent)", [claude_dockerfile, cursor_dockerfile]
    )

    if link_hit_list:
        problem_list.append("an agent Dockerfile links its agent into /usr/local/bin")
        problem_list += link_hit_list

    assert not problem_list, "\n".join(problem_list)


# --------------------------------------------------------------------------------
# Rule compose_image_follows_agent_and_tag: the agent and the tag pick the image
# --------------------------------------------------------------------------------
# compose.yml falls back to claude and local when a variable is unset, so a lost
# hand-off would start a Cursor sandbox on the Claude image, or a test sandbox
# on the images the user's sandboxes run. This rule keeps the image line of
# compose.yml. The hand-offs of the agent and the tag to Compose and the build of
# one image per agent on the base of its own tag are unit tests in tests/unit/sbx/
# (test_sbx_compose.py and test_sbx_build.py).
# --------------------------------------------------------------------------------

def test_compose_image_follows_agent_and_tag():
    compose_text = compose_file().read_text(encoding="utf-8")

    assert _COMPOSE_IMAGE_LINE in compose_text, (
        'compose.yml does not take its image from "sbx-${SBX_AGENT:-claude}:${SBX_IMAGE_TAG:-local}"'
    )
