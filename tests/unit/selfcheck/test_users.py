# --------------------------------------------------------------------------------
# Tests of the sandbox user helpers
# --------------------------------------------------------------------------------

import os

import users


# --------------------------------------------------------------------------------
# User names
# --------------------------------------------------------------------------------

def test_user_name_of_names_the_running_user():
    assert users.user_name_of(os.getuid())


def test_user_name_of_says_unknown_for_a_uid_with_no_entry():
    assert users.user_name_of(4294967294) == "unknown"
