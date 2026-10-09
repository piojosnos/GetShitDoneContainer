#!/usr/bin/env bash
# H-22: the base image holds the toolchain at the pinned versions, as native binaries, and a login shell in the sandbox finds it.
# - One probe (support/toolchain-probe.sh) runs in a throwaway sbx-base:local container, which proves the tools
#   come from the base image, and in a login shell of the test sandbox.
# - Node, gh, uv, the JDK and Maven must report the versions in versions.env, Python must be 3, and every binary must match the daemon's architecture.
# - The common Linux tools must be present and JAVA_HOME must be /opt/java/openjdk.
# Depends on: nothing
# Needs: images built; test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# expected_elf_machine: the ELF machine bytes the daemon's architecture needs (b700 for arm64, 3e00 for amd64); prints nothing for any other.
# --------------------------------------------------------------------------------
expected_elf_machine() {
  case "$(expected_arch)" in
    arm64) printf 'b700\n' ;;
    amd64) printf '3e00\n' ;;
  esac
}

# --------------------------------------------------------------------------------
# image_tag_version NAME: the tag of the _IMAGE pin NAME, the text between the first colon and the @.
# --------------------------------------------------------------------------------
image_tag_version() {
  pin_of "$1" | sed -e 's/^[^:]*://' -e 's/@.*$//'
}

# --------------------------------------------------------------------------------
# run_probes: runs the probe in a throwaway sbx-base:local container and in a login shell of the test sandbox.
# --------------------------------------------------------------------------------
run_probes() {
  local probeText

  probeText=$(cat "$HOST_DIR/support/toolchain-probe.sh")
  baseOutput=$(run_timeout 120 docker run --rm --entrypoint bash sbx-base:local -c "$probeText" </dev/null 2>&1)
  shellOutput=$(run_timeout 120 in_project bash -lc "$probeText")
}

# --------------------------------------------------------------------------------
# value_of OUTPUT KEY: the text after KEY on the first probe line that starts with KEY and a space; empty when there is none.
# --------------------------------------------------------------------------------
value_of() {
  local valueLine

  valueLine=$(printf '%s\n' "$1" | grep "^$2 " | head -n 1)
  printf '%s\n' "${valueLine#"$2" }"
}

# --------------------------------------------------------------------------------
# version_matches ACTUAL EXPECTED: true when ACTUAL is EXPECTED, or starts with EXPECTED and a space.
# --------------------------------------------------------------------------------
version_matches() {
  case "$1 " in
    "$2 "*) return 0 ;;
  esac

  return 1
}

# --------------------------------------------------------------------------------
# check_elf LABEL NAME ELF: a problem unless the binary of NAME is built for the daemon's architecture.
# --------------------------------------------------------------------------------
check_elf() {
  if [ -n "$expectedElf" ] && [ "$3" != "$expectedElf" ]; then
    add_problem "$1: $2 is $3; expected $expectedElf"
  fi
}

# --------------------------------------------------------------------------------
# check_missing LABEL OUTPUT: a problem for each tool the probe reported as missing.
# --------------------------------------------------------------------------------
check_missing() {
  local missingLine

  while IFS= read -r missingLine; do
    if [ -n "$missingLine" ]; then
      add_problem "$1: ${missingLine#MISSING } is missing"
    fi
  done <<EOF
$(printf '%s\n' "$2" | grep '^MISSING ')
EOF
}

