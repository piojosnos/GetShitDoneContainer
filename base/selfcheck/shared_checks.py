# ------------------------------------------------------------------------------
# The checks every sandbox image shares
# ------------------------------------------------------------------------------
# The launcher runs CHECK_LIST first. The image puts this file in
# /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

from checks_certs import CERT_CHECK_LIST
from checks_env import ENV_CHECK_LIST
from checks_sandbox import SANDBOX_CHECK_LIST
from checks_tools import TOOL_CHECK_LIST
from selfcheck_core import Check

CHECK_LIST: list[Check] = SANDBOX_CHECK_LIST + ENV_CHECK_LIST + TOOL_CHECK_LIST + CERT_CHECK_LIST
