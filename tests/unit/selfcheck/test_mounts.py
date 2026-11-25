# --------------------------------------------------------------------------------
# Tests of the mount point reader
# --------------------------------------------------------------------------------

import mounts
from helpers import ROOT_MOUNT_LINE, write_mountinfo


# --------------------------------------------------------------------------------
# Mount points
# --------------------------------------------------------------------------------

def test_read_mount_point_set_reads_the_fifth_field_of_each_line(tmp_path):
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, ["/mount1"])

    assert mounts.read_mount_point_set(mountinfo1) == {"/", "/mount1"}


def test_read_mount_point_set_ignores_blank_and_short_lines(tmp_path):
    mountinfo1 = tmp_path / "mountinfo1"
    mountinfo1.write_text("\n1 0 8:1\n" + ROOT_MOUNT_LINE + "\n")

    assert mounts.read_mount_point_set(mountinfo1) == {"/"}
