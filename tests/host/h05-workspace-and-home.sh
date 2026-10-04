#!/usr/bin/env bash
# H-05: the project folder is the container's working directory and shows up on the host;
# the home layout is there and owned by sandbox. The container side uses GNU stat, which is fine.
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-05 || exit 1

listing=$(in_container sh -c 'touch x.txt; ls -a /home/sandbox')
owners=$(in_container stat -c '%U %n' /home/sandbox/.local /home/sandbox/.local/state)

set --

if [ ! -f "$RUN/hosttest/x.txt" ]; then
  set -- "$@" "x.txt created in the container did not appear in $RUN/hosttest"
fi

for wanted in .bashrc .local; do
  if ! printf '%s\n' "$listing" | grep -Fxq "$wanted"; then
    set -- "$@" "ls -a /home/sandbox does not list $wanted"
  fi
done

for ownedPath in /home/sandbox/.local /home/sandbox/.local/state; do
  if ! printf '%s\n' "$owners" | grep -Fxq "sandbox $ownedPath"; then
    set -- "$@" "owner of $ownedPath is not sandbox; stat said: $(printf '%s\n' "$owners" | tr '\n' ' ')"
  fi
done

if [ "$#" -gt 0 ]; then
  fail H-05 "the workspace or home layout is wrong" "$@"
  exit 1
fi

pass H-05 "x.txt reached the host, .bashrc and .local exist, owners are sandbox"
exit 0
