#!/usr/bin/env bash
# Guard rules on the host tests: portable, delete nothing, unattended, declared dependencies, only the test sandbox named.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/host-tests.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# host_code_lines FILE...: every non-comment line of the files, as FILE:LINE:TEXT.
# --------------------------------------------------------------------------------
host_code_lines() {
  grep -Hn '^' "$@" 2>/dev/null | grep -Ev '^[^:]+:[0-9]+:[[:space:]]*#'
}

# --------------------------------------------------------------------------------
# no_host_code_matches REGEX EXEMPT FILE...: true if no code line matches REGEX.
# --------------------------------------------------------------------------------
# A line that also matches EXEMPT (when EXEMPT is not empty) is allowed. Prints the offenders.
no_host_code_matches() {
  local regex=$1
  local exempt=$2
  local hits

  shift 2
  hits=$(host_code_lines "$@" | grep -E -- "$regex")
  if [ -n "$hits" ] && [ -n "$exempt" ]; then
    hits=$(printf '%s\n' "$hits" | grep -Ev -- "$exempt")
  fi

  if [ -z "$hits" ]; then
    return 0
  fi
  echo "$hits" | sed 's/^/    /'

  return 1
}

# --------------------------------------------------------------------------------
# host_tests_are_portable: The host tests run on a Mac with stock bash 3.2 and BSD tools: no bash 4 features, no GNU-only options.
# --------------------------------------------------------------------------------
# GNU tools are fine only inside the container (in_container, docker exec).
host_tests_are_portable() {
  no_host_code_matches 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|sed -i|grep -P|readlink -f|date -d|\btimeout\b|sha256sum|echo -e|&>>|\|&|\bjq\b|\bpython3?\b|\bcoproc\b|wait -n|EPOCHSECONDS|local -n' '' $HOST_FILES \
    && no_host_code_matches 'stat -c' 'in_container|docker exec' $HOST_FILES
}

# --------------------------------------------------------------------------------
# host_tests_never_delete: The host tests delete nothing: no rm, no docker removal or prune, no down with a volume flag.
# --------------------------------------------------------------------------------
# Allowed: docker run --rm (a throwaway container) and the cleanup line that print_next_block prints.
host_tests_never_delete() {
  no_host_code_matches '(^|[^A-Za-z0-9_.-])(rm|rmdir|unlink)([[:space:]]|$)|docker[[:space:]]+(container[[:space:]]+rm|rm|rmi|image[[:space:]]+(rm|prune)|system|volume[[:space:]]+(rm|prune))|prune|down[[:space:]].*(-v|--volumes)|find .*-delete' \
    'rm -rf %q' $HOST_FILES
}

# --------------------------------------------------------------------------------
# host_tests_are_unattended: The runner and the checks never wait for a human: no read, no tty flags.
# --------------------------------------------------------------------------------
# tests/host/manual/ is exempt.
host_tests_are_unattended() {
  no_host_code_matches '(:[0-9]+:|[;&|(]|then|do|else)[[:space:]]*read[[:space:]]' '' $HOST_UNATTENDED_FILES \
    && no_host_code_matches 'docker[[:space:]]+(compose[[:space:]]+)?(exec|run)[^|;&]*[[:space:]](-it|-ti|-t|--tty)([[:space:]]|$)' '' $HOST_UNATTENDED_FILES
}

# --------------------------------------------------------------------------------
# host_checks_declare_dependencies: Every check says what it depends on, is named in run-all.sh, and prints its own ID.
# --------------------------------------------------------------------------------
host_checks_declare_dependencies() {
  local file fileId
  local ok=0

  for file in tests/host/h[0-9][0-9]-*.sh tests/host/coexistence.sh; do
    if [ ! -e "$file" ]; then
      continue
    fi

    if [ "$(grep -c '^# Depends on:' "$file")" -ne 1 ]; then
      echo "    $file: needs exactly one '# Depends on:' line"
      ok=1
    fi

    if ! grep -Fq "$(basename "$file")" tests/host/run-all.sh; then
      echo "    $file: is not named in tests/host/run-all.sh"
      ok=1
    fi

    case "$(basename "$file")" in
      h[0-9][0-9]-*)
        fileId=$(basename "$file" | sed -E 's/^h([0-9]{2})-.*/H-\1/')
        if ! grep -Fq "$fileId" "$file"; then
          echo "    $file: does not mention its own ID $fileId"
          ok=1
        fi
        ;;
    esac
  done

  return "$ok"
}

# --------------------------------------------------------------------------------
# host_tests_only_name_the_test_sandbox: Only the test sandbox is named: container sbx-hosttest, images sbx-base and sbx-claude.
# --------------------------------------------------------------------------------
# The old layout's cc_ names appear only where the old containers are compared (Coexistence, the snapshot).
host_tests_only_name_the_test_sandbox() {
  local otherNames oldNames

  nowhere_matches 'sbx-demo|SBX_NAME=demo' $HOST_FILES || return 1

  otherNames=$(grep -ohE 'sbx-[A-Za-z][A-Za-z0-9_]*' $HOST_FILES 2>/dev/null | sort -u | grep -Ev '^sbx-(hosttest|base|claude)$')
  if [ -n "$otherNames" ]; then
    echo "$otherNames" | sed 's/^/    /'
    return 1
  fi

  oldNames=$(grep -En '(^|[^A-Za-z0-9])cc_' $HOST_FILES 2>/dev/null | grep -v 'tests/host/coexistence\.sh:' | grep -vF "grep -E '^[0-9a-f]+ cc_'")
  if [ -n "$oldNames" ]; then
    echo "$oldNames" | sed 's/^/    /'
    return 1
  fi

  return 0
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  host_tests_are_portable \
  host_tests_never_delete \
  host_tests_are_unattended \
  host_checks_declare_dependencies \
  host_tests_only_name_the_test_sandbox || exit 1
