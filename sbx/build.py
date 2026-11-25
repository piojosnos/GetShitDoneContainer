# --------------------------------------------------------------------------------
# build.sh: builds sbx-base, then one image per agent, with the pins in versions.env
# --------------------------------------------------------------------------------
# versions.env is read as NAME=value text and never run. Each pin reaches Docker
# as a bare --build-arg NAME and a value in the environment of the build, so
# adding or bumping a pin never changes this file. Extra options go to every
# build. With SBX_CA_CERT set, the base image also trusts its root certificates.
# --------------------------------------------------------------------------------

import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Mapping
from functools import partial
from pathlib import Path

from sbx.cli import REPO_DIR, SbxError, run_command
from sbx.docker import Docker, run_docker
from sbx.names import KNOWN_AGENT_LIST, agent_image, base_image, image_tag


# --------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------

COMMAND_NAME = "build.sh"
_PIN_LINE_PATTERN = re.compile(r"([A-Z_][A-Z0-9_]*)=(.*)", re.ASCII)
_BEGIN_MARKER = "-----BEGIN CERTIFICATE-----"
_END_MARKER = "-----END CERTIFICATE-----"
_STAR_LINE = "*" * 78
_NOT_FOUND_EXIT_CODE = 127


# --------------------------------------------------------------------------------
# The pins
# --------------------------------------------------------------------------------
# A line that is not NAME=value (a comment, a blank line) is skipped. A value is
# the text after the first equals sign, as written; nothing in it is expanded.
# --------------------------------------------------------------------------------

def read_pins(versions_file: Path) -> dict[str, str]:
    try:
        text = versions_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        raise SbxError(f"cannot read {versions_file}") from None

    pin_map = {}

    for line in text.splitlines():
        match = _PIN_LINE_PATTERN.fullmatch(line)

        if match is None:
            continue

        pin_map[match.group(1)] = match.group(2)

    return pin_map


# --------------------------------------------------------------------------------
# The plan: which images, with which docker arguments
# --------------------------------------------------------------------------------
# Paths are absolute under repo_dir, so a build never depends on the working
# directory. The options come right after docker build. Only the base build gets
# the certificate directory and the fingerprints; each agent build is told which
# base to start from, so a test tag never sits on the local base.
# --------------------------------------------------------------------------------

def _docker_build_arguments(
    repo_dir: Path,
    dockerfile_dir: str,
    image: str,
    fixed_option_list: list[str],
    option_list: list[str],
    pin_name_list: list[str],
) -> list[str]:
    pin_argument_list = []

    for pin_name in pin_name_list:
        pin_argument_list.extend(["--build-arg", pin_name])

    return [
        "build",
        *fixed_option_list,
        *option_list,
        "-f",
        str(repo_dir / dockerfile_dir / "Dockerfile"),
        *pin_argument_list,
        "-t",
        image,
        str(repo_dir),
    ]


# --------------------------------------------------------------------------------

def build_plan(
    tag: str,
    pin_name_list: list[str],
    option_list: list[str],
    repo_dir: Path,
    cert_dir: Path | None,
    fingerprint_text: str,
) -> list[tuple[str, list[str]]]:
    base_fixed_option_list = []

    if cert_dir is not None:
        base_fixed_option_list.extend(
            ["--build-context", f"cacert={cert_dir}", "--build-arg", f"EXTRA_CA_FINGERPRINTS={fingerprint_text}"]
        )

    base = base_image(tag)
    plan = [(base, _docker_build_arguments(repo_dir, "base", base, base_fixed_option_list, option_list, pin_name_list))]

    for agent in KNOWN_AGENT_LIST:
        image = agent_image(agent, tag)
        agent_fixed_option_list = ["--build-arg", f"BASE_IMAGE={base}"]

        plan.append(
            (image, _docker_build_arguments(repo_dir, agent, image, agent_fixed_option_list, option_list, pin_name_list))
        )

    return plan


# --------------------------------------------------------------------------------
# The extra root certificate
# --------------------------------------------------------------------------------
# Only certificate blocks are kept, so a key in the same file never reaches the
# build. Each block is a file of its own, checked by openssl. The fingerprints
# (SHA-256, uppercase hex, no colons) are recorded by the image, so its selfcheck
# knows what to expect.
# --------------------------------------------------------------------------------

def find_openssl_for_cert(cert_path: str, environ: Mapping[str, str]) -> str:
    if not cert_path.startswith("/"):
        raise SbxError(f"SBX_CA_CERT must be an absolute path: {cert_path}")

    if not os.path.isfile(cert_path) or not os.access(cert_path, os.R_OK):
        raise SbxError(f"SBX_CA_CERT is not a readable file: {cert_path}")

    openssl_path = shutil.which("openssl", path=environ.get("PATH"))

    if openssl_path is None:
        raise SbxError("SBX_CA_CERT is set, but openssl is missing to check it")

    return openssl_path


# --------------------------------------------------------------------------------

def _run_openssl(openssl_path: str, argument_list: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        [openssl_path, "x509", *argument_list],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        errors="replace",
        check=False,
    )


# --------------------------------------------------------------------------------

