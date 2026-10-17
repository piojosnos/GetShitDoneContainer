#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-14: wrappers, hooks and settings in the image: root-owned, no bundle copy
# ------------------------------------------------------------------------------
# Needs: test sandbox running
# The bundle itself is the sandbox's clone; the image holds only the tools.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

cloneDir=/home/sandbox/workspace/best-practices

# ------------------------------------------------------------------------------
# Runs one probe in the container for owners, writable paths, mounts and values
# ------------------------------------------------------------------------------
# The probe also reports the env values and the managed settings entries.
# ------------------------------------------------------------------------------
probe_container() {
  local probeScript

  probeScript=$(cat <<'PROBE'
: h14-probe;
for probePath in /etc/sbx/start.d /etc/sbx/start.d/05-gsd /etc/sbx/start.d/10-best-practices /etc/claude-code/managed-settings.json /usr/local/bin/sbx-gh-login /usr/local/bin/sbx-bundle-clone /usr/local/bin/sbx-claude; do
  find "$probePath" -maxdepth 0 -printf 'OWNER %p %u:%g %m\n';
done;
find /etc/sbx/start.d /etc/claude-code /usr/local/bin/sbx-gh-login /usr/local/bin/sbx-bundle-clone /usr/local/bin/sbx-claude -writable | sed 's/^/WRITABLE /';
awk '{ print $5 }' /proc/self/mountinfo | grep -E '^(/etc/sbx|/etc/claude-code|/usr/local/bin)(/|$)' | sed 's/^/MOUNT /';
if [ -e /opt/sbx/best-practices ]; then
  echo 'BUNDLE COPY';
fi;
echo "URL $BUNDLE_REPO_URL";
echo "DIR $SBX_BUNDLE_DIR";
node -e 'try { const s = JSON.parse(require("fs").readFileSync("/etc/claude-code/managed-settings.json", "utf8")); const p = s.permissions || {}; for (const d of p.additionalDirectories || []) { console.log("ADDDIR " + d); } for (const d of p.deny || []) { console.log("DENY " + d); } } catch (e) { console.log("JSON bad"); }'
PROBE
)
  probeOutput=$(in_container sh -c "$probeScript")
}

# ------------------------------------------------------------------------------
# Checks owner and mode of the hook folder, hooks, wrappers and settings
# ------------------------------------------------------------------------------
check_owners_and_modes() {
  local expected expectedPath expectedMode ownerLine

  for expected in "/etc/sbx/start.d 755" "/etc/sbx/start.d/05-gsd 755" "/etc/sbx/start.d/10-best-practices 755" "/usr/local/bin/sbx-gh-login 755" "/usr/local/bin/sbx-bundle-clone 755" "/usr/local/bin/sbx-claude 755" "/etc/claude-code/managed-settings.json 644"; do
    expectedPath=${expected% *}
    expectedMode=${expected#* }
    ownerLine=$(printf '%s\n' "$probeOutput" | grep -F "OWNER $expectedPath ")

    if [ "$ownerLine" != "OWNER $expectedPath root:root $expectedMode" ]; then
      add_problem "$expectedPath is '${ownerLine#OWNER $expectedPath }' (owner:group mode); expected 'root:root $expectedMode'"
    fi
  done
}

# ------------------------------------------------------------------------------
# Checks the sandbox user can write nothing there and no mount sits there
# ------------------------------------------------------------------------------
check_read_only_and_unmounted() {
  local writableLines mountLines

  writableLines=$(printf '%s\n' "$probeOutput" | grep '^WRITABLE ')
  mountLines=$(printf '%s\n' "$probeOutput" | grep '^MOUNT ')

  if [ -n "$writableLines" ]; then
    add_problem "the sandbox user can write: $(first_lines "$(printf '%s\n' "$writableLines" | sed 's/^WRITABLE //')")"
  fi

  if [ -n "$mountLines" ]; then
    add_problem "a mount sits under the hook, wrapper or managed settings paths: $(first_lines "$(printf '%s\n' "$mountLines" | sed 's/^MOUNT //')")"
  fi
}

# ------------------------------------------------------------------------------
# Checks the image holds no copy of the bundle
# ------------------------------------------------------------------------------
check_no_bundle_copy() {
  if printf '%s\n' "$probeOutput" | grep -Fxq 'BUNDLE COPY'; then
    add_problem "the image holds a bundle copy at /opt/sbx/best-practices"
  fi
}

# ------------------------------------------------------------------------------
# Checks BUNDLE_REPO_URL equals versions.env and SBX_BUNDLE_DIR is the clone
# ------------------------------------------------------------------------------
check_env_values() {
  local urlLine dirLine pinnedUrl

  pinnedUrl=$(pin_of BUNDLE_REPO_URL)
  urlLine=$(printf '%s\n' "$probeOutput" | grep '^URL ')
  dirLine=$(printf '%s\n' "$probeOutput" | grep '^DIR ')

  if [ "$urlLine" != "URL $pinnedUrl" ]; then
    add_problem "BUNDLE_REPO_URL in the image is '${urlLine#URL }'; versions.env pins '$pinnedUrl'"
  fi

  if [ "$dirLine" != "DIR $cloneDir" ]; then
    add_problem "SBX_BUNDLE_DIR in the image is '${dirLine#DIR }'; expected '$cloneDir'"
  fi
}

# ------------------------------------------------------------------------------
# Checks the managed settings parse, name the clone and deny only the skills
# ------------------------------------------------------------------------------
# The deny list is the two entries of claude/managed-settings.json; a deny on
# the rules link would also block the clone, so none is allowed.
# ------------------------------------------------------------------------------
check_managed_settings() {
  local addDirLines denyLines expectedAddDir expectedDeny

  if printf '%s\n' "$probeOutput" | grep -Fxq 'JSON bad'; then
    add_problem "the managed settings in /etc/claude-code do not parse as JSON"

    return
  fi

  addDirLines=$(printf '%s\n' "$probeOutput" | grep '^ADDDIR ')
  denyLines=$(printf '%s\n' "$probeOutput" | grep '^DENY ')
  expectedAddDir="ADDDIR /home/sandbox/workspace/best-practices"
  expectedDeny=$(printf '%s\n%s' "DENY Edit(//home/sandbox/workspace/state/claude/.best-practices-skills)" "DENY Edit(//home/sandbox/workspace/state/claude/skills/**)")

  if [ "$addDirLines" != "$expectedAddDir" ]; then
    add_problem "the managed settings' additional directories are '$(join_lines "$addDirLines")'; expected only '$expectedAddDir'"
  fi

  if [ "$denyLines" != "$expectedDeny" ]; then
    add_problem "the managed settings' deny entries are '$(join_lines "$denyLines")'; expected the skill list and skills/** entries only"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-14 || exit 1
probe_container
check_owners_and_modes
check_read_only_and_unmounted
check_no_bundle_copy
check_env_values
check_managed_settings
report_check H-14 "the wrappers, hooks or settings in the image are wrong" \
  "the wrappers, hooks and settings are root-owned, read-only to sandbox and unmounted; no bundle copy; BUNDLE_REPO_URL and SBX_BUNDLE_DIR match; the clone is the one additional directory"
