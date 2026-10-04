#!/usr/bin/env bash
# H-14: the image holds the bundle at /opt/sbx/best-practices, equal to the repo, root-owned, outside every mount; the hook and the managed settings are in place.
# - The bundle is copied out of the container with docker cp into a fresh folder in the run folder's
#   logs/ (the printed cleanup removes it) and compared with best-practices/ in the repo.
# - One probe inside the container reports the owner and mode of the bundle, the hook folder, the hook
#   and the managed settings; anything the sandbox user can write under those folders; any mount point
#   under them; and whether the managed settings parse.
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-14 || exit 1

copyDir=$RUN/logs/h14-bundle-$$-$(date +%s)

set --

if ! docker cp "$CONTAINER:/opt/sbx/best-practices" "$copyDir" </dev/null >/dev/null 2>&1; then
  set -- "$@" "docker cp could not copy /opt/sbx/best-practices out of $CONTAINER"
else
  diffOutput=$(diff -r -x .DS_Store "$REPO_DIR/best-practices" "$copyDir" 2>&1)
  if [ "$?" -ne 0 ]; then
    set -- "$@" "the bundle in the image differs from best-practices/ in the repo: $(printf '%s\n' "$diffOutput" | head -n 3 | tr '\n' ' ')"
  fi
fi

probeScript=$(cat <<'PROBE'
: h14-probe;
for probePath in /opt/sbx/best-practices /etc/sbx/start.d /etc/sbx/start.d/10-best-practices /etc/claude-code/managed-settings.json; do
  find "$probePath" -maxdepth 0 -printf 'OWNER %p %u:%g %m\n';
done;
find /opt/sbx/best-practices /etc/sbx/start.d /etc/claude-code -writable | sed 's/^/WRITABLE /';
awk '{ print $5 }' /proc/self/mountinfo | grep -E '^(/opt/sbx|/etc/sbx|/etc/claude-code)(/|$)' | sed 's/^/MOUNT /';
if node -e 'JSON.parse(require("fs").readFileSync("/etc/claude-code/managed-settings.json", "utf8"))' 2>/dev/null; then
  echo 'JSON ok';
else
  echo 'JSON bad';
fi
PROBE
)
probeOutput=$(in_container sh -c "$probeScript")

for expected in "/opt/sbx/best-practices 755" "/etc/sbx/start.d 755" "/etc/sbx/start.d/10-best-practices 755" "/etc/claude-code/managed-settings.json 644"; do
  expectedPath=${expected% *}
  expectedMode=${expected#* }
  ownerLine=$(printf '%s\n' "$probeOutput" | grep -F "OWNER $expectedPath ")
  if [ "$ownerLine" != "OWNER $expectedPath root:root $expectedMode" ]; then
    set -- "$@" "$expectedPath is '${ownerLine#OWNER $expectedPath }' (owner:group mode); expected 'root:root $expectedMode'"
  fi
done

writableLines=$(printf '%s\n' "$probeOutput" | grep '^WRITABLE ')
if [ -n "$writableLines" ]; then
  set -- "$@" "the sandbox user can write: $(printf '%s\n' "$writableLines" | sed 's/^WRITABLE //' | head -n 3 | tr '\n' ' ')"
fi

mountLines=$(printf '%s\n' "$probeOutput" | grep '^MOUNT ')
if [ -n "$mountLines" ]; then
  set -- "$@" "a mount sits under the bundle, hook or managed settings folders: $(printf '%s\n' "$mountLines" | sed 's/^MOUNT //' | head -n 3 | tr '\n' ' ')"
fi

if ! printf '%s\n' "$probeOutput" | grep -Fxq 'JSON ok'; then
  set -- "$@" "the managed settings in /etc/claude-code do not parse as JSON"
fi

if [ "$#" -gt 0 ]; then
  fail H-14 "the bundle, the hook or the managed settings in the image are wrong" "$@"
  exit 1
fi

pass H-14 "the bundle in the image equals the repo; bundle, hook and managed settings are root-owned, read-only to sandbox and outside every mount"
exit 0