def _split_certificates(cert_path: str, cert_dir: Path) -> list[Path]:
    with open(cert_path, encoding="utf-8", errors="surrogateescape") as handle:
        line_list = handle.read().splitlines()

    block_list: list[list[str]] = []
    current_block: list[str] | None = None

    for line in line_list:
        if _BEGIN_MARKER in line:
            current_block = []
            block_list.append(current_block)

        if current_block is not None:
            current_block.append(line)

        if _END_MARKER in line:
            current_block = None

    cert_file_list = []

    for index, block in enumerate(block_list, start=1):
        cert_file = cert_dir / f"sbx-extra-ca-{index}.crt"

        with open(cert_file, "w", encoding="utf-8", errors="surrogateescape") as handle:
            handle.write("\n".join(block) + "\n")

        cert_file_list.append(cert_file)

    return cert_file_list


# --------------------------------------------------------------------------------

def _certificate_fingerprint(openssl_path: str, cert_file: Path) -> str:
    result = _run_openssl(openssl_path, ["-noout", "-fingerprint", "-sha256", "-in", str(cert_file)])

    if result.returncode != 0 or "=" not in result.stdout:
        return ""

    text = result.stdout.splitlines()[0].split("=", 1)[1]

    return text.replace(":", "").strip().upper()


# --------------------------------------------------------------------------------

def prepare_extra_certs(cert_path: str, cert_dir: Path, openssl_path: str) -> tuple[list[Path], list[str]]:
    cert_file_list = _split_certificates(cert_path, cert_dir)

    if not cert_file_list:
        raise SbxError(f"SBX_CA_CERT holds no PEM certificate: {cert_path}")

    fingerprint_list = []

    for cert_file in cert_file_list:
        if _run_openssl(openssl_path, ["-noout", "-in", str(cert_file)]).returncode != 0:
            raise SbxError(f"SBX_CA_CERT holds a block that is not a valid certificate: {cert_path}")

        fingerprint = _certificate_fingerprint(openssl_path, cert_file)

        if not fingerprint:
            raise SbxError(f"could not read the fingerprint of a certificate in {cert_path}")

        fingerprint_list.append(fingerprint)

    return cert_file_list, fingerprint_list


# --------------------------------------------------------------------------------
# The banner
# --------------------------------------------------------------------------------
# Printed before the first build and after the last. The openssl output is only
# shown; the fingerprints the image records come from prepare_extra_certs.
# --------------------------------------------------------------------------------

def print_cert_banner(cert_path: str, cert_file_list: list[Path], openssl_path: str) -> None:
    print(_STAR_LINE)
    print(f"* {COMMAND_NAME}: the sbx images trust an EXTRA ROOT CERTIFICATE")
    print(f"* file: {cert_path}")

    for cert_file in cert_file_list:
        result = _run_openssl(openssl_path, ["-noout", "-subject", "-fingerprint", "-sha256", "-in", str(cert_file)])

        for line in result.stdout.splitlines():
            print(f"* {line}")

    print("* Whoever holds its key can read and change HTTPS traffic in the sandbox. See README.md.")
    print(_STAR_LINE, flush=True)


# --------------------------------------------------------------------------------
# Running the plan
# --------------------------------------------------------------------------------

def _run_plan(plan: list[tuple[str, list[str]]], docker: Docker, docker_environ: Mapping[str, str]) -> None:
    for image, docker_argument_list in plan:
        print(f"{COMMAND_NAME}: building {image}", flush=True)

        result = docker(docker_argument_list, docker_environ, False)

        if result.returncode == _NOT_FOUND_EXIT_CODE:
            raise SbxError("cannot run docker; is Docker installed and on the PATH?")

        if result.returncode != 0:
            raise SbxError(f"the build of {image} failed")


# --------------------------------------------------------------------------------
# The command
# --------------------------------------------------------------------------------

def _build_images(argument_list: list[str], environ: Mapping[str, str], docker: Docker, repo_dir: Path) -> None:
    tag = image_tag(environ, COMMAND_NAME)
    versions_file = repo_dir / "versions.env"

    if not versions_file.is_file():
        raise SbxError("versions.env is missing next to build.sh")

    pin_map = read_pins(versions_file)

    if not pin_map:
        raise SbxError("versions.env holds no pins")

    docker_environ = dict(environ)
    docker_environ.update(pin_map)
    pin_name_list = list(pin_map)
    cert_path = environ.get("SBX_CA_CERT", "")

    if not cert_path:
        _run_plan(build_plan(tag, pin_name_list, argument_list, repo_dir, None, ""), docker, docker_environ)

        return

    openssl_path = find_openssl_for_cert(cert_path, environ)

    with tempfile.TemporaryDirectory(prefix="sbx-cacert.", dir=environ.get("TMPDIR") or None) as cert_dir_name:
        cert_dir = Path(cert_dir_name)
        cert_file_list, fingerprint_list = prepare_extra_certs(cert_path, cert_dir, openssl_path)
        plan = build_plan(tag, pin_name_list, argument_list, repo_dir, cert_dir, " ".join(fingerprint_list))

        print_cert_banner(cert_path, cert_file_list, openssl_path)
        _run_plan(plan, docker, docker_environ)
        print_cert_banner(cert_path, cert_file_list, openssl_path)


# --------------------------------------------------------------------------------

def main(
    argument_list: list[str],
    environ: Mapping[str, str] = os.environ,
    docker: Docker = run_docker,
    repo_dir: Path = REPO_DIR,
) -> int:
    return run_command(COMMAND_NAME, partial(_build_images, argument_list, environ, docker, repo_dir))


# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
