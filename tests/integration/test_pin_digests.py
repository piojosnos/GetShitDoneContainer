# --------------------------------------------------------------------------------
# Test: every digest pin in versions.env still resolves in its registry
# --------------------------------------------------------------------------------
# The one integration test that is not per agent: it reads versions.env and starts
# no sandbox. A tag the registry no longer resolves is a problem. A tag that now
# points at another digest is only news: the pin still pulls the image it names, so
# the test prints an INFO line and passes.
# --------------------------------------------------------------------------------

import re

from sbx.build import read_pins
from scenario_helpers import REPO_DIR, progress, run_timeout, step

_INSPECT_COMMAND = "docker buildx imagetools inspect"
_INSPECT_SECONDS = 120
_PIN_NAME_PATTERN = re.compile(r"[A-Z_]+")
_PIN_VALUE_PATTERN = re.compile(r"([^ ]+)@(sha256:[0-9a-f]{64})")


# --------------------------------------------------------------------------------
# The pins and the registry's answer
# --------------------------------------------------------------------------------

def _pinned_image_map(pin_map: dict[str, str]) -> dict[str, tuple[str, str]]:
    pinned_image_map = {}

    for pin_name, pin_value in pin_map.items():
        name_match = _PIN_NAME_PATTERN.fullmatch(pin_name)
        value_match = _PIN_VALUE_PATTERN.fullmatch(pin_value)

        if name_match is None or value_match is None:
            continue

        pinned_image_map[pin_name] = (value_match.group(1), value_match.group(2))

    return pinned_image_map


# --------------------------------------------------------------------------------

def _digest_from_inspect(inspect_text: str) -> str:
    for line in inspect_text.splitlines():
        if line.startswith("Digest:"):
            return line.partition(":")[2].strip()

    return ""


# --------------------------------------------------------------------------------

def _pin_result_line(pin_name: str, image: str, wanted_digest: str, found_digest: str) -> str:
    if not found_digest:
        return f"FAIL: {pin_name}: the registry did not resolve {image}"

    if found_digest == wanted_digest:
        return f"PASS: {pin_name} {wanted_digest}"

    return (
        f"INFO: {pin_name} pins {wanted_digest}, the registry now has {found_digest} "
        "(a newer image; bump the pin when convenient)"
    )


# --------------------------------------------------------------------------------
# test_every_pinned_digest_resolves
# --------------------------------------------------------------------------------
# every NAME=image@sha256 pin -> the registry still resolves its tag
# --------------------------------------------------------------------------------

def test_every_pinned_digest_resolves():
    problem_list = []

    with step("read the digest pins of versions.env"):
        pinned_image_map = _pinned_image_map(read_pins(REPO_DIR / "versions.env"))

        assert pinned_image_map, "versions.env holds no NAME=image@sha256 pin"

    with step("ask each registry for the tag's digest"):
        for pin_name, (image, wanted_digest) in pinned_image_map.items():
            inspected = run_timeout([*_INSPECT_COMMAND.split(), image], _INSPECT_SECONDS)
            result_line = _pin_result_line(pin_name, image, wanted_digest, _digest_from_inspect(inspected.stdout))

            progress(result_line)

            if result_line.startswith("FAIL: "):
                problem_list.append(result_line)

        assert not problem_list, "\n".join(problem_list)
