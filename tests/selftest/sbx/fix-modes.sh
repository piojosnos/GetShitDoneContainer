#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-fix-modes against a git repo and a stand-in xattr
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/fix-modes.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# The stand-in keeps each attribute in a file, and like macOS it refuses to
# write one on a read-only file.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# make_xattr_standin: makes WORK/xattr-bin/xattr, storing values in WORK/xattrs
# ------------------------------------------------------------------------------
make_xattr_standin() {
  mkdir -p "$WORK/xattr-bin" "$WORK/xattrs"
  {
    printf '%s\n' '#!/bin/sh'
    printf '%s\n' "store=\"$WORK/xattrs\""
    printf '%s\n' 'case "$1" in'
    printf '%s\n' '  -p) file=$3 ;;'
    printf '%s\n' '  -w) file=$4 ;;'
    printf '%s\n' '  *) exit 2 ;;'
    printf '%s\n' 'esac'
    printf '%s\n' 'key=$(printf "%s" "$file" | cksum | cut -d " " -f 1)'
    printf '%s\n' 'if [ "$1" = -p ]; then'
    printf '%s\n' '  [ -f "$store/$key" ] || exit 1'
    printf '%s\n' '  cat "$store/$key"'
    printf '%s\n' '  exit 0'
    printf '%s\n' 'fi'
    printf '%s\n' 'if [ ! -w "$file" ]; then'
    printf '%s\n' '  echo "xattr: [Errno 13] Permission denied: $file" >&2'
    printf '%s\n' '  exit 1'
    printf '%s\n' 'fi'
    printf '%s\n' 'printf "%s\n" "$3" >"$store/$key"'
  } >"$WORK/xattr-bin/xattr"
  chmod 755 "$WORK/xattr-bin/xattr"
}

# ------------------------------------------------------------------------------
# attribute_of PATH: prints the stand-in attribute of PATH (nothing when unset)
# ------------------------------------------------------------------------------
attribute_of() {
  PATH=$WORK/xattr-bin:$PATH xattr -p user.containers.override_stat "$1" 2>/dev/null
}

# ------------------------------------------------------------------------------
# has_mode PATH TEXT: true when the mode ls prints for PATH starts with TEXT
# ------------------------------------------------------------------------------
has_mode() {
  local listLine

  listLine=$(ls -ld "$1") || return 1
  [ "${listLine:0:10}" = "$2" ]
}

# ------------------------------------------------------------------------------
# make_repo DIR: commits run.sh and ro.sh as 755, doc.md as 644, then drifts
# ------------------------------------------------------------------------------
# After the drift the Mac modes disagree with git on run.sh (600), doc.md (755)
# and ro.sh (read-only), and run.sh and ro.sh carry an attribute the sandbox
# would read as 644. plain.sh has no attribute and matches git.
# ------------------------------------------------------------------------------
make_repo() {
  local repoDir=$1

  git init -q "$repoDir" || return 1
  printf 'echo run\n' >"$repoDir/run.sh"
  printf 'echo ro\n' >"$repoDir/ro.sh"
  printf 'echo plain\n' >"$repoDir/plain.sh"
  printf 'doc\n' >"$repoDir/doc.md"
  chmod 755 "$repoDir/run.sh" "$repoDir/ro.sh" "$repoDir/plain.sh"
  chmod 644 "$repoDir/doc.md"
  git -C "$repoDir" add . || return 1
  git -C "$repoDir" -c user.name=test -c user.email=test@example.com commit -q -m init || return 1

  chmod 600 "$repoDir/run.sh"
  chmod 755 "$repoDir/doc.md"
  chmod 444 "$repoDir/ro.sh"
  PATH=$WORK/xattr-bin:$PATH xattr -w user.containers.override_stat 1001:1001:0100644 "$repoDir/run.sh"
  chmod u+w "$repoDir/ro.sh"
  PATH=$WORK/xattr-bin:$PATH xattr -w user.containers.override_stat 1001:1001:0100644 "$repoDir/ro.sh"
  chmod u-w "$repoDir/ro.sh"
}

