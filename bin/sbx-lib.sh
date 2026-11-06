#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared by the sbx-* host scripts: registry, name rule, Compose, start wait
# ------------------------------------------------------------------------------
# A library: defines variables and functions, runs nothing, sets no options.
# Stock bash 3.2 with BSD tools, because it runs in the Mac shell.
# ------------------------------------------------------------------------------

claudeImage=sbx-claude:local
startLimitSeconds=120

# ------------------------------------------------------------------------------
# sbx_error MESSAGE: prints the script name and the error on stderr
# ------------------------------------------------------------------------------
sbx_error() {
  echo "$scriptName: $1" >&2
}

# ------------------------------------------------------------------------------
# sbx_usage ARGS_TEXT: prints the usage line on stderr and exits 2
# ------------------------------------------------------------------------------
# It runs before sbx_init, so the script name is read here when it is not set.
# ------------------------------------------------------------------------------
sbx_usage() {
  echo "Usage: ${scriptName:-${0##*/}} $1" >&2
  exit 2
}

# ------------------------------------------------------------------------------
# read_start_variable VARIABLE: prints VARIABLE as base/sbx-start-lib.sh sets it
# ------------------------------------------------------------------------------
# The file is sourced in a subshell, so its globals stay out of the caller.
# ------------------------------------------------------------------------------
read_start_variable() {
  ( . "$repoDir/base/sbx-start-lib.sh" && printf '%s' "${!1}" )
}

