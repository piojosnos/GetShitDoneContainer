# --------------------------------------------------------------------------------
# Tests of build.sh as the sbx.build module
# --------------------------------------------------------------------------------
# Docker is the recorder. The extra root certificate cases use the real openssl on
# files made under tmp_path. The last test reads the three Dockerfiles, so a bare
# docker build that lacks a pin is proven to name it without running Docker.
# --------------------------------------------------------------------------------

import os
import subprocess
from pathlib import Path

import pytest

from sbx import build as build_module
from sbx.docker import DockerResult
from sbx.names import KNOWN_AGENT_LIST
from sbx_helpers import REPO_DIR, DockerRecorder

STAR_LINE = "*" * 78
VERSIONS_TEXT = (
    "# a comment\n"
    "\n"
    "UBUNTU_IMAGE=ubuntu:24.04@sha256:abc\n"
    "NODE_VERSION=24.21.0\n"
    "# another comment\n"
    "BEST_PRACTICES_REPO_URL=https://example.com/one.git\n"
)
TAG_RULE_TEXT = "build.sh: SBX_IMAGE_TAG must be local or test, not 'latest'\n"


# --------------------------------------------------------------------------------
# Fixtures and helpers
# --------------------------------------------------------------------------------

@pytest.fixture
def repo_dir(tmp_path) -> Path:
    repo1 = tmp_path / "repo1"
    repo1.mkdir()
    (repo1 / "versions.env").write_text(VERSIONS_TEXT, encoding="utf-8")

    return repo1


# --------------------------------------------------------------------------------

@pytest.fixture
def run_build(repo_dir, recorder, capsys):
    def run(argument_list, extra_map=None, docker=None):
        environ = {"PATH": os.environ["PATH"]}

        if extra_map:
            environ.update(extra_map)

        exit_code = build_module.main(argument_list, environ, docker=docker or recorder, repo_dir=repo_dir)
        captured = capsys.readouterr()

        return exit_code, captured.out, captured.err

    return run


# --------------------------------------------------------------------------------

def _make_certificate(directory: Path, name: str) -> tuple[Path, Path]:
    key_file = directory / f"{name}.key"
    cert_file = directory / f"{name}.crt"

    subprocess.run(
        [
            "openssl", "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes",
            "-keyout", str(key_file), "-out", str(cert_file), "-subj", f"/CN={name}", "-days", "1",
        ],
        check=True,
        capture_output=True,
    )

    return key_file, cert_file


# --------------------------------------------------------------------------------

def _openssl_fingerprint(cert_file: Path) -> str:
    result = subprocess.run(
        ["openssl", "x509", "-noout", "-fingerprint", "-sha256", "-in", str(cert_file)],
        check=True,
        capture_output=True,
        text=True,
    )

    return result.stdout.strip().split("=", 1)[1].replace(":", "").upper()


# --------------------------------------------------------------------------------

class CertInspector(DockerRecorder):
    # Looks at the certificate directory while the first build runs, since the
    # command removes the directory when it is done.
    def __init__(self) -> None:
        super().__init__()
        self.cert_file_map: dict[str, str] = {}

    # --------------------------------------------------------------------------------

    def __call__(self, argument_list, environ=None, capture=True):
        if not self.call_list and "--build-context" in argument_list:
            context_text = argument_list[argument_list.index("--build-context") + 1]
            cert_dir = Path(context_text.split("=", 1)[1])

            for file in sorted(cert_dir.iterdir()):
                self.cert_file_map[file.name] = file.read_text(encoding="utf-8")

        return super().__call__(argument_list, environ, capture)


# --------------------------------------------------------------------------------

@pytest.fixture
def bundle(tmp_path) -> tuple[Path, list[Path]]:
    work_dir = tmp_path / "pems"
    work_dir.mkdir()
    key_file, cert_file1 = _make_certificate(work_dir, "one")
    _, cert_file2 = _make_certificate(work_dir, "two")
    bundle_file = work_dir / "bundle.pem"
    bundle_file.write_text(
        key_file.read_text() + cert_file1.read_text() + "text between\n" + cert_file2.read_text(),
        encoding="utf-8",
    )

    return bundle_file, [cert_file1, cert_file2]


