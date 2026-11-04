#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# The container start steps as functions; base/sbx-entrypoint runs them
# ------------------------------------------------------------------------------
# A library: defines variables and functions, runs nothing, sets no options.
# ------------------------------------------------------------------------------

ws=/home/sandbox/workspace
state=$ws/state
hookDir=/etc/sbx/start.d

# Compose lowercases a project name, so two names that differ only in case would
# share one project.
sandboxNamePattern='^[a-z][a-z0-9-]{0,30}$'
sandboxNameRuleText='starts with a lowercase letter, then lowercase letters, digits or hyphens, 31 characters at most'

# ------------------------------------------------------------------------------
# is_mount PATH: true when PATH is a mount point
# ------------------------------------------------------------------------------
# Field 5 of /proc/self/mountinfo is the mount point; no util-linux needed.
# ------------------------------------------------------------------------------
is_mount() { awk -v p="$1" '$5==p { f=1 } END { exit !f }' /proc/self/mountinfo; }

# ------------------------------------------------------------------------------
# start_error MESSAGE: prints the error and how to start the sandbox
# ------------------------------------------------------------------------------
# Every step prints its error here and returns 1; the entrypoint stops.
# ------------------------------------------------------------------------------
start_error() {
  echo "[sbx] ERROR: $1" >&2
  echo "[sbx]        Start the sandbox with 'docker compose up' (see SANDBOX.md)." >&2
}

# ------------------------------------------------------------------------------
# check_workspace_mount: needs a writable mount point and SBX_NAME set
# ------------------------------------------------------------------------------
# A plain docker run or a broken compose file would put data in the container
# layer, lost on recreate.
# ------------------------------------------------------------------------------
check_workspace_mount() {
  is_mount "$ws" || { start_error "$ws is not a mount point; its data would be lost on recreate."; return 1; }
  [ -w "$ws" ] || { start_error "$ws is not writable by $(id -un)."; return 1; }
  [ -n "${SBX_NAME:-}" ] || { start_error "SBX_NAME is not set."; return 1; }
}

# ------------------------------------------------------------------------------
# check_sandbox_name: SBX_NAME must follow the sandbox name rule
# ------------------------------------------------------------------------------
# The name becomes a folder, so it is checked first; state and best-practices
# are taken. LC_ALL=C makes [a-z] the 26 ASCII letters in any locale.
# ------------------------------------------------------------------------------
check_sandbox_name() {
  local LC_ALL=C

  if [[ ! "${SBX_NAME:-}" =~ $sandboxNamePattern ]]; then
    start_error "SBX_NAME \"${SBX_NAME:-}\" breaks the sandbox name rule: $sandboxNameRuleText. Example: my-project."
    return 1
  fi

  case "$SBX_NAME" in
    state | best-practices)
      start_error "SBX_NAME \"$SBX_NAME\" is taken: $ws/$SBX_NAME is one of the sandbox's own folders. Pick another name."
      return 1
      ;;
  esac
}

# ------------------------------------------------------------------------------
# check_project_and_state_folders: both exist and the state one is writable
# ------------------------------------------------------------------------------
# A mistyped SBX_DIR has neither.
# ------------------------------------------------------------------------------
check_project_and_state_folders() {
  [ -d "$ws/$SBX_NAME" ] || { start_error "$ws/$SBX_NAME (the project folder) is missing."; return 1; }
  [ -d "$state" ] || { start_error "$state is missing."; return 1; }
  [ -w "$state" ] || { start_error "$state is not writable by $(id -un)."; return 1; }
}

# ------------------------------------------------------------------------------
# create_state_dirs: creates the state subfolders that are missing
# ------------------------------------------------------------------------------
# SBX_STATE_DIRS adds the agent image's folders (Claude adds claude), so this
# base never needs to know which agent is on top.
# ------------------------------------------------------------------------------
create_state_dirs() {
  local stateFolder
  local stateFolderList

  # The list is split on spaces only; a * or ? in a name is never expanded.
  read -r -a stateFolderList <<< "shell gh git ${SBX_STATE_DIRS:-}"

  for stateFolder in "${stateFolderList[@]}"; do
    mkdir -p "$state/$stateFolder" || return 1
  done
}

# ------------------------------------------------------------------------------
# run_start_hooks: runs each hook in name order; a bad entry stops the start
# ------------------------------------------------------------------------------
# Names sort as text, so hooks use two-digit prefixes (10-, 20-). Folders are
# skipped; any other entry that is not an executable file is refused.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# enter_project_folder: changes to the project folder
# ------------------------------------------------------------------------------
# The command runs there; docker exec shells pick their own folder with -w.
# ------------------------------------------------------------------------------
enter_project_folder() {
  cd "$ws/$SBX_NAME" || { start_error "cannot enter $ws/$SBX_NAME."; return 1; }
}
