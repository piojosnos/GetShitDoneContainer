# ------------------------------------------------------------------------------
# The shared checks of the extra root certificates
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import hashlib
import ssl
from pathlib import Path
from typing import Mapping

from selfcheck_core import (
    Check,
    CheckResult,
    failed,
    first_output_line,
    passed,
    problem_list_result,
    rebuild_hint,
    run_command,
)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

EXTRA_CA_DIR = Path("/usr/local/share/ca-certificates")
SYSTEM_BUNDLE_FILE = Path("/etc/ssl/certs/ca-certificates.crt")
KEYTOOL_STORE_ARGUMENT_TUPLE = ("-cacerts", "-storepass", "changeit")
NO_EXTRA_CA_TEXT = "no extra root certificate installed"
PEM_BEGIN_MARKER = "-----BEGIN CERTIFICATE-----"
PEM_END_MARKER = "-----END CERTIFICATE-----"
KEYTOOL_FINGERPRINT_PREFIX = "Certificate fingerprint (SHA-256): "
KEYTOOL_ALIAS_LINE_END = "trustedCertEntry,"


# ------------------------------------------------------------------------------
# Certificate parsing
# ------------------------------------------------------------------------------

def pem_block_list(text: str) -> list[str]:
    block_list = []

    for part in text.split(PEM_END_MARKER):
        begin_index = part.find(PEM_BEGIN_MARKER)

        if begin_index < 0:
            continue

        block_list.append(part[begin_index:] + PEM_END_MARKER)

    return block_list


def pem_fingerprint(pem_text: str) -> str:
    return hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem_text)).hexdigest().upper()


def extra_cert_fingerprint_by_alias_map(extra_ca_dir: Path) -> dict[str, str]:
    fingerprint_by_alias_map = {}

    for certificate_file in sorted(extra_ca_dir.glob("sbx-extra-ca-*.crt")):
        block_list = pem_block_list(certificate_file.read_text())

        if not block_list:
            raise ValueError(f"{certificate_file} holds no certificate")

        fingerprint_by_alias_map[certificate_file.stem] = pem_fingerprint(block_list[0])

    return fingerprint_by_alias_map


def keytool_fingerprint_set(text: str) -> set[str]:
    fingerprint_set = set()

    for line in text.splitlines():
        if line.startswith(KEYTOOL_FINGERPRINT_PREFIX):
            fingerprint_set.add(line[len(KEYTOOL_FINGERPRINT_PREFIX):].strip().replace(":", "").upper())

    return fingerprint_set


def keytool_alias_set(text: str) -> set[str]:
    alias_set = set()

    for line in text.splitlines():
        stripped_line = line.strip()

        if stripped_line.endswith(KEYTOOL_ALIAS_LINE_END):
            alias_set.add(stripped_line.partition(", ")[0])

    return alias_set


def extra_certificates_text(fingerprint_by_alias_map: Mapping[str, str]) -> str:
    pair_list = []

    for alias, fingerprint in fingerprint_by_alias_map.items():
        pair_list.append(f"{alias} {fingerprint}")

    return ", ".join(pair_list)


# ------------------------------------------------------------------------------
# Trust store checks
# ------------------------------------------------------------------------------

def system_bundle_result(
    extra_ca_dir: Path = EXTRA_CA_DIR,
    bundle_file: Path = SYSTEM_BUNDLE_FILE,
) -> CheckResult:
    fingerprint_by_alias_map = extra_cert_fingerprint_by_alias_map(extra_ca_dir)

    if not fingerprint_by_alias_map:
        return passed(NO_EXTRA_CA_TEXT)

    if not bundle_file.is_file():
        return failed(f"{bundle_file} is missing", rebuild_hint())

    bundle_fingerprint_set = set()

    for block in pem_block_list(bundle_file.read_text()):
        bundle_fingerprint_set.add(pem_fingerprint(block))

    problem_list = []

    for alias, fingerprint in fingerprint_by_alias_map.items():
        if fingerprint not in bundle_fingerprint_set:
            problem_list.append(f"{alias} ({fingerprint}) is not in {bundle_file}")

    return problem_list_result(
        problem_list,
        rebuild_hint(),
        f"{len(fingerprint_by_alias_map)} extra root certificates in the system bundle: "
        + extra_certificates_text(fingerprint_by_alias_map),
    )


def java_cacerts_result(
    extra_ca_dir: Path = EXTRA_CA_DIR,
    keytool_argument_tuple: tuple[str, ...] = KEYTOOL_STORE_ARGUMENT_TUPLE,
) -> CheckResult:
    fingerprint_by_alias_map = extra_cert_fingerprint_by_alias_map(extra_ca_dir)

    if not fingerprint_by_alias_map:
        return passed(NO_EXTRA_CA_TEXT)

    completed = run_command(["keytool", "-list", *keytool_argument_tuple])

    if completed.returncode != 0:
        return failed(f"keytool -list failed: {first_output_line(completed)}", rebuild_hint())

    alias_set = keytool_alias_set(completed.stdout)
    fingerprint_set = keytool_fingerprint_set(completed.stdout)
    problem_list = []

    for alias, fingerprint in fingerprint_by_alias_map.items():
        if alias not in alias_set:
            problem_list.append(f"{alias} is not an alias in Java cacerts")
        elif fingerprint not in fingerprint_set:
            problem_list.append(f"{alias} ({fingerprint}) is not in Java cacerts")

    return problem_list_result(
        problem_list,
        rebuild_hint(),
        f"{len(fingerprint_by_alias_map)} extra root certificates in Java cacerts: "
        + extra_certificates_text(fingerprint_by_alias_map),
    )


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def check_extra_ca_system_bundle() -> CheckResult:
    return system_bundle_result()


def check_extra_ca_java_cacerts() -> CheckResult:
    return java_cacerts_result()


CERT_CHECK_LIST = [
    Check("extra-ca-system-bundle", check_extra_ca_system_bundle),
    Check("extra-ca-java-cacerts", check_extra_ca_java_cacerts),
]
