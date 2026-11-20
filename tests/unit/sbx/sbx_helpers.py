# ------------------------------------------------------------------------------
# Plain helpers the sbx unit tests share
# ------------------------------------------------------------------------------
# The repo directory, a recorder that stands in for the Docker function, the
# environment a command gets and a writer of registry files.
# ------------------------------------------------------------------------------

import json
from collections.abc import Mapping
from pathlib import Path

from sbx.docker import DockerResult

REPO_DIR = Path(__file__).resolve().parents[3]


# ------------------------------------------------------------------------------
# Docker stand-in
# ------------------------------------------------------------------------------
# It has the signature of run_docker. It notes each argument list and answers
# from the longest prefix it was told about, else with success and no output.
# ------------------------------------------------------------------------------

class DockerRecorder:
    def __init__(self) -> None:
        self.call_list: list[list[str]] = []
        self._answer_map: dict[tuple[str, ...], DockerResult] = {}

    def answer(self, prefix_list: list[str], result: DockerResult) -> None:
        self._answer_map[tuple(prefix_list)] = result

    def __call__(
        self,
        argument_list: list[str],
        environ: Mapping[str, str] | None = None,
        capture: bool = True,
    ) -> DockerResult:
        self.call_list.append(list(argument_list))
        best_prefix: tuple[str, ...] | None = None

        for prefix in self._answer_map:
            if tuple(argument_list[: len(prefix)]) != prefix:
                continue

            if best_prefix is None or len(prefix) > len(best_prefix):
                best_prefix = prefix

        if best_prefix is None:
            return DockerResult(0, "")

        return self._answer_map[best_prefix]


# ------------------------------------------------------------------------------
# Environment and registry files
# ------------------------------------------------------------------------------

def environ_for(config: Path, extra_map: dict[str, str] | None = None) -> dict[str, str]:
    environ = {"SBX_CONFIG_DIR": str(config)}

    if extra_map:
        environ.update(extra_map)

    return environ


def write_json_entry(registry: Path, name: str, path: str, agent: str) -> Path:
    registry.mkdir(parents=True, exist_ok=True)
    file = registry / f"{name}.json"
    file.write_text(json.dumps({"path": path, "agent": agent}), encoding="utf-8")

    return file
