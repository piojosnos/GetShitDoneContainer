#!/usr/bin/env bash
# Self-test of H-23 (tests/host/h23-caches-survive-recreate.sh) against the fake docker: caches in the state folder that survive the recreate pass, with a real Maven download; folders the entrypoint did not make, an npm cache outside state, a ~/.m2 that is not the state link, a cache that never reaches the Mac, a cache lost on recreate, a failing Maven download and a downloaded jar that never reaches the Mac each fail and are named.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h23-caches-survive-recreate.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# make_cache_fixture: makes a fixture run folder with the cache folders a started sandbox has.
# --------------------------------------------------------------------------------
make_cache_fixture() {
  reset_state
  make_fixture_run
  fake_start_sync "$FIXTURE"
  mkdir -p "$FIXTURE/state/cache/npm" "$FIXTURE/state/cache/uv" "$FIXTURE/state/m2"
}

# --------------------------------------------------------------------------------
# marker_file_in FOLDER: true when FOLDER holds a file named h23-...
# --------------------------------------------------------------------------------
marker_file_in() {
  ls "$1"/h23-* >/dev/null 2>&1
}

# --------------------------------------------------------------------------------
# marker_files_in_all_caches: true when each of the three cache folders of FIXTURE holds a marker file.
# --------------------------------------------------------------------------------
marker_files_in_all_caches() {
  marker_file_in "$FIXTURE/state/cache/npm" && marker_file_in "$FIXTURE/state/cache/uv" && marker_file_in "$FIXTURE/state/m2"
}

# --------------------------------------------------------------------------------
# jar_in_unique_repository: true when state/m2 of FIXTURE holds the junit jar under a repository-h23-... folder.
# --------------------------------------------------------------------------------
jar_in_unique_repository() {
  ls "$FIXTURE"/state/m2/repository-h23-*/junit/junit/4.13.2/junit-4.13.2.jar >/dev/null 2>&1
}

# --------------------------------------------------------------------------------
# Cases of H-23, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h23_alone() {
  echo "--- H-23 on its own"
  make_cache_fixture
  run_standalone "$WORK/out.h23" h23-caches-survive-recreate.sh
  expect "H-23: caches in the state folder that survive the recreate pass" equals "$CHECK_RC" "0"
  expect "H-23: prints PASS: H-23" has_text "$WORK/out.h23" "PASS: H-23"
  expect "H-23: the sandbox is down and up once" equals "$(grep -c 'ARGS: compose .* \(up\|down\)' "$FAKE_LOG")" "2"
  expect "H-23: the marker files are on the host afterwards" marker_files_in_all_caches
  expect "H-23: the PASS line mentions the Maven download" has_text "$WORK/out.h23" "Maven download"
  expect "H-23: Maven is asked for junit 4.13.2 in the project folder, with a pinned plugin and a run-unique local repository" \
    has_match "$FAKE_LOG" "exec -w /home/sandbox/workspace/hosttest sbx-hosttest mvn -q org.apache.maven.plugins:maven-dependency-plugin:[0-9.]+:get -Dartifact=junit:junit:4.13.2 -Dmaven.repo.local=/home/sandbox/.m2/repository-h23-[0-9]+-[0-9]+\$"
  expect "H-23: the downloaded jar is in the run-unique repository on the host afterwards" jar_in_unique_repository
  expect "H-23: the sandbox is up at the end" test -f "$WORK/state/container"

  reset_state
  make_fixture_run
  fake_start_sync "$FIXTURE"
  run_standalone "$WORK/out.h23.nodirs" h23-caches-survive-recreate.sh FAKE_NO_CACHE_DIRS=1
  expect "H-23: folders the entrypoint did not make fail" equals "$CHECK_RC" "1"
  expect "H-23: the missing folder message says the entrypoint did not make it" has_text "$WORK/out.h23.nodirs" "the entrypoint did not make it"
  expect "H-23: the missing folder is named" has_text "$WORK/out.h23.nodirs" "state/cache/npm"

  make_cache_fixture
  run_standalone "$WORK/out.h23.npm" h23-caches-survive-recreate.sh FAKE_NPM_CACHE=/home/sandbox/.npm
  expect "H-23: an npm cache outside state fails" equals "$CHECK_RC" "1"
  expect "H-23: the npm problem names npm and what it printed" has_text "$WORK/out.h23.npm" "/home/sandbox/.npm"

  make_cache_fixture
  run_standalone "$WORK/out.h23.m2" h23-caches-survive-recreate.sh FAKE_M2_LINK=/home/sandbox/m2-local
  expect "H-23: a ~/.m2 that is not the state link fails" equals "$CHECK_RC" "1"
  expect "H-23: the ~/.m2 problem names ~/.m2" has_text "$WORK/out.h23.m2" "~/.m2"

  make_cache_fixture
  run_standalone "$WORK/out.h23.noshare" h23-caches-survive-recreate.sh FAKE_CACHE_NOT_SHARED=1
  expect "H-23: a cache that never reaches the Mac fails" equals "$CHECK_RC" "1"
  expect "H-23: the unshared cache says it was missing before the recreate" has_text "$WORK/out.h23.noshare" "before the recreate"

  make_cache_fixture
  run_standalone "$WORK/out.h23.lost" h23-caches-survive-recreate.sh FAKE_DOWN_LOSES_CACHES=1
  expect "H-23: a cache lost on recreate fails" equals "$CHECK_RC" "1"
  expect "H-23: the lost cache says it was missing after the recreate" has_text "$WORK/out.h23.lost" "after the recreate"
  expect "H-23: a cache lost on recreate was still there before it" lacks_text "$WORK/out.h23.lost" "before the recreate"

  make_cache_fixture
  run_standalone "$WORK/out.h23.mvn" h23-caches-survive-recreate.sh FAKE_MVN_IO_ERROR=1
  expect "H-23: a failing Maven download fails" equals "$CHECK_RC" "1"
  expect "H-23: the Maven problem names the exit status" has_text "$WORK/out.h23.mvn" "exited with status 1"
  expect "H-23: the Maven problem names the Input/output error" has_text "$WORK/out.h23.mvn" "Input/output error"

  make_cache_fixture
  run_standalone "$WORK/out.h23.nojar" h23-caches-survive-recreate.sh FAKE_NO_MAVEN_JAR=1
  expect "H-23: a downloaded jar that never reaches the Mac fails" equals "$CHECK_RC" "1"
  expect "H-23: the missing jar is named" has_text "$WORK/out.h23.nojar" "junit-4.13.2.jar"
  expect "H-23: the missing jar says it was missing before the recreate" has_text "$WORK/out.h23.nojar" "before the recreate"

  make_cache_fixture
  mkdir -p "$FIXTURE/state/m2/repository/junit/junit/4.13.2"
  : >"$FIXTURE/state/m2/repository/junit/junit/4.13.2/junit-4.13.2.jar"
  run_standalone "$WORK/out.h23.leftover" h23-caches-survive-recreate.sh FAKE_NO_MAVEN_JAR=1
  expect "H-23: a jar left by an earlier run does not satisfy a download that wrote nothing" equals "$CHECK_RC" "1"
  expect "H-23: the leftover case names the missing jar" has_text "$WORK/out.h23.leftover" "junit-4.13.2.jar is missing on the Mac before the recreate"

  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h23.none" h23-caches-survive-recreate.sh
  expect "H-23: no test sandbox fails" equals "$CHECK_RC" "1"
  expect "H-23: no test sandbox says to run run-all.sh first" has_text "$WORK/out.h23.none" "run-all.sh first"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h23_alone
finish_cases