# ------------------------------------------------------------------------------
# load_name_rule: sets the name rule and the reserved names from the image code
# ------------------------------------------------------------------------------
# The rule is written once, in the start library the container runs. It is
# never copied here, so the host scripts and the container cannot disagree.
# ------------------------------------------------------------------------------
load_name_rule() {
  nameRulePattern=$(read_start_variable sandboxNamePattern) || nameRulePattern=""
  nameRuleText=$(read_start_variable sandboxNameRuleText) || nameRuleText=""
  reservedNameList=$(read_start_variable sandboxReservedNameList) || reservedNameList=""

  if [ -z "$nameRulePattern" ] || [ -z "$nameRuleText" ]; then
    sbx_error "cannot read the sandbox name rule from $repoDir/base/sbx-start-lib.sh"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# sbx_init: sets scriptName, repoDir, the registry folder and the name rule
# ------------------------------------------------------------------------------
# repoDir comes from the place of this library, not from $0, so a test that
# sources the library finds the repo too. COMPOSE_* variables are unset.
# ------------------------------------------------------------------------------
sbx_init() {
  local libDir

  scriptName=${0##*/}
  libDir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  repoDir=$(cd "$libDir/.." && pwd -P) || return 1

  configDir=${SBX_CONFIG_DIR:-}

  if [ -z "$configDir" ]; then
    if [ -z "${HOME:-}" ]; then
      sbx_error "HOME and SBX_CONFIG_DIR are both empty; set SBX_CONFIG_DIR to an absolute path"
      return 1
    fi

    configDir=$HOME/.config/sbx
  fi

  if [[ "$configDir" != /* ]]; then
    sbx_error "SBX_CONFIG_DIR must be an absolute path, not '$configDir'"
    return 1
  fi

  registryDir=$configDir/sandboxes

  unset COMPOSE_PROJECT_NAME COMPOSE_FILE COMPOSE_PROFILES COMPOSE_PATH_SEPARATOR COMPOSE_ENV_FILES COMPOSE_IGNORE_ORPHANS COMPOSE_REMOVE_ORPHANS

  load_name_rule
}

# ------------------------------------------------------------------------------
# check_name NAME: NAME must follow the sandbox name rule and not be reserved
# ------------------------------------------------------------------------------
# [[ =~ ]] sees the whole name, so a multi-line name fails; grep would pass one
# good line of it. LC_ALL=C pins [a-z] to ASCII.
# ------------------------------------------------------------------------------
check_name() {
  local LC_ALL=C
  local sandboxName=$1
  local reservedName

  if [[ ! "$sandboxName" =~ $nameRulePattern ]]; then
    sbx_error "'$sandboxName' breaks the sandbox name rule: $nameRuleText. Example: my-project."
    return 1
  fi

  for reservedName in $reservedNameList; do
    if [ "$sandboxName" = "$reservedName" ]; then
      sbx_error "'$sandboxName' is taken: the sandbox folder uses $reservedName/ itself. Pick another name."
      return 1
    fi
  done
}

# ------------------------------------------------------------------------------
# read_registry_entry NAME: sets entryFile, entryDir and entryAgent from NAME
# ------------------------------------------------------------------------------
# The caller checked the name. The file is read line by line as text and never
# sourced, so a value such as $(command) is only a path that does not exist.
# ------------------------------------------------------------------------------
read_registry_entry() {
  local sandboxName=$1
  local line

  entryFile=$registryDir/$sandboxName
  entryDir=""
  entryAgent=""

  if [ ! -f "$entryFile" ]; then
    sbx_error "$sandboxName is not registered; run: sbx-add $sandboxName HOST_PATH"
    return 1
  fi

  if [ ! -r "$entryFile" ]; then
    sbx_error "cannot read $entryFile"
    return 1
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      SBX_DIR=*)
        entryDir=${line#SBX_DIR=}
        ;;
      SBX_AGENT=*)
        entryAgent=${line#SBX_AGENT=}
        ;;
    esac
  done <"$entryFile"

  if [[ "$entryDir" != /* ]]; then
    sbx_error "the entry $entryFile has no absolute SBX_DIR"
    return 1
  fi

  if [ "$entryAgent" != "claude" ]; then
    sbx_error "the entry $entryFile names agent '$entryAgent'; only claude exists"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# check_sandbox_folders NAME: NAME/ and state/ exist in the registered folder
# ------------------------------------------------------------------------------
# Docker would make a missing bind source as root, so this runs first.
# ------------------------------------------------------------------------------
check_sandbox_folders() {
  local sandboxName=$1
  local folderName

  for folderName in "$sandboxName" state; do
    if [ ! -d "$entryDir/$folderName" ]; then
      sbx_error "missing $entryDir/$folderName; create it with mkdir -p, or fix SBX_DIR in $entryFile"
      return 1
    fi
  done
}

# ------------------------------------------------------------------------------
# run_compose NAME ARG...: runs docker compose for the sandbox NAME only
# ------------------------------------------------------------------------------
# -p wins over COMPOSE_PROJECT_NAME; --env-file /dev/null keeps a .env file out.
# SBX_NAME and SBX_DIR are set on this one command, never taken from the caller.
# ------------------------------------------------------------------------------
run_compose() {
  local sandboxName=$1

  shift
  SBX_NAME="$sandboxName" SBX_DIR="$entryDir" docker compose --env-file /dev/null -p "sbx-$sandboxName" -f "$repoDir/compose.yml" "$@" </dev/null
}

# ------------------------------------------------------------------------------
# require_images NAME: the Claude image must exist before the sandbox starts
# ------------------------------------------------------------------------------
require_images() {
  local sandboxName=$1

  if ! docker image inspect "$claudeImage" >/dev/null 2>&1 </dev/null; then
    sbx_error "$claudeImage is not built; run: sbx-upgrade $sandboxName (it builds the images and starts the sandbox)"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# sandbox_is_running NAME: true when the container sbx-NAME is running
# ------------------------------------------------------------------------------
# A missing container is false, not an error.
# ------------------------------------------------------------------------------
sandbox_is_running() {
  local runningState

  runningState=$(docker container inspect --format '{{.State.Running}}' "sbx-$1" 2>/dev/null </dev/null) || return 1

  [ "$runningState" = "true" ]
}

# ------------------------------------------------------------------------------
# wait_until_ready NAME: returns 0 once the start hooks of sbx-NAME are done
# ------------------------------------------------------------------------------
# The entrypoint runs sleep after its last start hook, so a running sleep means
# done. A compose healthcheck that waits for the hooks should replace this poll.
# ------------------------------------------------------------------------------
wait_until_ready() {
  local sandboxName=$1
  local waitedSeconds=0
  local running

  while [ "$waitedSeconds" -lt "$startLimitSeconds" ]; do
    if docker exec "sbx-$sandboxName" pgrep -x sleep >/dev/null 2>&1 </dev/null; then
      return 0
    fi

    running=$(docker container inspect --format '{{.State.Running}}' "sbx-$sandboxName" 2>/dev/null </dev/null)

    if [ "$running" != "true" ]; then
      sbx_error "sbx-$sandboxName stopped during its start; docker logs sbx-$sandboxName shows why"
      return 1
    fi

    sleep 1
    waitedSeconds=$((waitedSeconds + 1))
  done

  sbx_error "the start hooks of sbx-$sandboxName did not finish within $startLimitSeconds s; docker logs sbx-$sandboxName shows them"
  return 1
}
