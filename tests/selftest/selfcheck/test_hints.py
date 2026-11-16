# ------------------------------------------------------------------------------
# Tests of the fix hints
# ------------------------------------------------------------------------------

import hints


# ------------------------------------------------------------------------------
# Hint builders
# ------------------------------------------------------------------------------

def test_hint_builders_name_the_sandbox_from_sbx_name():
    environment1 = {"SBX_NAME": "sbx1"}

    assert hints.rebuild_hint(environment1) == (
        "rebuild the image and recreate the sandbox: on the Mac run: sbx-upgrade sbx1"
    )
    assert hints.restart_hint(environment1) == (
        "restart the sandbox: on the Mac run: sbx-stop sbx1, then sbx-start sbx1"
    )
    assert hints.start_hint(environment1).endswith("on the Mac run: sbx-start sbx1, then sbx-shell sbx1")
    assert hints.shell_hint(environment1).endswith("on the Mac run: sbx-shell sbx1")
    assert hints.init_hint(environment1).endswith("sbx-shell sbx1 opens it")
    assert hints.init_hint(environment1).startswith("run sbx-init in the sandbox shell")


def test_hint_builders_say_name_when_sbx_name_is_unset_or_empty():
    assert hints.rebuild_hint({}).endswith("on the Mac run: sbx-upgrade NAME")
    assert hints.restart_hint({}).endswith("sbx-stop NAME, then sbx-start NAME")
    assert hints.start_hint({}).endswith("sbx-start NAME, then sbx-shell NAME")
    assert hints.shell_hint({}).endswith("sbx-shell NAME")
    assert hints.shell_hint({"SBX_NAME": ""}).endswith("sbx-shell NAME")
    assert hints.init_hint({}).endswith("sbx-shell NAME opens it")


def test_mac_hint_puts_the_action_before_the_command():
    assert hints.mac_hint("do action1", "command1") == "do action1: on the Mac run: command1"
