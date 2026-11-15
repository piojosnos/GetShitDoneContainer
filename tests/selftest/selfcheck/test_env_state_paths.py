# ------------------------------------------------------------------------------
# Tests of the state variables check
# ------------------------------------------------------------------------------

import environment_values
import paths
from helpers import load_shared_check

env_state_paths = load_shared_check("110_env_state_paths")


# ------------------------------------------------------------------------------
# State variables
# ------------------------------------------------------------------------------

def test_every_state_variable_points_under_the_state_folder():
    for name, value in env_state_paths._STATE_PATH_BY_NAME_MAP.items():
        assert value.startswith(str(paths.STATE_DIR) + "/"), name


def test_state_variables_pass_when_the_environment_holds_them():
    environment1 = dict(env_state_paths._STATE_PATH_BY_NAME_MAP)

    assert environment_values.environment_values_result(env_state_paths._STATE_PATH_BY_NAME_MAP, environment1).passed