# --------------------------------------------------------------------------------
# read_pins
# --------------------------------------------------------------------------------

def test_read_pins_returns_the_pairs_in_file_order_and_skips_comments_and_blank_lines(repo_dir):
    pin_map = build_module.read_pins(repo_dir / "versions.env")

    assert list(pin_map.items()) == [
        ("UBUNTU_IMAGE", "ubuntu:24.04@sha256:abc"),
        ("NODE_VERSION", "24.21.0"),
        ("BEST_PRACTICES_REPO_URL", "https://example.com/one.git"),
    ]


# --------------------------------------------------------------------------------

def test_read_pins_keeps_a_command_substitution_as_text_and_runs_nothing(tmp_path):
    versions_file = tmp_path / "versions.env"
    versions_file.write_text("NODE_VERSION=$(touch pwned)\nOTHER_VERSION=`touch pwned2`\n", encoding="utf-8")

    pin_map = build_module.read_pins(versions_file)

    assert pin_map == {"NODE_VERSION": "$(touch pwned)", "OTHER_VERSION": "`touch pwned2`"}
    assert not (tmp_path / "pwned").exists()
    assert not (Path.cwd() / "pwned").exists()


# --------------------------------------------------------------------------------
# The refusals before any build
# --------------------------------------------------------------------------------

def test_a_tag_other_than_local_or_test_is_refused_before_versions_env_is_read(run_build, repo_dir, recorder):
    (repo_dir / "versions.env").unlink()

    exit_code, out, err = run_build([], {"SBX_IMAGE_TAG": "latest"})

    assert exit_code == 1
    assert out == ""
    assert err == TAG_RULE_TEXT
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

def test_a_missing_versions_env_is_refused(run_build, repo_dir, recorder):
    (repo_dir / "versions.env").unlink()

    exit_code, out, err = run_build([])

    assert exit_code == 1
    assert out == ""
    assert err == "build.sh: versions.env is missing next to build.sh\n"
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

def test_a_versions_env_without_a_pin_is_refused(run_build, repo_dir, recorder):
    (repo_dir / "versions.env").write_text("# nothing here\n\n", encoding="utf-8")

    exit_code, out, err = run_build([])

    assert exit_code == 1
    assert out == ""
    assert err == "build.sh: versions.env holds no pins\n"
    assert recorder.call_list == []


# --------------------------------------------------------------------------------
# The tag and the order of the builds
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("extra_map", [{}, {"SBX_IMAGE_TAG": ""}])
def test_an_unset_or_empty_tag_builds_the_local_images_without_a_notice(run_build, recorder, extra_map):
    exit_code, out, err = run_build([], extra_map)

    assert exit_code == 0
    assert out.splitlines() == [
        "build.sh: building sbx-base:local",
        "build.sh: building sbx-claude:local",
        "build.sh: building sbx-cursor:local",
    ]
    assert err == ""
    assert len(recorder.call_list) == 3


# --------------------------------------------------------------------------------

def test_the_test_tag_builds_the_test_images_and_names_the_tag_on_stderr(run_build, recorder):
    exit_code, out, err = run_build([], {"SBX_IMAGE_TAG": "test"})

    assert exit_code == 0
    assert out.splitlines()[0] == "build.sh: building sbx-base:test"
    assert err == (
        "build.sh: using the test images because SBX_IMAGE_TAG=test; "
        "unset it to use the local images your sandboxes run\n"
    )


# --------------------------------------------------------------------------------

def test_a_failed_build_stops_the_run_and_names_the_image(run_build, recorder):
    recorder.answer(["build"], DockerResult(1, ""))

    exit_code, out, err = run_build([])

    assert exit_code == 1
    assert err == "build.sh: the build of sbx-base:local failed\n"
    assert len(recorder.call_list) == 1


# --------------------------------------------------------------------------------

