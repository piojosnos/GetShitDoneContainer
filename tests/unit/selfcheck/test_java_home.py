# --------------------------------------------------------------------------------
# Tests of the JAVA_HOME check
# --------------------------------------------------------------------------------

from helpers import load_shared_check

java_home = load_shared_check("130_java_home")


# --------------------------------------------------------------------------------
# JAVA_HOME
# --------------------------------------------------------------------------------

def test_the_check_names_java_home_in_its_result():
    result = java_home.CHECK_LIST[0].function()

    assert "JAVA_HOME" in result.detail
