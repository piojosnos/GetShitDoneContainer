# ------------------------------------------------------------------------------
# Checks: the extra root certificates are trusted
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

import hashlib
import ssl
from pathlib import Path
from typing import Mapping

from check_result import Check, CheckResult, failed, passed, problem_list_result
from commands import first_output_line, run_command
from hints import rebuild_hint

_EXTRA_CA_DIR = Path("/usr/local/share/ca-certificates")
_SYSTEM_BUNDLE_FILE = Path("/etc/ssl/certs/ca-certificates.crt")
_KEYTOOL_STORE_ARGUMENT_TUPLE = ("-cacerts", "-storepass", "changeit")
_NO_EXTRA_CA_TEXT = "no extra root certificate installed"
_PEM_BEGIN_MARKER = "-----BEGIN CERTIFICATE-----"
_PEM_END_MARKER = "-----END CERTIFICATE-----"
_KEYTOOL_FINGERPRINT_PREFIX = "Certificate fingerprint (SHA-256): "
_KEYTOOL_ALIAS_LINE_END = "trustedCertEntry,"


# ------------------------------------------------------------------------------
# Certificate parsing
# ------------------------------------------------------------------------------

def _pem_block_list(text: str) -> list[str]:
    block_list = []

    for part in text.split(_PEM_END_MARKER):
        begin_index = part.find(_PEM_BEGIN_MARKER)

        if begin_index < 0:
            continue

        block_list.append(part[begin_index:] + _PEM_END_MARKER)

    return block_list


def _pem_fingerprint(pem_text: str) -> str:
    return hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem_text)).hexdigest().upper()


def _extra_cert_fingerprint_by_alias_map(extra_ca_dir: Path) -> dict[str, str]:
    fingerprint_by_alias_map = {}

    for certificate_file in sorted(extra_ca_dir.glob("sbx-extra-ca-*.crt")):
        block_list = _pem_block_list(certificate_file.read_text())

        if not block_list:
            raise ValueError(f"{certificate_file} holds no certificate")

        fingerprint_by_alias_map[certificate_file.stem] = _pem_fingerprint(block_list[0])

    return fingerprint_by_alias_map


def _keytool_fingerprint_set(text: str) -> set[str]:
    fingerprint_set = set()

    for line in text.splitlines():
        if line.startswith(_KEYTOOL_FINGERPRINT_PREFIX):
            fingerprint_set.add(line[len(_KEYTOOL_FINGERPRINT_PREFIX):].strip().replace(":", "").upper())

    return fingerprint_set


def _keytool_alias_set(text: str) -> set[str]:
    alias_set = set()

    for line in text.splitlines():
        stripped_line = line.strip()

        if stripped_line.endswith(_KEYTOOL_ALIAS_LINE_END):
            alias_set.add(stripped_line.partition(", ")[0])

    return alias_set


def _extra_certificates_text(fingerprint_by_alias_map: Mapping[str, str]) -> str:
    pair_list = []

    for alias, fingerprint in fingerprint_by_alias_map.items():
        pair_list.append(f"{alias} {fingerprint}")

    return ", ".join(pair_list)


# ------------------------------------------------------------------------------
# Trust store checks
# ------------------------------------------------------------------------------

def system_bundle_result(
    extra_ca_dir: Path = _EXTRA_CA_DIR,
    bundle_file: Path = _SYSTEM_BUNDLE_FILE,
) -> CheckResult:
    fingerprint_by_alias_map = _extra_cert_fingerprint_by_alias_map(extra_ca_dir)

    if not fingerprint_by_alias_map:
        return passed(_NO_EXTRA_CA_TEXT)

    if not bundle_file.is_file():
        return failed(f"{bundle_file} is missing", rebuild_hint())

    bundle_fingerprint_set = set()

    for block in _pem_block_list(bundle_file.read_text()):
        bundle_fingerprint_set.add(_pem_fingerprint(block))

    problem_list = []

    for alias, fingerprint in fingerprint_by_alias_map.items():
        if fingerprint not in bundle_fingerprint_set:
            problem_list.append(f"{alias} ({fingerprint}) is not in {bundle_file}")

    return problem_list_result(
        problem_list,
        rebuild_hint(),
        f"{len(fingerprint_by_alias_map)} extra root certificates in the system bundle: "
        + _extra_certificates_text(fingerprint_by_alias_map),
    )


def java_cacerts_result(
    extra_ca_dir: Path = _EXTRA_CA_DIR,
    keytool_argument_tuple: tuple[str, ...] = _KEYTOOL_STORE_ARGUMENT_TUPLE,
) -> CheckResult:
    fingerprint_by_alias_map = _extra_cert_fingerprint_by_alias_map(extra_ca_dir)

    if not fingerprint_by_alias_map:
        return passed(_NO_EXTRA_CA_TEXT)

    completed = run_command(["keytool", "-list", *keytool_argument_tuple])

    if completed.returncode != 0:
        return failed(f"keytool -list failed: {first_output_line(completed)}", rebuild_hint())

    alias_set = _keytool_alias_set(completed.stdout)
    fingerprint_set = _keytool_fingerprint_set(completed.stdout)
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
        + _extra_certificates_text(fingerprint_by_alias_map),
    )


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_extra_ca_system_bundle() -> CheckResult:
    return system_bundle_result()


def _check_extra_ca_java_cacerts() -> CheckResult:
    return java_cacerts_result()


CHECK_LIST = [
    Check("extra-ca-system-bundle", _check_extra_ca_system_bundle),
    Check("extra-ca-java-cacerts", _check_extra_ca_java_cacerts),
]
