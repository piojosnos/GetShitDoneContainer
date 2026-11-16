# ------------------------------------------------------------------------------
# Check: JAVA_HOME points at the image's JDK
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from environment_values import environment_values_result


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_java_home() -> CheckResult:
    return environment_values_result({"JAVA_HOME": "/opt/java/openjdk"})


CHECK_LIST = [Check("java-home", _check_java_home)]