def test_a_missing_docker_is_named(run_build, recorder):
    recorder.answer(["build"], DockerResult(127, ""))

    exit_code, _, err = run_build([])

    assert exit_code == 1
    assert err == "build.sh: cannot run docker; is Docker installed and on the PATH?\n"


# --------------------------------------------------------------------------------
# build_plan
# --------------------------------------------------------------------------------

def test_the_plan_builds_the_base_first_then_one_image_per_agent(repo_dir):
    plan = build_module.build_plan("test", ["NODE_VERSION", "GH_VERSION"], ["--no-cache"], repo_dir, None, "")

    assert [image for image, _ in plan] == ["sbx-base:test", "sbx-claude:test", "sbx-cursor:test"]
    assert [f"sbx-{agent}:test" for agent in KNOWN_AGENT_LIST] == [image for image, _ in plan][1:]

    pin_argument_list = ["--build-arg", "NODE_VERSION", "--build-arg", "GH_VERSION"]

    assert plan[0][1] == [
        "build", "--no-cache", "-f", f"{repo_dir}/base/Dockerfile", *pin_argument_list, "-t", "sbx-base:test",
        str(repo_dir),
    ]
    assert plan[1][1] == [
        "build", "--build-arg", "BASE_IMAGE=sbx-base:test", "--no-cache", "-f", f"{repo_dir}/claude/Dockerfile",
        *pin_argument_list, "-t", "sbx-claude:test", str(repo_dir),
    ]
    assert plan[2][1][-3:-1] == ["-t", "sbx-cursor:test"]
    assert "BASE_IMAGE=sbx-base:test" in plan[2][1]


# --------------------------------------------------------------------------------

def test_only_the_base_build_gets_the_certificate_directory_and_the_fingerprints(repo_dir, tmp_path):
    plan = build_module.build_plan("local", ["NODE_VERSION"], [], repo_dir, tmp_path / "certs", "AA BB")

    assert plan[0][1][:5] == ["build", "--build-context", f"cacert={tmp_path / 'certs'}", "--build-arg",
                              "EXTRA_CA_FINGERPRINTS=AA BB"]

    for _, argument_list in plan[1:]:
        assert "--build-context" not in argument_list
        assert "EXTRA_CA_FINGERPRINTS=AA BB" not in argument_list


# --------------------------------------------------------------------------------

def test_every_pin_is_a_bare_build_arg_and_its_value_is_in_the_docker_environment(run_build, recorder):
    exit_code, _, _ = run_build(["--pull"], {"HOME": "/x"})

    assert exit_code == 0

    for argument_list, environ in zip(recorder.call_list, recorder.environ_list):
        assert "--pull" in argument_list
        assert argument_list.count("--build-arg") >= 3
        assert "NODE_VERSION" in argument_list
        assert "NODE_VERSION=24.21.0" not in argument_list
        assert environ["NODE_VERSION"] == "24.21.0"
        assert environ["UBUNTU_IMAGE"] == "ubuntu:24.04@sha256:abc"
        assert environ["BEST_PRACTICES_REPO_URL"] == "https://example.com/one.git"
        assert environ["HOME"] == "/x"


# --------------------------------------------------------------------------------

def test_the_builds_run_with_output_to_the_terminal(run_build, recorder):
    run_build([])

    assert recorder.capture_list == [False, False, False]


# --------------------------------------------------------------------------------
# SBX_CA_CERT
# --------------------------------------------------------------------------------

def test_a_relative_certificate_path_is_refused(run_build, recorder):
    exit_code, out, err = run_build([], {"SBX_CA_CERT": "certs/ca.pem"})

    assert exit_code == 1
    assert out == ""
    assert err == "build.sh: SBX_CA_CERT must be an absolute path: certs/ca.pem\n"
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("kind", ["missing", "directory"])
def test_a_certificate_path_that_is_not_a_readable_file_is_refused(run_build, tmp_path, recorder, kind):
    path = tmp_path / "ca.pem"

    if kind == "directory":
        path.mkdir()

    exit_code, _, err = run_build([], {"SBX_CA_CERT": str(path)})

    assert exit_code == 1
    assert err == f"build.sh: SBX_CA_CERT is not a readable file: {path}\n"
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

