# ------------------------------------------------------------------------------
# Tests of the tzdata check
# ------------------------------------------------------------------------------

from helpers import load_shared_check

tzdata = load_shared_check("220_tzdata")


# ------------------------------------------------------------------------------
# Tzdata
# ------------------------------------------------------------------------------

def test_tzdata_passes_when_the_utc_zone_file_exists(tmp_path):
    utc_file = tmp_path / "UTC"
    utc_file.write_text("zone1")

    assert tzdata.tzdata_result(utc_file).passed
    assert not tzdata.tzdata_result(tmp_path / "missing1").passed
