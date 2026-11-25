# --------------------------------------------------------------------------------
# Checks: the extra root certificates are trusted
# --------------------------------------------------------------------------------
# build.sh records the SHA-256 fingerprint of each root certificate it adds in
# /etc/sbx/extra-ca-fingerprints, one per line. No certificate installed (no
# /etc/sbx/extra-ca.pem) and no fingerprint means none was requested; a
# certificate without a recorded fingerprint fails. The image puts this file in
# /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

import hashlib
import ssl
from pathlib import Path

from check_result import Check, CheckResult, failed, passed, problem_list_result
from commands import first_output_line, run_command
from hints import rebuild_hint

_EXPECTED_FINGERPRINTS_FILE = Path("/etc/sbx/extra-ca-fingerprints")
_INSTALLED_CERTIFICATES_FILE = Path("/etc/sbx/extra-ca.pem")
_SYSTEM_BUNDLE_FILE = Path("/etc/ssl/certs/ca-certificates.crt")
_KEYTOOL_STORE_ARGUMENT_TUPLE = ("-cacerts", "-storepass", "changeit")
_NOT_REQUESTED_TEXT = "no extra root certificate requested"
_PEM_BEGIN_MARKER = "-----BEGIN CERTIFICATE-----"
_PEM_END_MARKER = "-----END CERTIFICATE-----"
_KEYTOOL_FINGERPRINT_PREFIX = "Certificate fingerprint (SHA-256): "


# --------------------------------------------------------------------------------
# The expected fingerprints
# --------------------------------------------------------------------------------

def _expected_fingerprint_list(expected_file: Path) -> list[str]:
    if not expected_file.is_file():
        return []

    fingerprint_list = []

    for line in expected_file.read_text().splitlines():
        if line.strip():
            fingerprint_list.append(line.strip().upper())

    return fingerprint_list


def _expected_list_or_result(expected_file: Path, installed_file: Path) -> tuple[list[str], CheckResult | None]:
    expected_list = _expected_fingerprint_list(expected_file)

    if expected_list:
        return expected_list, None

    if installed_file.is_file():
        return [], failed(
            f"a root certificate is installed ({installed_file}) but its expected fingerprint was not recorded "
            f"by the build ({expected_file} is missing or empty)",
            rebuild_hint(),
        )

    return [], passed(_NOT_REQUESTED_TEXT)


# --------------------------------------------------------------------------------
# Fingerprints found in a store
# --------------------------------------------------------------------------------

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


def _keytool_fingerprint_set(text: str) -> set[str]:
    fingerprint_set = set()

    for line in text.splitlines():
        if line.startswith(_KEYTOOL_FINGERPRINT_PREFIX):
            fingerprint_set.add(line[len(_KEYTOOL_FINGERPRINT_PREFIX):].strip().replace(":", "").upper())

    return fingerprint_set


def _missing_result(
    expected_list: list[str],
    found_set: set[str],
    store_text: str,
) -> CheckResult:
    problem_list = []

    for fingerprint in expected_list:
        if fingerprint not in found_set:
            problem_list.append(f"{fingerprint} is not in {store_text}")

    return problem_list_result(
        problem_list,
        rebuild_hint(),
        f"{len(expected_list)} extra root certificates in {store_text}: " + ", ".join(expected_list),
    )


# --------------------------------------------------------------------------------
# System bundle
# --------------------------------------------------------------------------------

def system_bundle_result(
    expected_file: Path = _EXPECTED_FINGERPRINTS_FILE,
    bundle_file: Path = _SYSTEM_BUNDLE_FILE,
    installed_file: Path = _INSTALLED_CERTIFICATES_FILE,
) -> CheckResult:
    expected_list, early_result = _expected_list_or_result(expected_file, installed_file)

    if early_result:
        return early_result

    if not bundle_file.is_file():
        return failed(f"{bundle_file} is missing", rebuild_hint())

    bundle_fingerprint_set = set()

    for block in _pem_block_list(bundle_file.read_text()):
        bundle_fingerprint_set.add(_pem_fingerprint(block))

    return _missing_result(expected_list, bundle_fingerprint_set, f"the system bundle {bundle_file}")


# --------------------------------------------------------------------------------
# Java cacerts
# --------------------------------------------------------------------------------

def java_cacerts_result(
    expected_file: Path = _EXPECTED_FINGERPRINTS_FILE,
    keytool_argument_tuple: tuple[str, ...] = _KEYTOOL_STORE_ARGUMENT_TUPLE,
    installed_file: Path = _INSTALLED_CERTIFICATES_FILE,
) -> CheckResult:
    expected_list, early_result = _expected_list_or_result(expected_file, installed_file)

    if early_result:
        return early_result

    completed = run_command(["keytool", "-list", *keytool_argument_tuple])

    if completed.returncode != 0:
        return failed(f"keytool -list failed: {first_output_line(completed)}", rebuild_hint())

    return _missing_result(expected_list, _keytool_fingerprint_set(completed.stdout), "Java cacerts")


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_extra_ca_system_bundle() -> CheckResult:
    return system_bundle_result()


def _check_extra_ca_java_cacerts() -> CheckResult:
    return java_cacerts_result()


CHECK_LIST = [
    Check("extra-ca-system-bundle", _check_extra_ca_system_bundle),
    Check("extra-ca-java-cacerts", _check_extra_ca_java_cacerts),
]