def test_a_missing_openssl_is_refused(run_build, bundle, tmp_path, recorder):
    empty_dir = tmp_path / "empty-path"
    empty_dir.mkdir()

    exit_code, _, err = run_build([], {"SBX_CA_CERT": str(bundle[0]), "PATH": str(empty_dir)})

    assert exit_code == 1
    assert err == "build.sh: SBX_CA_CERT is set, but openssl is missing to check it\n"
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

def test_a_file_with_no_certificate_is_refused_and_leaves_no_temporary_directory(run_build, bundle, tmp_path, recorder):
    key_only = tmp_path / "key-only.pem"
    key_only.write_text(bundle[0].read_text().split("-----BEGIN CERTIFICATE-----")[0], encoding="utf-8")
    temp_dir = tmp_path / "tmp1"
    temp_dir.mkdir()

    exit_code, _, err = run_build([], {"SBX_CA_CERT": str(key_only), "TMPDIR": str(temp_dir)})

    assert exit_code == 1
    assert err == f"build.sh: SBX_CA_CERT holds no PEM certificate: {key_only}\n"
    assert recorder.call_list == []
    assert list(temp_dir.iterdir()) == []


# --------------------------------------------------------------------------------

def test_an_invalid_certificate_block_is_refused(run_build, tmp_path, recorder):
    bad_file = tmp_path / "bad.pem"
    bad_file.write_text("-----BEGIN CERTIFICATE-----\nnot a certificate\n-----END CERTIFICATE-----\n", encoding="utf-8")

    exit_code, _, err = run_build([], {"SBX_CA_CERT": str(bad_file)})

    assert exit_code == 1
    assert err == f"build.sh: SBX_CA_CERT holds a block that is not a valid certificate: {bad_file}\n"
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

def test_a_bundle_with_a_key_and_two_certificates_gives_two_files_and_no_key(run_build, bundle, tmp_path):
    bundle_file, cert_file_list = bundle
    temp_dir = tmp_path / "tmp1"
    temp_dir.mkdir()
    inspector = CertInspector()

    exit_code, out, err = run_build([], {"SBX_CA_CERT": str(bundle_file), "TMPDIR": str(temp_dir)}, docker=inspector)

    assert exit_code == 0, err
    assert sorted(inspector.cert_file_map) == ["sbx-extra-ca-1.crt", "sbx-extra-ca-2.crt"]

    for text in inspector.cert_file_map.values():
        assert "PRIVATE KEY" not in text
        assert text.startswith("-----BEGIN CERTIFICATE-----")
        assert "text between" not in text

    assert inspector.cert_file_map["sbx-extra-ca-1.crt"] == cert_file_list[0].read_text()
    assert inspector.cert_file_map["sbx-extra-ca-2.crt"] == cert_file_list[1].read_text()
    assert list(temp_dir.iterdir()) == []


# --------------------------------------------------------------------------------

def test_the_fingerprints_and_the_context_go_to_the_base_build_only(run_build, bundle):
    bundle_file, cert_file_list = bundle
    recorder = DockerRecorder()
    expected_text = " ".join([_openssl_fingerprint(cert_file) for cert_file in cert_file_list])

    exit_code, _, _ = run_build([], {"SBX_CA_CERT": str(bundle_file)}, docker=recorder)

    assert exit_code == 0
    assert f"EXTRA_CA_FINGERPRINTS={expected_text}" in recorder.call_list[0]
    assert ":" not in expected_text
    assert expected_text == expected_text.upper()
    assert len(expected_text.split(" ")) == 2

    base_call = recorder.call_list[0]

    assert base_call[base_call.index("--build-context") + 1].startswith("cacert=")

    for argument_list in recorder.call_list[1:]:
        assert "--build-context" not in argument_list
        assert not any(argument.startswith("EXTRA_CA_FINGERPRINTS=") for argument in argument_list)


