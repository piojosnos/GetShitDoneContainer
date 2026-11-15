# ------------------------------------------------------------------------------
# Tests of the extra root certificate checks
# ------------------------------------------------------------------------------
# The certificates are made by openssl and the keystores by keytool, both real,
# inside tmp_path.
# ------------------------------------------------------------------------------

import shutil
import subprocess
from pathlib import Path

import pytest

import checks_certs


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

KEYTOOL_PASSWORD = "changeit"
BEGIN_MARKER = "-----BEGIN CERTIFICATE-----"
END_MARKER = "-----END CERTIFICATE-----"

pytestmark = pytest.mark.skipif(
    shutil.which("openssl") is None or shutil.which("keytool") is None,
    reason="openssl and keytool are needed to make the certificates",
)


def openssl_fingerprint(certificate_file: Path) -> str:
    completed = subprocess.run(
        ["openssl", "x509", "-noout", "-fingerprint", "-sha256", "-in", str(certificate_file)],
        check=True,
        capture_output=True,
        text=True,
    )

    return completed.stdout.strip().partition("=")[2].replace(":", "").upper()


def import_into_store(store_file: Path, certificate_file: Path, alias: str) -> None:
    subprocess.run(
        [
            "keytool", "-importcert", "-noprompt", "-keystore", str(store_file), "-storepass", KEYTOOL_PASSWORD,
            "-alias", alias, "-file", str(certificate_file),
        ],
        check=True,
        capture_output=True,
    )


def keystore_arguments(store_file: Path) -> list[str]:
    return ["-keystore", str(store_file), "-storepass", KEYTOOL_PASSWORD]


@pytest.fixture
def certs1(make_certificate) -> Path:
    return make_certificate("certs1")


@pytest.fixture
def certs2(make_certificate) -> Path:
    return make_certificate("certs2")


@pytest.fixture
def extra1(tmp_path, certs1) -> Path:
    extra_dir = tmp_path / "extra1"
    extra_dir.mkdir()
    shutil.copy(certs1, extra_dir / "sbx-extra-ca-1.crt")

    return extra_dir


@pytest.fixture
def bundle1(tmp_path, certs1, certs2) -> Path:
    bundle_file = tmp_path / "bundle1.crt"
    bundle_file.write_text(certs2.read_text() + "\n" + certs1.read_text())

    return bundle_file


# ------------------------------------------------------------------------------
# Certificate parsing
# ------------------------------------------------------------------------------

def test_pem_block_list_splits_two_certificates_joined_by_a_blank_line(certs1, certs2):
    text = certs1.read_text() + "\n" + certs2.read_text()

    block_list = checks_certs.pem_block_list(text)

    assert len(block_list) == 2
    assert block_list[0].startswith(BEGIN_MARKER)
    assert block_list[0].endswith(END_MARKER)
    assert block_list[1].startswith(BEGIN_MARKER)


def test_pem_block_list_ignores_text_around_the_blocks(certs1):
    text = "comment line1\n" + certs1.read_text() + "trailing line2\n"

    assert len(checks_certs.pem_block_list(text)) == 1


def test_pem_block_list_of_text_without_a_certificate_is_empty():
    assert checks_certs.pem_block_list("nothing here\n") == []


def test_pem_fingerprint_equals_the_one_openssl_prints(certs1):
    block = checks_certs.pem_block_list(certs1.read_text())[0]

    assert checks_certs.pem_fingerprint(block) == openssl_fingerprint(certs1)


def test_extra_cert_fingerprint_map_is_keyed_by_the_file_stem(tmp_path, certs1, certs2):
    extra2 = tmp_path / "extra2"
    extra2.mkdir()
    shutil.copy(certs1, extra2 / "sbx-extra-ca-1.crt")
    shutil.copy(certs2, extra2 / "sbx-extra-ca-2.crt")
    shutil.copy(certs2, extra2 / "other1.crt")

    fingerprint_by_alias_map = checks_certs.extra_cert_fingerprint_by_alias_map(extra2)

    assert fingerprint_by_alias_map == {
        "sbx-extra-ca-1": openssl_fingerprint(certs1),
        "sbx-extra-ca-2": openssl_fingerprint(certs2),
    }


def test_keytool_helpers_read_the_aliases_and_fingerprints_of_a_listing(tmp_path, certs1, certs2):
    store1 = tmp_path / "store1.p12"
    import_into_store(store1, certs1, "alias1")
    import_into_store(store1, certs2, "alias2")
    listing = subprocess.run(
        ["keytool", "-list"] + keystore_arguments(store1), check=True, capture_output=True, text=True
    ).stdout

    assert checks_certs.keytool_alias_set(listing) == {"alias1", "alias2"}
    assert checks_certs.keytool_fingerprint_set(listing) == {openssl_fingerprint(certs1), openssl_fingerprint(certs2)}


