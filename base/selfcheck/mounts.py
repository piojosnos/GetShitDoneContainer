# --------------------------------------------------------------------------------
# The mount points of the sandbox
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/.
# --------------------------------------------------------------------------------

from pathlib import Path

MOUNTINFO_FILE = Path("/proc/self/mountinfo")


# --------------------------------------------------------------------------------
# Mount points
# --------------------------------------------------------------------------------

def _mount_point_set(mountinfo_text: str) -> set[str]:
    mount_point_found_set = set()

    for line in mountinfo_text.splitlines():
        field_list = line.split()

        if len(field_list) < 5:
            continue

        mount_point_found_set.add(field_list[4])

    return mount_point_found_set


# --------------------------------------------------------------------------------

def read_mount_point_set(mountinfo_file: Path = MOUNTINFO_FILE) -> set[str]:
    return _mount_point_set(mountinfo_file.read_text())
