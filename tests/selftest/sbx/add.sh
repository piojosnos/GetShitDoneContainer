#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-add: the entry, the folders, every refusal, the overlaps
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/add.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# entry_equals NAME PATH: true when the entry NAME is exactly the two lines
# ------------------------------------------------------------------------------
entry_equals() {
  printf 'SBX_DIR=%s\nSBX_AGENT=claude\n' "$2" | cmp -s - "$SBX_CONFIG_DIR/sandboxes/$1"
}

# ------------------------------------------------------------------------------
# folders_made PATH NAME: true when PATH/NAME and PATH/state are folders
# ------------------------------------------------------------------------------
folders_made() {
  [ -d "$1/$2" ] && [ -d "$1/state" ]
}

# ------------------------------------------------------------------------------
# entry_kept LABEL TEXT BEFORE_FILE NAME: refused, entry NAME as in BEFORE_FILE
# ------------------------------------------------------------------------------
entry_kept() {
  [ "$SBX_RC" -eq 1 ] && has_text "$WORK/$1.err" "$2" && cmp -s "$3" "$SBX_CONFIG_DIR/sandboxes/$4"
}

# ------------------------------------------------------------------------------
# home_entry_made RC: true when the default registry under HOME got the entry
# ------------------------------------------------------------------------------
home_entry_made() {
  [ "$1" -eq 0 ] && [ -f "$WORK/home/.config/sbx/sandboxes/homedemo" ]
}

# ------------------------------------------------------------------------------
# Case: a sandbox is registered and its folders are made
# ------------------------------------------------------------------------------
case_registers() {
  echo '--- sbx-add registers a sandbox'

  run_sbx demo sbx-add demo "$WORK/sbx one"
  expect "sbx-add: registers a sandbox whose path has a space" equals "$SBX_RC" 0
  expect "sbx-add: the entry is the two lines SBX_DIR and SBX_AGENT=claude" entry_equals demo "$WORK/sbx one"
  expect "sbx-add: the host folder, its project folder and state/ are made" folders_made "$WORK/sbx one" demo

  run_sbx two sbx-add two "$WORK/sbx two/"
  expect "sbx-add: a trailing slash is not stored" entry_equals two "$WORK/sbx two"

  mkdir -p "$WORK/sbx three/state"
  echo keep >"$WORK/sbx three/state/keep.txt"
  run_sbx three sbx-add three "$WORK/sbx three"
  expect "sbx-add: an existing folder and its files are kept" equals "$SBX_RC$(cat "$WORK/sbx three/state/keep.txt")" 0keep
}

# ------------------------------------------------------------------------------
# Case: the registry folder default and a relative registry folder
# ------------------------------------------------------------------------------
case_defaults() {
  local homeRc

  echo '--- the registry folder'

  ( unset SBX_CONFIG_DIR; HOME=$WORK/home; export HOME; bash "$BIN/sbx-add" homedemo "$WORK/home sbx" ) >"$WORK/home.out" 2>"$WORK/home.err" </dev/null
  homeRc=$?
  expect "sbx-add: with SBX_CONFIG_DIR unset the entry goes under HOME/.config/sbx" home_entry_made "$homeRc"

  SBX_CONFIG_DIR=cfg run_sbx relcfg sbx-add relcfg "$WORK/relcfg"
  expect "sbx-add: a relative SBX_CONFIG_DIR is refused" refused_cleanly relcfg SBX_CONFIG_DIR "" "$WORK/relcfg"
}

# ------------------------------------------------------------------------------
# Case: the wrong number of arguments prints the usage and exits 2
# ------------------------------------------------------------------------------
case_usage() {
  local usageText='Usage: sbx-add NAME HOST_PATH'

  echo '--- the wrong number of arguments'

  run_sbx u0 sbx-add
  expect "sbx-add: no argument prints the usage and exits 2" usage_printed u0 "$usageText"

  run_sbx u1 sbx-add demo
  expect "sbx-add: one argument prints the usage and exits 2" usage_printed u1 "$usageText"

  run_sbx u3 sbx-add demo "$WORK/u3" extra
  expect "sbx-add: three arguments print the usage and exit 2" usage_printed u3 "$usageText"
}

