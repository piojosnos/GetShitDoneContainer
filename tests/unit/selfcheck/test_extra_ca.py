# --------------------------------------------------------------------------------
# Tests of the extra root certificate checks
# --------------------------------------------------------------------------------
# The certificates are made by openssl and the keystores by keytool, both real,
# inside tmp_path. A file stands for /etc/sbx/extra-ca.pem, the sign that a
# certificate was installed.
# --------------------------------------------------------------------------------

import subprocess
from pathlib import Path

import pytest

from helpers import load_shared_check

extra_ca = load_shared_check("280_extra_ca")


# --------------------------------------------------------------------------------
# Constants and helpers
# --------------------------------------------------------------------------------

KEYTOOL_PASSWORD = "changeit"


def openssl_fingerprint(certificate_file: Path) -> str:
    completed = subprocess.run(
        ["openssl", "x509", "-noout", "-fingerprint", "-sha256", "-in", str(certificate_file)],
        check=True,
        capture_output=True,
        text=True,
    )

    return completed.stdout.strip().partition("=")[2].replace(":", "").upper()


# --------------------------------------------------------------------------------

def import_into_store(store_file: Path, certificate_file: Path, alias: str) -> None:
    subprocess.run(
        [
            "keytool", "-importcert", "-noprompt", "-keystore", str(store_file), "-storepass", KEYTOOL_PASSWORD,
            "-alias", alias, "-file", str(certificate_file),
        ],
        check=True,
        capture_output=True,
    )


# --------------------------------------------------------------------------------

def keystore_arguments(store_file: Path) -> tuple[str, ...]:
    return ("-keystore", str(store_file), "-storepass", KEYTOOL_PASSWORD)


# --------------------------------------------------------------------------------

@pytest.fixture
def certs1(make_certificate) -> Path:
    return make_certificate("certs1")


# --------------------------------------------------------------------------------

@pytest.fixture
def certs2(make_certificate) -> Path:
    return make_certificate("certs2")


# --------------------------------------------------------------------------------

@pytest.fixture
def installed1(tmp_path, certs1) -> Path:
    installed_file = tmp_path / "installed1.pem"
    installed_file.write_text(certs1.read_text())

    return installed_file


# --------------------------------------------------------------------------------

@pytest.fixture
def absent1(tmp_path) -> Path:
    return tmp_path / "absent1.pem"


# --------------------------------------------------------------------------------

def write_expected(expected_file: Path, fingerprint_list: list[str]) -> Path:
    expected_file.write_text("".join(fingerprint + "\n" for fingerprint in fingerprint_list))

    return expected_file


# --------------------------------------------------------------------------------

@pytest.fixture
def expected1(tmp_path, certs1) -> Path:
    return write_expected(tmp_path / "expected1", [openssl_fingerprint(certs1)])


# --------------------------------------------------------------------------------

@pytest.fixture
def bundle1(tmp_path, certs1, certs2) -> Path:
    bundle_file = tmp_path / "bundle1.crt"
    bundle_file.write_text(certs2.read_text() + "\n" + certs1.read_text())

    return bundle_file


# --------------------------------------------------------------------------------
# System bundle
# --------------------------------------------------------------------------------

def test_system_bundle_passes_when_the_requested_certificate_is_in_the_bundle_and_prints_its_fingerprint(
    expected1, bundle1, installed1, certs1
):
    result = extra_ca.system_bundle_result(expected1, bundle1, installed1)

    assert result.passed
    assert openssl_fingerprint(certs1) in result.detail


# --------------------------------------------------------------------------------

def test_system_bundle_reads_two_certificates_joined_by_a_blank_line(tmp_path, certs1, certs2):
    expected2 = write_expected(tmp_path / "expected2", [openssl_fingerprint(certs1), openssl_fingerprint(certs2)])
    bundle2 = tmp_path / "bundle2.crt"
    bundle2.write_text(certs1.read_text() + "\n" + certs2.read_text())

    result = extra_ca.system_bundle_result(expected2, bundle2)

    assert result.passed
    assert openssl_fingerprint(certs1) in result.detail
    assert openssl_fingerprint(certs2) in result.detail


# --------------------------------------------------------------------------------

def test_system_bundle_ignores_text_around_the_certificates(tmp_path, expected1, certs1):
    bundle2 = tmp_path / "bundle2.crt"
    bundle2.write_text("comment line1\n" + certs1.read_text() + "trailing line2\n")

    assert extra_ca.system_bundle_result(expected1, bundle2).passed


# --------------------------------------------------------------------------------

def test_system_bundle_accepts_a_lowercase_fingerprint_in_the_file(tmp_path, bundle1, certs1):
    expected2 = write_expected(tmp_path / "expected2", [openssl_fingerprint(certs1).lower()])

    assert extra_ca.system_bundle_result(expected2, bundle1).passed


# --------------------------------------------------------------------------------

def test_system_bundle_fails_naming_the_requested_certificate_the_bundle_lacks(tmp_path, expected1, certs1, certs2):
    bundle2 = tmp_path / "bundle2.crt"
    bundle2.write_text(certs2.read_text())

    result = extra_ca.system_bundle_result(expected1, bundle2)

    assert not result.passed
    assert openssl_fingerprint(certs1) in result.detail
    assert openssl_fingerprint(certs2) not in result.detail
    assert "sbx-upgrade" in result.hint


# --------------------------------------------------------------------------------

def test_system_bundle_fails_for_a_bundle_without_a_certificate(tmp_path, expected1, certs1):
    bundle2 = tmp_path / "bundle2.crt"
    bundle2.write_text("nothing here\n")

    result = extra_ca.system_bundle_result(expected1, bundle2)

    assert not result.passed
    assert openssl_fingerprint(certs1) in result.detail


