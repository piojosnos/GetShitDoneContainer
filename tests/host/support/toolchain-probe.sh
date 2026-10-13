#!/usr/bin/env bash
# Toolchain probe: prints one line per tool for host check H-22.
# - Runs inside an sbx container (Ubuntu, bash 5, GNU tools), never on the Mac.
# - H-22 reads this file and passes its text to bash -c in a throwaway sbx-base:local container
#   and to bash -lc in the test sandbox, so the first command below is the marker the fake docker looks for.
# - Output lines:
#   TOOL NAME ELF VERSION_LINE   for git, gh, node, python3, uv and java; ELF is the two e_machine bytes in hex
#                                (b700 for AArch64, 3e00 for x86-64)
#   JAVA_VENDOR LINE             the second line of java -version
#   MAVEN LINE                   the first line of mvn -v
#   MAVEN_JAVA LINE              the "Java version:" line of mvn -v
#   JAVA_HOME VALUE              the variable, or unset
#   CMD NAME                     jq, rg, unzip, zip, ssh, make, gcc and tzdata when present
#   MISSING NAME                 in place of any other line for a tool that is not found
#   the end marker               always the last line, written at the bottom of this file
: toolchain-probe

# --------------------------------------------------------------------------------
# version_line NAME: prints the first line of the version output of tool NAME.
# --------------------------------------------------------------------------------
version_line() {
  case "$1" in
    git) git --version | head -n 1 ;;
    gh) gh --version | head -n 1 ;;
    node) node -v | head -n 1 ;;
    python3) python3 --version | head -n 1 ;;
    uv) uv --version | head -n 1 ;;
    java) java -version 2>&1 | head -n 1 ;;
  esac
}

# --------------------------------------------------------------------------------
# elf_machine PATH: prints the two e_machine bytes of the ELF file at PATH as hex, without spaces.
# --------------------------------------------------------------------------------
elf_machine() {
  od -An -tx1 -j18 -N2 "$1" | tr -d ' \n'
}

# --------------------------------------------------------------------------------
# probe_tool NAME: prints the TOOL line of NAME, or MISSING NAME.
# --------------------------------------------------------------------------------
probe_tool() {
  local toolPath

  toolPath=$(command -v "$1")

  if [ -z "$toolPath" ]; then
    echo "MISSING $1"

    return 0
  fi

  echo "TOOL $1 $(elf_machine "$(readlink -f "$toolPath")") $(version_line "$1")"
}

# --------------------------------------------------------------------------------
# probe_java_vendor: prints the JAVA_VENDOR line, from the second line of java -version.
# --------------------------------------------------------------------------------
probe_java_vendor() {
  if command -v java >/dev/null; then
    echo "JAVA_VENDOR $(java -version 2>&1 | sed -n 2p)"
  fi
}

# --------------------------------------------------------------------------------
# probe_maven: prints the MAVEN and MAVEN_JAVA lines, or MISSING mvn.
# --------------------------------------------------------------------------------
probe_maven() {
  local mavenOutput

  if ! command -v mvn >/dev/null; then
    echo "MISSING mvn"

    return 0
  fi

  mavenOutput=$(mvn -v 2>&1)
  echo "MAVEN $(echo "$mavenOutput" | head -n 1)"
  echo "MAVEN_JAVA $(echo "$mavenOutput" | grep '^Java version:' | head -n 1)"
}

# --------------------------------------------------------------------------------
# probe_java_home: prints the JAVA_HOME line.
# --------------------------------------------------------------------------------
probe_java_home() {
  echo "JAVA_HOME ${JAVA_HOME:-unset}"
}

# --------------------------------------------------------------------------------
# probe_commands: prints CMD NAME or MISSING NAME for the common Linux tools and the time zone data.
# --------------------------------------------------------------------------------
probe_commands() {
  local commandName

  for commandName in jq rg unzip zip ssh make gcc; do
    if command -v "$commandName" >/dev/null; then
      echo "CMD $commandName"
    else
      echo "MISSING $commandName"
    fi
  done

  if [ -e /usr/share/zoneinfo/UTC ]; then
    echo "CMD tzdata"
  else
    echo "MISSING tzdata"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
for toolName in git gh node python3 uv java; do
  probe_tool "$toolName"
done

probe_java_vendor
probe_maven
probe_java_home
probe_commands
echo "PROBE-END"
