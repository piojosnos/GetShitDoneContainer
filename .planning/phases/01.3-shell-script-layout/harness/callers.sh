#!/usr/bin/env bash
# Usage, from the repo root: bash callers.sh   (prints each library function and the scripts that call it)
set -u
for lib in tests/host/lib*.sh tests/host/manual/lib*.sh; do
  [ -f "$lib" ] || continue
  for fn in $(grep -oE '^[A-Za-z_][A-Za-z0-9_]*\(\)' "$lib" | tr -d '()'); do
    callerList=""
    for script in base/sbx-entrypoint tests/host/*.sh tests/host/manual/*.sh; do
      [ "$script" = "$lib" ] && continue
      if grep -vE '^[[:space:]]*#' "$script" | grep -qw -- "$fn"; then
        callerList="$callerList $(basename "$script" .sh)"
      fi
    done
    selftest=""
    if grep -qw -- "$fn" tests/host-selftest.sh tests/guard.sh 2>/dev/null; then
      selftest=" [also named in a frozen test script]"
    fi
    printf '%-34s %-22s %2s %s%s\n' "$fn" "$(basename "$lib")" "$(echo $callerList | wc -w | tr -d ' ')" "$callerList" "$selftest"
  done
done