# --------------------------------------------------------------------------------
# check_tool_line LABEL OUTPUT NAME EXPECTED_TEXT PIN_TEXT: NAME must be a native binary; when EXPECTED_TEXT is not empty its version text must be that.
# --------------------------------------------------------------------------------
# A tool the probe reported as missing has no TOOL line; check_missing names it, so it is not reported twice here.
check_tool_line() {
  local label=$1
  local toolName=$3
  local toolValue elfBytes versionText

  toolValue=$(value_of "$2" "TOOL $toolName")

  if [ -z "$toolValue" ]; then
    return 0
  fi

  elfBytes=${toolValue%% *}
  versionText=${toolValue#* }
  check_elf "$label" "$toolName" "$elfBytes"

  if [ -n "$4" ] && ! version_matches "$versionText" "$4"; then
    add_problem "$label: $toolName reports $versionText; the pin is $5"
  fi
}

# --------------------------------------------------------------------------------
# check_python LABEL OUTPUT: a Python 3, found by its version text, built for the daemon's architecture.
# --------------------------------------------------------------------------------
check_python() {
  local pythonLine rest

  pythonLine=$(printf '%s\n' "$2" | grep -E '^TOOL [a-z0-9]+ [0-9a-f]+ Python 3\.' | head -n 1)

  if [ -z "$pythonLine" ]; then
    add_problem "$1: no Python 3"

    return 0
  fi

  rest=${pythonLine#TOOL * }
  check_elf "$1" "Python 3" "${rest%% *}"
}

# --------------------------------------------------------------------------------
# check_java LABEL OUTPUT: the JDK is Temurin at the pinned version.
# --------------------------------------------------------------------------------
check_java() {
  local javaVersion javaValue vendorLine

  javaVersion=$(image_tag_version TEMURIN_IMAGE)
  javaVersion=${javaVersion%%_*}
  javaValue=$(value_of "$2" "TOOL java")

  if [ -z "$javaValue" ]; then
    return 0
  fi

  vendorLine=$(value_of "$2" JAVA_VENDOR)

  case "$vendorLine" in
    *Temurin*) ;;
    *) add_problem "$1: the JDK is not Temurin; got: $vendorLine" ;;
  esac

  case "$javaValue" in
    *"\"$javaVersion\""*) ;;
    *) add_problem "$1: java reports ${javaValue#* }; the pin is \"$javaVersion\"" ;;
  esac
}

# --------------------------------------------------------------------------------
# check_maven LABEL OUTPUT: Maven is at its pin and runs on the pinned JDK.
# --------------------------------------------------------------------------------
check_maven() {
  local javaVersion mavenLine mavenJavaLine

  mavenLine=$(value_of "$2" MAVEN)

  if [ -z "$mavenLine" ]; then
    return 0
  fi

  if ! version_matches "$mavenLine" "Apache Maven $(pin_of MAVEN_VERSION)"; then
    add_problem "$1: mvn reports $mavenLine; the pin is Apache Maven $(pin_of MAVEN_VERSION)"
  fi

  javaVersion=$(image_tag_version TEMURIN_IMAGE)
  javaVersion=${javaVersion%%_*}
  mavenJavaLine=$(value_of "$2" MAVEN_JAVA)

  case "$mavenJavaLine" in
    *"Java version: $javaVersion,"*) ;;
    *) add_problem "$1: Maven runs on '$mavenJavaLine'; expected Java version: $javaVersion" ;;
  esac
}

# --------------------------------------------------------------------------------
# check_probe LABEL OUTPUT: every problem the probe output of one place shows; LABEL says which place.
# --------------------------------------------------------------------------------
check_probe() {
  local label=$1
  local output=$2
  local javaHome

  if ! printf '%s\n' "$output" | grep -Fxq 'PROBE-END'; then
    add_problem "$label: the probe did not finish; got: $(first_lines "$output")"

    return 0
  fi

  check_missing "$label" "$output"
  check_tool_line "$label" "$output" git "" ""
  check_tool_line "$label" "$output" gh "gh version $(pin_of GH_VERSION)" "$(pin_of GH_VERSION)"
  check_tool_line "$label" "$output" node "v$(pin_of NODE_VERSION)" "v$(pin_of NODE_VERSION)"
  check_tool_line "$label" "$output" uv "uv $(image_tag_version UV_IMAGE)" "$(image_tag_version UV_IMAGE)"
  check_tool_line "$label" "$output" java "" ""
  check_python "$label" "$output"
  check_java "$label" "$output"
  check_maven "$label" "$output"

  javaHome=$(value_of "$output" JAVA_HOME)

  if [ "$javaHome" != "/opt/java/openjdk" ]; then
    add_problem "$label: JAVA_HOME is $javaHome; expected /opt/java/openjdk"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-22 || exit 1
expectedElf=$(expected_elf_machine)

if [ -z "$expectedElf" ]; then
  add_problem "the daemon architecture is unknown"
fi

run_probes
check_probe "sbx-base:local" "$baseOutput"
check_probe "login shell in the sandbox" "$shellOutput"
javaTag=$(image_tag_version TEMURIN_IMAGE)
report_check H-22 "the toolchain in the base image is missing, not native or not at its pin" \
  "Node $(pin_of NODE_VERSION), uv $(image_tag_version UV_IMAGE), Temurin ${javaTag%%_*} and Maven $(pin_of MAVEN_VERSION) are native and at their pins, in the image and in a login shell"
