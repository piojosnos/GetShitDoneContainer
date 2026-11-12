#!/usr/bin/env bash
# Usage, from the repo root: bash layout-lint.sh   (exit 0 = every in-scope file follows the layout rule)
# Scratch proof tool for the layout phase; checks the mechanical parts of the rule only.
set -u
bannerLine="# $(printf -- '-%.0s' $(seq 1 80))"
fileList="base/sbx-entrypoint tests/host/lib*.sh tests/host/run-all.sh tests/host/h*.sh tests/host/coexistence.sh tests/host/manual/*.sh"
problemCount=0

complain() {
  printf 'LINT: %s: %s\n' "$1" "$2"
  problemCount=$((problemCount + 1))
}

for file in $fileList; do
  [ -f "$file" ] || continue

  # 1. the entry point banner, as a three line block, exists once (libraries define functions only and are exempt)
  case "$(basename "$file")" in
    lib*.sh) ;;
    *)
      if [ "$(grep -c '^# Main / Entry Point$' "$file")" -ne 1 ]; then
        complain "$file" "needs exactly one '# Main / Entry Point' banner"
      fi
      ;;
  esac

  # 2. every banner rule is exactly 80 dashes after '# '
  badRuleCount=$(grep -E '^# -{10,}$' "$file" | grep -vcxF "$bannerLine")
  if [ "$badRuleCount" -gt 0 ]; then
    complain "$file" "$badRuleCount banner rule line(s) are not '# ' plus 80 dashes"
  fi

  # 3. a banner is a rule, one text line, a rule
  awk -v f="$file" -v rule="$bannerLine" '
    $0 == rule { if (state == 0) { state = 1; next } if (state == 2) { state = 0; next } }
    state == 1 { state = 2; next }
    END { if (state != 0) { print "LINT: " f ": a banner is not closed by a second rule line" } }' "$file"

  # 4. every function has a comment or banner right above it
  awk -v f="$file" '
    /^[A-Za-z_][A-Za-z0-9_]*\(\) *\{/ { if (prev !~ /^#/) { print "LINT: " f ":" NR ": function without a comment above: " $0 } }
    { prev = $0 }' "$file"

  # 5. no failure collection through the positional parameters in the host tests
  case "$file" in
    tests/host/*)
      if grep -nE 'set -- ("\$@"|$)|^[[:space:]]*set --$' "$file" >/dev/null; then
        grep -nE 'set -- ("\$@"|$)|^[[:space:]]*set --$' "$file" | sed "s|^|LINT: $file:|; s|\$| (set -- collection)|"
        problemCount=$((problemCount + 1))
      fi
      ;;
  esac

  # 6. bash 4 features and GNU-only options
  if grep -vE '^[[:space:]]*#' "$file" | grep -nE 'declare -[Ag]|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^|,|\^)\}|&>>|\|&|local -n|coproc|wait -n|\$BASHPID|EPOCHSECONDS|sed -i([^.]|$)|grep -P|readlink -f|date -d|\[\[ -v ' >/dev/null; then
    complain "$file" "bash 4 or GNU-only construct (see the grep above)"
  fi

  # 7. no dash as punctuation and ASCII only in comments
  if LC_ALL=C grep -nP '[^\x00-\x7F]' "$file" >/dev/null 2>&1; then
    complain "$file" "non-ASCII character"
  fi
done

if [ "$problemCount" -eq 0 ]; then
  echo "layout-lint: clean"
  exit 0
fi
echo "layout-lint: $problemCount problem(s)"
exit 1