# --------------------------------------------------------------------------------

def test_system_bundle_fails_when_the_bundle_file_is_missing(tmp_path, expected1):
    result = extra_ca.system_bundle_result(expected1, tmp_path / "missing1.crt")

    assert not result.passed
    assert "missing1.crt is missing" in result.detail


# --------------------------------------------------------------------------------

def test_system_bundle_passes_when_no_certificate_was_requested_and_reads_no_bundle(tmp_path, absent1):
    result = extra_ca.system_bundle_result(tmp_path / "missing1", tmp_path / "missing2.crt", absent1)

    assert result.passed
    assert result.detail == "no extra root certificate requested"


# --------------------------------------------------------------------------------

def test_system_bundle_treats_an_empty_fingerprint_file_as_not_requested_when_no_certificate_is_installed(tmp_path, absent1):
    result = extra_ca.system_bundle_result(write_expected(tmp_path / "expected2", []), tmp_path / "missing2.crt", absent1)

    assert result.passed
    assert result.detail == "no extra root certificate requested"


# --------------------------------------------------------------------------------
# A certificate installed without a recorded fingerprint
# --------------------------------------------------------------------------------

def test_system_bundle_fails_when_a_certificate_is_installed_but_no_fingerprint_file_exists(
    tmp_path, bundle1, installed1
):
    result = extra_ca.system_bundle_result(tmp_path / "missing1", bundle1, installed1)

    assert not result.passed
    assert "installed" in result.detail
    assert "fingerprint was not recorded" in result.detail
    assert "sbx-upgrade" in result.hint


# --------------------------------------------------------------------------------

def test_system_bundle_fails_when_a_certificate_is_installed_but_the_fingerprint_file_is_empty(
    tmp_path, bundle1, installed1
):
    result = extra_ca.system_bundle_result(write_expected(tmp_path / "expected2", []), bundle1, installed1)

    assert not result.passed
    assert "fingerprint was not recorded" in result.detail


# --------------------------------------------------------------------------------

def test_system_bundle_fails_when_a_fingerprint_is_recorded_but_no_certificate_is_installed(
    tmp_path, expected1, absent1, certs1, certs2
):
    bundle2 = tmp_path / "bundle2.crt"
    bundle2.write_text(certs2.read_text())

    result = extra_ca.system_bundle_result(expected1, bundle2, absent1)

    assert not result.passed
    assert openssl_fingerprint(certs1) in result.detail


# --------------------------------------------------------------------------------
# Java cacerts
# --------------------------------------------------------------------------------

def test_java_cacerts_passes_when_the_requested_certificate_is_in_the_store_and_prints_its_fingerprint(
    tmp_path, expected1, installed1, certs1
):
    store1 = tmp_path / "store1.p12"
    import_into_store(store1, certs1, "alias1")

    result = extra_ca.java_cacerts_result(expected1, keystore_arguments(store1), installed1)

    assert result.passed
    assert openssl_fingerprint(certs1) in result.detail


# --------------------------------------------------------------------------------

def test_java_cacerts_fails_naming_the_second_requested_certificate_the_store_lacks(tmp_path, certs1, certs2):
    store1 = tmp_path / "store1.p12"
    import_into_store(store1, certs1, "alias1")
    expected2 = write_expected(tmp_path / "expected2", [openssl_fingerprint(certs1), openssl_fingerprint(certs2)])

    result = extra_ca.java_cacerts_result(expected2, keystore_arguments(store1))

    assert not result.passed
    assert openssl_fingerprint(certs2) in result.detail
    assert openssl_fingerprint(certs1) not in result.detail
    assert "sbx-upgrade" in result.hint


# --------------------------------------------------------------------------------

def test_java_cacerts_fails_when_the_store_holds_only_another_certificate(tmp_path, expected1, certs1, certs2):
    store1 = tmp_path / "store1.p12"
    import_into_store(store1, certs2, "alias1")

    result = extra_ca.java_cacerts_result(expected1, keystore_arguments(store1))

    assert not result.passed
    assert openssl_fingerprint(certs1) in result.detail


# --------------------------------------------------------------------------------

def test_java_cacerts_reports_a_keytool_failure_with_its_first_line(tmp_path, expected1):
    result = extra_ca.java_cacerts_result(expected1, keystore_arguments(tmp_path / "missing1.p12"))

    assert not result.passed
    assert "keytool" in result.detail


# --------------------------------------------------------------------------------

def test_java_cacerts_passes_when_no_certificate_was_requested_without_running_keytool(tmp_path, absent1):
    result = extra_ca.java_cacerts_result(tmp_path / "missing1", keystore_arguments(tmp_path / "missing2.p12"), absent1)

    assert result.passed
    assert result.detail == "no extra root certificate requested"


# --------------------------------------------------------------------------------

def test_java_cacerts_fails_when_a_certificate_is_installed_but_no_fingerprint_file_exists_without_running_keytool(
    tmp_path, installed1
):
    result = extra_ca.java_cacerts_result(
        tmp_path / "missing1", keystore_arguments(tmp_path / "missing2.p12"), installed1
    )

    assert not result.passed
    assert "installed" in result.detail
    assert "fingerprint was not recorded" in result.detail
    assert "sbx-upgrade" in result.hint


# --------------------------------------------------------------------------------

def test_java_cacerts_fails_when_a_fingerprint_is_recorded_but_no_certificate_is_installed(
    tmp_path, expected1, absent1, certs2
):
    store1 = tmp_path / "store1.p12"
    import_into_store(store1, certs2, "alias1")

    result = extra_ca.java_cacerts_result(expected1, keystore_arguments(store1), absent1)

    assert not result.passed
    assert "is not in Java cacerts" in result.detail
