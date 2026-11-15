# ------------------------------------------------------------------------------
# The sandbox user
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import pwd

SANDBOX_USER = "sandbox"
SANDBOX_UID = 1000
SANDBOX_GID = 1000


# ------------------------------------------------------------------------------
# User names
# ------------------------------------------------------------------------------

def user_name_of(uid: int) -> str:
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return "unknown"