# ------------------------------------------------------------------------------
# System bundle check
# ------------------------------------------------------------------------------

def test_system_bundle_passes_and_prints_the_alias_and_the_fingerprint(extra1, bundle1, certs1):
    result = checks_certs.system_bundle_result(extra1, bundle1)

    assert result.passed
    assert "sbx-extra-ca-1" in result.detail
    assert openssl_fingerprint(certs1) in result.detail


def test_system_bundle_fails_naming_the_certificate_the_bundle_lacks(tmp_path, extra1, certs2):
    bundle2 = tmp_path / "bundle2.crt"
    bundle2.write_text(certs2.read_text())

    result = checks_certs.system_bundle_result(extra1, bundle2)

    assert not result.passed
    assert "sbx-extra-ca-1" in result.detail
    assert "sbx-upgrade" in result.hint


def test_system_bundle_is_not_fooled_by_a_bundle_with_as_many_other_certificates(tmp_path, extra1, certs2):
    bundle2 = tmp_path / "bundle2.crt"
    bundle2.write_text(certs2.read_text())

    assert len(checks_certs.pem_block_list(bundle2.read_text())) == 1
    assert not checks_certs.system_bundle_result(extra1, bundle2).passed


def test_system_bundle_passes_with_no_extra_certificate_and_reads_no_bundle(tmp_path):
    empty_dir = tmp_path / "empty1"
    empty_dir.mkdir()

    result = checks_certs.system_bundle_result(empty_dir, tmp_path / "missing1.crt")

    assert result.passed
    assert result.detail == "no extra root certificate installed"


# ------------------------------------------------------------------------------
# Java cacerts check
# ------------------------------------------------------------------------------

def test_java_cacerts_passes_when_the_alias_and_the_fingerprint_are_in_the_store(tmp_path, extra1, certs1):
    store1 = tmp_path / "store1.p12"
    import_into_store(store1, certs1, "sbx-extra-ca-1")

    result = checks_certs.java_cacerts_result(extra1, keystore_arguments(store1))

    assert result.passed
    assert "sbx-extra-ca-1" in result.detail
    assert openssl_fingerprint(certs1) in result.detail


def test_java_cacerts_fails_naming_the_second_certificate_the_store_lacks(tmp_path, extra1, certs1, certs2):
    store1 = tmp_path / "store1.p12"
    import_into_store(store1, certs1, "sbx-extra-ca-1")
    shutil.copy(certs2, extra1 / "sbx-extra-ca-2.crt")

    result = checks_certs.java_cacerts_result(extra1, keystore_arguments(store1))

    assert not result.passed
    assert "sbx-extra-ca-2" in result.detail
    assert "sbx-extra-ca-1" not in result.detail
    assert "sbx-upgrade" in result.hint


def test_java_cacerts_fails_naming_the_alias_when_the_certificate_sits_under_another_alias(
    tmp_path, extra1, certs1, certs2
):
    store1 = tmp_path / "store1.p12"
    import_into_store(store1, certs1, "sbx-extra-ca-1")
    import_into_store(store1, certs2, "other1")
    shutil.copy(certs2, extra1 / "sbx-extra-ca-2.crt")

    result = checks_certs.java_cacerts_result(extra1, keystore_arguments(store1))

    assert not result.passed
    assert "sbx-extra-ca-2" in result.detail


def test_java_cacerts_fails_when_the_alias_holds_another_certificate(tmp_path, extra1, certs2):
    store1 = tmp_path / "store1.p12"
    import_into_store(store1, certs2, "sbx-extra-ca-1")

    result = checks_certs.java_cacerts_result(extra1, keystore_arguments(store1))

    assert not result.passed
    assert "sbx-extra-ca-1" in result.detail


def test_java_cacerts_reports_a_keytool_failure_with_its_first_line(tmp_path, extra1):
    result = checks_certs.java_cacerts_result(extra1, keystore_arguments(tmp_path / "missing1.p12"))

    assert not result.passed
    assert "keytool" in result.detail


def test_java_cacerts_with_no_extra_certificate_passes_without_running_keytool(tmp_path):
    empty_dir = tmp_path / "empty1"
    empty_dir.mkdir()

    result = checks_certs.java_cacerts_result(empty_dir, keystore_arguments(tmp_path / "missing1.p12"))

    assert result.passed
    assert result.detail == "no extra root certificate installed"
