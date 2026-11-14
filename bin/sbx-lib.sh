#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared by the sbx-* host scripts: registry, name rule, Compose, start wait
# ------------------------------------------------------------------------------
# A library: defines variables and functions, runs nothing, sets no options.
# Stock bash 3.2 with BSD tools, because it runs in the Mac shell.
# ------------------------------------------------------------------------------

knownAgentList="claude cursor"
knownImageTagList="local test"
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
  echo "Usage: ${scriptName:-${0##*/}}${1:+ $1}" >&2
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
# check_image_tag: sets imageTag from SBX_IMAGE_TAG; only local and test pass
# ------------------------------------------------------------------------------
# Unset or empty means local, as in compose.yml and build.sh. Any other value is
# refused, so a typo cannot make a third set of images. An accepted tag other
# than local is named on stderr, so a value left in the shell never moves a real
# sandbox onto other images unseen.
# ------------------------------------------------------------------------------
check_image_tag() {
  local knownTag

  imageTag=${SBX_IMAGE_TAG:-local}

  for knownTag in $knownImageTagList; do
    if [ "$imageTag" = "$knownTag" ]; then
      if [ "$imageTag" != "local" ]; then
        echo "$scriptName: using the $imageTag images because SBX_IMAGE_TAG=$imageTag; unset it to use the local images your sandboxes run" >&2
      fi

      return 0
    fi
  done

  sbx_error "SBX_IMAGE_TAG must be ${knownImageTagList// / or }, not '$imageTag'"
  return 1
}

# ------------------------------------------------------------------------------
# sbx_init: sets scriptName, repoDir, the registry folder and the name rule
# ------------------------------------------------------------------------------
# repoDir comes from the place of this library, not from $0, so a test that
# sources the library finds the repo too. COMPOSE_* variables are unset, and the
# image tag is checked here, before any script registers or builds anything.
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

  check_image_tag || return 1
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
# is_known_agent AGENT: true when AGENT is in knownAgentList
# ------------------------------------------------------------------------------
is_known_agent() {
  local knownAgent

  for knownAgent in $knownAgentList; do
    if [ "$1" = "$knownAgent" ]; then
      return 0
    fi
  done

  return 1
}

# ------------------------------------------------------------------------------
# read_registry_entry NAME: sets entryFile, entryDir, entryAgent and agentImage
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
  agentImage=""

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

  if ! is_known_agent "$entryAgent"; then
    sbx_error "the entry $entryFile names agent '$entryAgent'; the known agents are: $knownAgentList"
    return 1
  fi

  agentImage=sbx-$entryAgent:$imageTag
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
# SBX_NAME, SBX_DIR and SBX_AGENT are set on this one command, never taken from
# the caller. SBX_IMAGE_TAG comes from the caller, but only as the value
# check_image_tag accepted.
# ------------------------------------------------------------------------------
run_compose() {
  local sandboxName=$1

  shift
  SBX_NAME="$sandboxName" SBX_DIR="$entryDir" SBX_IMAGE_TAG="$imageTag" SBX_AGENT="$entryAgent" docker compose --env-file /dev/null -p "sbx-$sandboxName" -f "$repoDir/compose.yml" "$@" </dev/null
}

# ------------------------------------------------------------------------------
# require_docker: Docker must answer before a missing image or container counts
# ------------------------------------------------------------------------------
# With Docker stopped every image and container looks missing.
# ------------------------------------------------------------------------------
require_docker() {
  if ! docker info >/dev/null 2>&1 </dev/null; then
    sbx_error "cannot reach Docker; is Docker running?"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# require_images NAME: the sandbox's agent image must exist before it starts
# ------------------------------------------------------------------------------
# Docker must answer first, or sbx-upgrade would be the wrong advice.
# ------------------------------------------------------------------------------
require_images() {
  local sandboxName=$1

  require_docker || return 1

  if ! docker image inspect "$agentImage" >/dev/null 2>&1 </dev/null; then
    sbx_error "$agentImage is not built; run: sbx-upgrade $sandboxName (it builds the images and starts the sandbox)"
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
# runs_older_image NAME: true when sbx-NAME runs on another image than current
# ------------------------------------------------------------------------------
# A missing or stopped container, a failed inspect or an empty id is false, so
# no caller warns or marks by mistake. It prints nothing.
# ------------------------------------------------------------------------------
runs_older_image() {
  local runningImage
  local currentImage

  if ! sandbox_is_running "$1"; then
    return 1
  fi

  runningImage=$(docker container inspect --format '{{.Image}}' "sbx-$1" 2>/dev/null </dev/null) || return 1
  currentImage=$(docker image inspect --format '{{.Id}}' "$agentImage" 2>/dev/null </dev/null) || return 1

  [ -n "$runningImage" ] && [ -n "$currentImage" ] && [ "$runningImage" != "$currentImage" ]
}

# ------------------------------------------------------------------------------
# warn_sessions_close NAME LEAD: warns that sbx-NAME loses its open sessions
# ------------------------------------------------------------------------------
# LEAD says why and ends with the recreate or the removal, e.g. "is running;
# removing it". One wording for every script that recreates or removes one.
# ------------------------------------------------------------------------------
warn_sessions_close() {
  echo "$scriptName: sbx-$1 $2 will close its open shells and Claude sessions"
}

# ------------------------------------------------------------------------------
# wait_until_ready NAME: returns 0 once the start hooks of sbx-NAME are done
# ------------------------------------------------------------------------------
# The entrypoint runs sleep after its last start hook, so a running sleep means
# done. A compose healthcheck that waits for the hooks should replace this poll.
# A container that is gone counts as stopped: the failed inspect must not end
# the caller, which runs under set -e, before the error is printed.
# ------------------------------------------------------------------------------
wait_until_ready() {
  local sandboxName=$1
  local waitedSeconds=0
  local running

  while [ "$waitedSeconds" -lt "$startLimitSeconds" ]; do
    if docker exec "sbx-$sandboxName" pgrep -x sleep >/dev/null 2>&1 </dev/null; then
      return 0
    fi

    running=$(docker container inspect --format '{{.State.Running}}' "sbx-$sandboxName" 2>/dev/null </dev/null) || running=""

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

# ------------------------------------------------------------------------------
# bring_up_sandbox NAME: folders, image, then up and the start-hook wait
# ------------------------------------------------------------------------------
# The caller read the registry entry. A running sandbox on an older image is
# recreated by up, after the sessions warning.
# ------------------------------------------------------------------------------
bring_up_sandbox() {
  local sandboxName=$1

  check_sandbox_folders "$sandboxName" || return 1
  require_images "$sandboxName" || return 1

  if runs_older_image "$sandboxName"; then
    warn_sessions_close "$sandboxName" "runs on an older image; recreating it on the new one"
  fi

  if ! run_compose "$sandboxName" up -d --wait; then
    sbx_error "docker compose up failed; docker logs sbx-$sandboxName shows why"
    return 1
  fi

  wait_until_ready "$sandboxName"
}