# ------------------------------------------------------------------------------
# Case: a name that breaks the rule or is reserved is refused, nothing is made
# ------------------------------------------------------------------------------
case_bad_names() {
  local ruleText='breaks the sandbox name rule'

  echo '--- bad names'

  run_sbx n1 sbx-add MyProject "$WORK/names/upper"
  expect "sbx-add: an uppercase name is refused" refused_cleanly n1 "$ruleText" MyProject "$WORK/names/upper"

  run_sbx n2 sbx-add my_project "$WORK/names/underscore"
  expect "sbx-add: an underscore is refused" refused_cleanly n2 "$ruleText" my_project "$WORK/names/underscore"

  run_sbx n3 sbx-add ../x "$WORK/names/dots"
  expect "sbx-add: a path as a name is refused" refused_cleanly n3 "$ruleText" "" "$WORK/names/dots"

  run_sbx n4 sbx-add "" "$WORK/names/empty"
  expect "sbx-add: an empty name is refused" refused_cleanly n4 "$ruleText" "" "$WORK/names/empty"

  run_sbx n5 sbx-add abcdefghijklmnopqrstuvwxyzabcdef "$WORK/names/long"
  expect "sbx-add: a name of 32 characters is refused" refused_cleanly n5 "$ruleText" abcdefghijklmnopqrstuvwxyzabcdef "$WORK/names/long"

  run_sbx n6 sbx-add $'ok\nbad' "$WORK/names/lines"
  expect "sbx-add: a name with a line break is refused" refused_cleanly n6 "$ruleText" "" "$WORK/names/lines"

  run_sbx n7 sbx-add $'caf\xc3\xa9' "$WORK/names/accent"
  expect "sbx-add: a non-ASCII name is refused" refused_cleanly n7 "$ruleText" "" "$WORK/names/accent"

  run_sbx n8 sbx-add state "$WORK/names/state"
  expect "sbx-add: the state name is refused" refused_cleanly n8 "is taken" state "$WORK/names/state"

  run_sbx n9 sbx-add best-practices "$WORK/names/best"
  expect "sbx-add: the best-practices name is refused" refused_cleanly n9 "is taken" best-practices "$WORK/names/best"
}

# ------------------------------------------------------------------------------
# Case: a host path that is unsafe is refused, nothing is made
# ------------------------------------------------------------------------------
case_bad_paths() {
  local partText='has an empty, . or .. part'
  local registryText='overlaps the registry folder'

  echo '--- bad host paths'

  run_sbx p1 sbx-add relpath rel/dir
  expect "sbx-add: a relative path is refused" refused_cleanly p1 "is not an absolute path" relpath rel/dir

  run_sbx p2 sbx-add emptypath ""
  expect "sbx-add: an empty path is refused" refused_cleanly p2 "the host path is empty" emptypath ""

  run_sbx p3 sbx-add linepath "$WORK/p"$'\n'"q"
  expect "sbx-add: a path with a line break is refused" refused_cleanly p3 "the host path has a line break" linepath "$WORK/p"

  run_sbx p4 sbx-add dotdot "$WORK/p/../q"
  expect "sbx-add: a path with a .. part is refused" refused_cleanly p4 "$partText" dotdot "$WORK/p"

  run_sbx p5 sbx-add onedot "$WORK/p/./q"
  expect "sbx-add: a path with a . part is refused" refused_cleanly p5 "$partText" onedot "$WORK/p"

  run_sbx p6 sbx-add emptypart "$WORK/p//q"
  expect "sbx-add: a path with an empty part is refused" refused_cleanly p6 "$partText" emptypart "$WORK/p"

  run_sbx p7 sbx-add rootpath /
  expect "sbx-add: the root folder is refused" refused_cleanly p7 "$registryText" rootpath /

  run_sbx p8 sbx-add holdsreg "$WORK"
  expect "sbx-add: a path that holds the registry folder is refused" refused_cleanly p8 "$registryText" holdsreg ""

  run_sbx p9 sbx-add insidereg "$WORK/cfg/inside"
  expect "sbx-add: a path inside the registry folder is refused" refused_cleanly p9 "$registryText" insidereg "$WORK/cfg/inside"
}

# ------------------------------------------------------------------------------
# folders_absent PATH: true when PATH/state was not made
# ------------------------------------------------------------------------------
folders_absent() {
  [ ! -e "$1/state" ]
}

# ------------------------------------------------------------------------------
# Case: a folder that is, holds or sits inside the repo folder is refused
# ------------------------------------------------------------------------------
# The script runs from a copy of bin/ and the start library in WORK/box/repo, so
# a failing case makes folders in the copy and never in the real repo.
# ------------------------------------------------------------------------------
case_repo_overlap() {
  local realBin=$BIN
  local repoText='overlaps the repo folder'
  local fakeRepo=$WORK/box/repo

  echo '--- the repo folder'

  mkdir -p "$fakeRepo/bin" "$fakeRepo/base"
  cp "$realBin"/sbx-* "$fakeRepo/bin/"
  cp "$REPO/base/sbx-start-lib.sh" "$fakeRepo/base/"
  BIN=$fakeRepo/bin

  run_sbx repois sbx-add repois "$fakeRepo"
  expect "sbx-add: the repo folder itself is refused" refused_cleanly repois "$repoText" repois ""
  expect "sbx-add: the repo folder got no state folder" folders_absent "$fakeRepo"

  run_sbx repoholds sbx-add repoholds "$WORK/box"
  expect "sbx-add: a folder that holds the repo folder is refused" refused_cleanly repoholds "$repoText" repoholds ""
  expect "sbx-add: the folder that holds the repo got no state folder" folders_absent "$WORK/box"

  run_sbx repoinside sbx-add repoinside "$fakeRepo/inside"
  expect "sbx-add: a folder inside the repo folder is refused" refused_cleanly repoinside "$repoText" repoinside "$fakeRepo/inside"

  ln -s "$fakeRepo" "$WORK/box/repolink"
  run_sbx repolink sbx-add repolink "$WORK/box/repolink"
  expect "sbx-add: a symlink to the repo folder is refused" refused_cleanly repolink "$repoText" repolink ""
  expect "sbx-add: the folder behind the symlink got no state folder" folders_absent "$fakeRepo"

  run_sbx repolinkin sbx-add repolinkin "$WORK/box/repolink/inside"
  expect "sbx-add: a folder inside a symlink to the repo folder is refused" refused_cleanly repolinkin "$repoText" repolinkin "$fakeRepo/inside"

  run_sbx repoprefix sbx-add repoprefix "$WORK/box/repo-other"
  expect "sbx-add: a folder that only shares a text prefix with the repo folder is accepted" equals "$SBX_RC" 0

  BIN=$realBin
}

