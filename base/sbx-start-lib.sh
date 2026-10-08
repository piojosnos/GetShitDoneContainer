#!/usr/bin/env bash
# The container start steps, as functions: the mount check, the name check, the folder checks, the
# state folders, the start hooks and the move into the project folder.
# - A library: it defines variables and functions and runs nothing. base/sbx-entrypoint
#   sources it from its own folder and runs the steps; the self-tests source it to call them.
# - Sets no shell options; the entrypoint sets set -eu before sourcing it.
# - Every step prints its [sbx] ERROR line and returns 1 on a failure; the entrypoint decides to stop.

ws=/home/sandbox/workspace
state=$ws/state
hookDir=/etc/sbx/start.d

# SBX_NAME names the project folder, the container and the Compose project. Compose turns a
# project name into lowercase, so two names that differ only in case would share one project.
sandboxNamePattern='^[a-z][a-z0-9-]{0,30}$'
sandboxNameRuleText='starts with a lowercase letter, then lowercase letters, digits or hyphens, 31 characters at most'

# --------------------------------------------------------------------------------
# is_mount PATH: true when PATH is a mount point.
# --------------------------------------------------------------------------------
# Field 5 of /proc/self/mountinfo is the mount point; no util-linux "mountpoint" needed.
is_mount() { awk -v p="$1" '$5==p { f=1 } END { exit !f }' /proc/self/mountinfo; }

# --------------------------------------------------------------------------------
# start_error MESSAGE: prints the error and how to start the sandbox.
# --------------------------------------------------------------------------------
start_error() {
  echo "[sbx] ERROR: $1" >&2
  echo "[sbx]        Start the sandbox with 'docker compose up' (see SANDBOX.md)." >&2
}

# --------------------------------------------------------------------------------
# Checks the workspace is a writable mount point and SBX_NAME is set; prints the error and returns 1 if not
# --------------------------------------------------------------------------------
check_workspace_mount() {
  is_mount "$ws" || { start_error "$ws is not a mount point; its data would be lost on recreate."; return 1; }
  [ -w "$ws" ] || { start_error "$ws is not writable by $(id -un)."; return 1; }
  [ -n "${SBX_NAME:-}" ] || { start_error "SBX_NAME is not set."; return 1; }
}

# --------------------------------------------------------------------------------
# Checks SBX_NAME follows the sandbox name rule; prints the error and returns 1 if not
# --------------------------------------------------------------------------------
# LC_ALL=C makes [a-z] the 26 ASCII letters in any locale.
check_sandbox_name() {
  local LC_ALL=C

  if [[ ! "${SBX_NAME:-}" =~ $sandboxNamePattern ]]; then
    start_error "SBX_NAME \"${SBX_NAME:-}\" breaks the sandbox name rule: $sandboxNameRuleText. Example: my-project."
    return 1
  fi
}

# --------------------------------------------------------------------------------
# Checks the project and state folders exist; prints the error and returns 1 if not
# --------------------------------------------------------------------------------
check_project_and_state_folders() {
  [ -d "$ws/$SBX_NAME" ] || { start_error "$ws/$SBX_NAME (the project folder) is missing."; return 1; }
  [ -d "$state" ] || { start_error "$state is missing."; return 1; }
  [ -w "$state" ] || { start_error "$state is not writable by $(id -un)."; return 1; }
}

# --------------------------------------------------------------------------------
# Creates the state subfolders that are missing; returns 1 if one cannot be made
# --------------------------------------------------------------------------------
create_state_dirs() {
  local stateFolder
  local stateFolderList

  # The list is split on spaces only; a * or ? in a name is never expanded.
  read -r -a stateFolderList <<< "shell gh git ${SBX_STATE_DIRS:-}"

  for stateFolder in "${stateFolderList[@]}"; do
    mkdir -p "$state/$stateFolder" || return 1
  done
}

# --------------------------------------------------------------------------------
# Runs every start hook in name order; any entry that is not an executable file prints an error and returns 1
# --------------------------------------------------------------------------------
# The hooks run after the checks above and before the command. Names sort as text, so hooks
# use two-digit prefixes (10-, 20-). Folders are skipped; every other entry must be an
# executable regular file, so a dangling link, a fifo or a socket is refused, not skipped.
run_start_hooks() {
  local hook

  for hook in "$hookDir"/*; do
    # Only the unmatched glob of an empty folder is neither present nor a link.
    if [ ! -e "$hook" ] && [ ! -L "$hook" ]; then
      continue
    fi

    if [ -d "$hook" ]; then
      continue
    fi

    if [ ! -f "$hook" ]; then
      echo "[sbx] ERROR: start hook $hook is not a regular file; the container was not started." >&2
      return 1
    fi

    if [ ! -x "$hook" ]; then
      echo "[sbx] ERROR: start hook $hook is not executable; the container was not started." >&2
      return 1
    fi

    if ! "$hook"; then
      echo "[sbx] ERROR: start hook $hook failed; the container was not started." >&2
      return 1
    fi
  done
}

# --------------------------------------------------------------------------------
# Changes to the project folder; prints the error and returns 1 if it cannot
# --------------------------------------------------------------------------------
# The command runs in the project folder. docker exec shells pick their own folder with -w.
enter_project_folder() {
  cd "$ws/$SBX_NAME" || { start_error "cannot enter $ws/$SBX_NAME."; return 1; }
}