# --------------------------------------------------------------------------------

def test_the_banner_is_printed_before_the_first_build_and_after_the_last(run_build, bundle):
    bundle_file, cert_file_list = bundle

    exit_code, out, _ = run_build([], {"SBX_CA_CERT": str(bundle_file)})

    assert exit_code == 0

    line_list = out.splitlines()
    first_building = line_list.index("build.sh: building sbx-base:local")

    assert line_list[0] == STAR_LINE
    assert line_list[1] == "* build.sh: the sbx images trust an EXTRA ROOT CERTIFICATE"
    assert line_list[2] == f"* file: {bundle_file}"
    assert line_list[first_building - 1] == STAR_LINE
    assert line_list[-1] == STAR_LINE
    assert line_list[-2] == "* Whoever holds its key can read and change HTTPS traffic in the sandbox. See README.md."
    assert line_list.count("* build.sh: the sbx images trust an EXTRA ROOT CERTIFICATE") == 2
    assert out.count("* subject=") == 4

    for cert_file in cert_file_list:
        fingerprint = _openssl_fingerprint(cert_file)
        colon_form = ":".join([fingerprint[index:index + 2] for index in range(0, len(fingerprint), 2)])

        assert out.count(f"Fingerprint={colon_form}") == 2


# --------------------------------------------------------------------------------

def test_a_failed_build_prints_no_closing_banner(run_build, bundle):
    recorder = DockerRecorder()
    recorder.answer(["build"], DockerResult(1, ""))

    exit_code, out, _ = run_build([], {"SBX_CA_CERT": str(bundle[0])}, docker=recorder)

    assert exit_code == 1
    assert out.count("EXTRA ROOT CERTIFICATE") == 1


# --------------------------------------------------------------------------------
# A bare docker build names its missing pin
# --------------------------------------------------------------------------------
# Every ARG that is a pin ending in _VERSION or _URL is followed by a RUN line that
# stops with "NAME is not set; build with ./build.sh". A docker build run without
# build.sh then fails at the first use of the pin and says which one is missing.
# --------------------------------------------------------------------------------

def _pin_arg_name_list(dockerfile: Path) -> list[tuple[str, int]]:
    line_list = dockerfile.read_text(encoding="utf-8").splitlines()
    found_list = []

    for index, line in enumerate(line_list):
        if not line.startswith("ARG "):
            continue

        name = line[len("ARG "):].split("=", 1)[0].strip()

        if name.endswith("_VERSION") or name.endswith("_URL"):
            found_list.append((name, index))

    return found_list


# --------------------------------------------------------------------------------

def _next_run_line(line_list: list[str], start_index: int) -> str:
    for line in line_list[start_index + 1:]:
        if line.startswith("RUN "):
            return line

    return ""


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("dockerfile_name", ["base/Dockerfile", "claude/Dockerfile", "cursor/Dockerfile"])
def test_guard_line_every_pin_arg_is_followed_by_a_run_line_that_names_the_missing_pin(dockerfile_name):
    dockerfile = REPO_DIR / dockerfile_name
    line_list = dockerfile.read_text(encoding="utf-8").splitlines()
    found_list = _pin_arg_name_list(dockerfile)

    assert found_list != []

    for name, index in found_list:
        run_line = _next_run_line(line_list, index)

        assert "${" + name + ":?" + name + " is not set; build with ./build.sh}" in run_line, name


# --------------------------------------------------------------------------------

def test_guard_line_test_sees_a_pin_arg_without_a_guard(tmp_path):
    dockerfile = tmp_path / "Dockerfile"
    dockerfile.write_text("FROM x\nARG NODE_VERSION\nRUN echo hello\n", encoding="utf-8")
    line_list = dockerfile.read_text(encoding="utf-8").splitlines()

    found_list = _pin_arg_name_list(dockerfile)

    assert found_list == [("NODE_VERSION", 1)]
    assert "${NODE_VERSION:?" not in _next_run_line(line_list, 1)