# ------------------------------------------------------------------------------
# Case: names and folders already taken by another sandbox (after the register)
# ------------------------------------------------------------------------------
case_overlaps() {
  echo '--- overlaps with registered sandboxes'

  cp "$SBX_CONFIG_DIR/sandboxes/demo" "$WORK/demo.before"
  run_sbx again sbx-add demo "$WORK/other"
  expect "sbx-add: a name already registered is refused and its entry is unchanged" entry_kept again "is already registered" "$WORK/demo.before" demo

  run_sbx same sbx-add samefolder "$WORK/sbx one"
  expect "sbx-add: the folder of another sandbox is refused" refused_cleanly same "overlaps the folder of sandbox demo" samefolder ""

  run_sbx inner sbx-add innerfolder "$WORK/sbx one/inner"
  expect "sbx-add: a path inside another sandbox folder is refused" refused_cleanly inner "overlaps the folder of sandbox demo" innerfolder "$WORK/sbx one/inner"

  run_sbx deep sbx-add deep "$WORK/a/b/c"
  run_sbx holder sbx-add holder "$WORK/a"
  expect "sbx-add: a path that holds another sandbox folder is refused" refused_cleanly holder "overlaps the folder of sandbox deep" holder ""

  run_sbx near sbx-add near "$WORK/sbx one-other"
  expect "sbx-add: a path that only shares a text prefix is accepted" equals "$SBX_RC" 0
}

# ------------------------------------------------------------------------------
# Case: folders are compared as folders, so a symlink or a letter case cannot hide one
# ------------------------------------------------------------------------------
# Runs after case_overlaps, which registered demo (WORK/sbx one) and deep
# (WORK/a/b/c). /tmp against /private/tmp on the Mac is the same case as a symlink.
# ------------------------------------------------------------------------------
case_same_folder() {
  local sandboxText='overlaps the folder of sandbox'
  local registryText='overlaps the registry folder'

  echo '--- one folder under another name'

  ln -s "$WORK/sbx one" "$WORK/link to one"
  run_sbx linkone sbx-add linkone "$WORK/link to one"
  expect "sbx-add: a symlink to another sandbox folder is refused" refused_cleanly linkone "$sandboxText demo" linkone ""

  run_sbx linkoneinner sbx-add linkoneinner "$WORK/link to one/inner"
  expect "sbx-add: a folder inside a symlink to another sandbox folder is refused" refused_cleanly linkoneinner "$sandboxText demo" linkoneinner "$WORK/sbx one/inner"

  ln -s "$WORK/a" "$WORK/link to a"
  run_sbx linkholder sbx-add linkholder "$WORK/link to a/b"
  expect "sbx-add: a folder that holds another sandbox folder through a symlink is refused" refused_cleanly linkholder "$sandboxText deep" linkholder ""

  ln -s "$WORK/cfg" "$WORK/link to cfg"
  run_sbx linkreg sbx-add linkreg "$WORK/link to cfg/inside"
  expect "sbx-add: a folder inside a symlink to the registry folder is refused" refused_cleanly linkreg "$registryText" linkreg "$WORK/cfg/inside"

  SBX_CONFIG_DIR="$WORK/link to cfg" run_sbx regthroughlink sbx-add regthroughlink "$WORK/cfg"
  expect "sbx-add: the registry folder given as a symlink is still protected" refused_cleanly regthroughlink "$registryText" regthroughlink ""

  SBX_CONFIG_DIR=$WORK/cfg-notyet run_sbx notyet sbx-add notyet "$WORK/CFG-NOTYET/inside"
  expect "sbx-add: a registry folder not made yet is compared without letter case" refused_cleanly notyet "$registryText" notyet "$WORK/CFG-NOTYET/inside"

  if [ "$WORK/SBX ONE" -ef "$WORK/sbx one" ]; then
    run_sbx upper sbx-add upper "$WORK/SBX ONE"
    expect "sbx-add: the same folder in another letter case is refused" refused_cleanly upper "$sandboxText demo" upper ""
  else
    echo "INFO: this disk tells letter cases apart; the same-folder-in-another-case check runs on the Mac only"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
echo "INFO: bash $BASH_VERSION"
case_usage
case_bad_names
case_bad_paths
case_registers
case_defaults
case_repo_overlap
case_overlaps
case_same_folder
expect "sbx-add: no case reached docker" no_docker_call
finish_cases
