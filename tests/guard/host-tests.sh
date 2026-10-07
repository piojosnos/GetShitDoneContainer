#!/usr/bin/env bash
# Guard rules on the host tests: portable, delete nothing, unattended, declared dependencies, only the test sandbox named.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/host-tests.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# require_readable_files FILE...: true if every argument is a readable regular file; prints each one that is not, and an empty list.
# --------------------------------------------------------------------------------
# A glob that matched nothing arrives as its literal pattern, so it is reported as unreadable.
require_readable_files() {
  local file
  local problem=0

  if [ "$#" -eq 0 ]; then
    echo "    no file to scan"
    return 1
  fi

  for file in "$@"; do
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
      echo "    cannot read: $file"
      problem=1
    fi
  done

  return "$problem"
}

# --------------------------------------------------------------------------------
# host_code_lines FILE...: every non-comment line of the files, as FILE:LINE:TEXT.
# --------------------------------------------------------------------------------
host_code_lines() {
  grep -Hn '^' "$@" | grep -Ev '^[^:]+:[0-9]+:[[:space:]]*#'
}

# --------------------------------------------------------------------------------
# no_host_code_matches REGEX EXEMPT FILE...: true if no code line matches REGEX.
# --------------------------------------------------------------------------------
# A line that also matches EXEMPT (when EXEMPT is not empty) is allowed. Prints the offenders. Fails when a file cannot be read.
no_host_code_matches() {
  local regex=$1
  local exempt=$2
  local hits

  shift 2

  require_readable_files "$@" || return 1

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
  no_host_code_matches 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|sed -i|\bgrep -P|readlink -f|date -d|\btimeout\b|sha256sum|echo -e|&>>|\|&|\bjq\b|\bpython3?\b|\bcoproc\b|wait -n|EPOCHSECONDS|local -n|sed -r|sort -V|xargs -r|\brealpath\b|date --date|mktemp --tmpdir' '' $HOST_FILES \
    && no_host_code_matches 'stat -c' 'in_container|docker exec' $HOST_FILES
}

# --------------------------------------------------------------------------------
# host_tests_have_blank_lines_before_control_flow: Every if, for, while, until and case in the host scripts has a blank line before it, unless it follows an opening line or a comment; here-document bodies are not code.
# --------------------------------------------------------------------------------
# A line counts as opening when it ends in {, then, do, else, ;;, ), in or a backslash. POSIX awk only, so the BSD awk on the Mac runs it.
# The single quote comes in with -v because the program sits in a single-quoted string.
host_tests_have_blank_lines_before_control_flow() {
  local hits
  local awkStatus

  require_readable_files $HOST_FILES || return 1

  hits=$(awk -v quote="'" '
    FNR == 1 {
      endMark = ""
      prev = ""
    }
    {
      line = $0
      if (endMark != "") {
        if (line == endMark) {
          endMark = ""
        }
        prev = line
        next
      }
      text = line
      sub(/^[ \t]+/, "", text)
      if (text ~ /^(if|for|while|until|case)[ (]/ && prev != "") {
        before = prev
        sub(/^[ \t]+/, "", before)
        if (before !~ /^#/ && before !~ /(\{|then|do|else|;;|\)|in)$/ && before !~ /\\$/) {
          printf "    %s:%d: %s\n", FILENAME, FNR, text
        }
      }
      if (match(line, "(^|[^<])<<-?[ ]*[" quote "\"]?[A-Za-z_]+[" quote "\"]?")) {
        mark = substr(line, RSTART, RLENGTH)
        gsub("^[^<]?<<-?[ ]*[" quote "\"]?", "", mark)
        gsub("[" quote "\"]", "", mark)
        endMark = mark
      }
      prev = line
    }
  ' $HOST_FILES)
  awkStatus=$?

  if [ "$awkStatus" -ne 0 ]; then
    echo "    awk could not read every file it was given"

    return 1
  fi

  if [ -z "$hits" ]; then
    return 0
  fi

  printf '%s\n' "$hits"

  return 1
}

# --------------------------------------------------------------------------------
# host_tests_never_delete: The host tests delete nothing: no rm, mv or truncate, no docker removal, kill, stop or prune, no git clean, no down with a volume flag or --rmi.
# --------------------------------------------------------------------------------
# Allowed: docker run --rm (a throwaway container) and the cleanup line that print_next_block prints.
# A truncating redirect stays allowed because a check empties its own log in the run folder that way.
host_tests_never_delete() {
  no_host_code_matches '(^|[^A-Za-z0-9_.-])(rm|rmdir|unlink|mv|truncate)([[:space:]]|$)|docker[[:space:]]+(container[[:space:]]+rm|rm|rmi|kill|stop|image[[:space:]]+(rm|prune)|system|volume[[:space:]]+(rm|prune))|git[[:space:]]+clean|--rmi|prune|down[[:space:]].*(-v|--volumes)|find .*-delete' \
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
  local file
  local fileId
  local checkCount=0
  local ok=0

  for file in tests/host/h[0-9][0-9]-*.sh tests/host/coexistence.sh; do
    if [ ! -e "$file" ]; then
      if [ "$file" = "tests/host/coexistence.sh" ]; then
        echo "    tests/host/coexistence.sh is missing"
        ok=1
      fi

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
        checkCount=$((checkCount + 1))
        fileId=$(basename "$file" | sed -E 's/^h([0-9]{2})-.*/H-\1/')
        if ! grep -Fq "$fileId" "$file"; then
          echo "    $file: does not mention its own ID $fileId"
          ok=1
        fi
        ;;
    esac
  done

  if [ "$checkCount" -eq 0 ]; then
    echo "    no host check found under tests/host/"
    ok=1
  fi

  return "$ok"
}

# --------------------------------------------------------------------------------
# host_tests_only_name_the_test_sandbox: Only the test sandbox is named: container sbx-hosttest, images sbx-base and sbx-claude.
# --------------------------------------------------------------------------------
# The old layout's cc_ names appear only where the old containers are compared (Coexistence, the snapshot).
host_tests_only_name_the_test_sandbox() {
  local otherNames oldNames

  require_readable_files $HOST_FILES || return 1

  nowhere_matches 'sbx-demo|SBX_NAME=demo' $HOST_FILES || return 1

  otherNames=$(grep -ohE 'sbx-[A-Za-z][A-Za-z0-9_]*' $HOST_FILES | sort -u | grep -Ev '^sbx-(hosttest|base|claude)$')
  if [ -n "$otherNames" ]; then
    echo "$otherNames" | sed 's/^/    /'
    return 1
  fi

  oldNames=$(grep -En '(^|[^A-Za-z0-9])cc_' $HOST_FILES | grep -v 'tests/host/coexistence\.sh:' | grep -vF "grep -E '^[0-9a-f]+ cc_'")
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
  host_tests_have_blank_lines_before_control_flow \
  host_tests_never_delete \
  host_tests_are_unattended \
  host_checks_declare_dependencies \
  host_tests_only_name_the_test_sandbox || exit 1