# ------------------------------------------------------------------------------
# Case: bad input is refused before any file is touched
# ------------------------------------------------------------------------------
case_fix_modes_refusals() {
  SBX_CONFIG_DIR=$WORK/cfg-modes
  export SBX_CONFIG_DIR

  echo '--- sbx-fix-modes refusals'

  run_sbx modes1 sbx-fix-modes
  expect "sbx-fix-modes: no argument prints the usage and exits 2" usage_printed modes1 "Usage: sbx-fix-modes NAME"

  run_sbx modes2 sbx-fix-modes nosuch
  expect "sbx-fix-modes: an unregistered name is refused" refused_cleanly modes2 "is not registered; run: sbx-add" "" ""

  run_sbx modes3 sbx-fix-modes ../x
  expect "sbx-fix-modes: a path as a name is refused" refused_cleanly modes3 "breaks the sandbox name rule" "" ""

  run_sbx nogit sbx-add nogit "$WORK/modes dir/nogit"
  run_sbx modes4 sbx-fix-modes nogit
  expect "sbx-fix-modes: a project folder that is not a git repo is refused" refused_cleanly modes4 "is not the top folder of a git repository" "" ""
}

# ------------------------------------------------------------------------------
# Case: the Mac modes and the attributes follow git; a second run changes nothing
# ------------------------------------------------------------------------------
case_fix_modes_sets_both_sides() {
  local repoDir="$WORK/modes dir/fixed/fixed"

  SBX_CONFIG_DIR=$WORK/cfg-modes
  export SBX_CONFIG_DIR

  echo '--- sbx-fix-modes on a drifted repo'

  make_xattr_standin
  run_sbx fixed sbx-add fixed "$WORK/modes dir/fixed"
  make_repo "$repoDir"

  PATH=$WORK/xattr-bin:$PATH run_sbx modes5 sbx-fix-modes fixed
  expect "sbx-fix-modes: it exits 0" equals "$SBX_RC" 0
  expect "sbx-fix-modes: a file committed as 755 is 755 on the Mac" has_mode "$repoDir/run.sh" -rwxr-xr-x
  expect "sbx-fix-modes: a file committed as 644 is 644 on the Mac" has_mode "$repoDir/doc.md" -rw-r--r--
  expect "sbx-fix-modes: a read-only file gets the git mode on the Mac" has_mode "$repoDir/ro.sh" -rwxr-xr-x
  expect "sbx-fix-modes: a file that matches git keeps its mode" has_mode "$repoDir/plain.sh" -rwxr-xr-x
  expect "sbx-fix-modes: the attribute takes the git mode and keeps the owner" equals "$(attribute_of "$repoDir/run.sh")" 1001:1001:0100755
  expect "sbx-fix-modes: a read-only file gets the git mode in its attribute" equals "$(attribute_of "$repoDir/ro.sh")" 1001:1001:0100755
  expect "sbx-fix-modes: a file without an attribute does not get one" equals "$(attribute_of "$repoDir/plain.sh")" ""
  expect "sbx-fix-modes: the counts are printed" has_text "$WORK/modes5.out" "set 3 Mac modes and 2 sandbox modes from git"

  PATH=$WORK/xattr-bin:$PATH run_sbx modes6 sbx-fix-modes fixed
  expect "sbx-fix-modes: a second run changes nothing" has_text "$WORK/modes6.out" "set 0 Mac modes and 0 sandbox modes from git"
}

# ------------------------------------------------------------------------------
# Case: without xattr the Mac modes are still set, and the skip is said
# ------------------------------------------------------------------------------
case_fix_modes_without_xattr() {
  local repoDir="$WORK/modes dir/bare/bare"

  SBX_CONFIG_DIR=$WORK/cfg-modes
  export SBX_CONFIG_DIR

  echo '--- sbx-fix-modes without xattr'

  if command -v xattr >/dev/null 2>&1; then
    echo 'SKIP: xattr is installed here, so its absence cannot be tested'
    return 0
  fi

  run_sbx bare sbx-add bare "$WORK/modes dir/bare"
  make_repo "$repoDir"

  run_sbx modes7 sbx-fix-modes bare
  expect "sbx-fix-modes: without xattr it exits 0" equals "$SBX_RC" 0
  expect "sbx-fix-modes: without xattr the Mac modes still follow git" has_mode "$repoDir/run.sh" -rwxr-xr-x
  expect "sbx-fix-modes: without xattr the skip is said" has_text "$WORK/modes7.out" "xattr is not installed"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_fix_modes_refusals
case_fix_modes_sets_both_sides
case_fix_modes_without_xattr
finish_cases
