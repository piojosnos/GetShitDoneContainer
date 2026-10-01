#!/usr/bin/env bash
# Static checks for the sbx layout. Runs without Docker: greps the files for pins,
# the FROM chain, the mount layout and forbidden patterns. Host-side checks (real
# builds, real mounts) live in the Mac checklist, not here.
#
# No "set -e": the script counts failures, and a zero-match grep exits 1.
set -u
cd "$(dirname "$0")/.."

FAILS=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }

# need FILE...: every file must exist.
need() {
  for f in "$@"; do
    if [ -f "$f" ]; then pass "exists $f"; else fail "missing $f"; fi
  done
}
# has LABEL ERE FILE...: the pattern must match in every file.
has() {
  local label=$1 re=$2; shift 2
  local f ok=1
  for f in "$@"; do grep -Eq -- "$re" "$f" 2>/dev/null || ok=0; done
  if [ "$ok" = 1 ]; then pass "$label"; else fail "$label"; fi
}
# hasx LABEL LINE FILE...: a whole line must equal LINE in every file.
hasx() {
  local label=$1 line=$2; shift 2
  local f ok=1
  for f in "$@"; do grep -Fxq -- "$line" "$f" 2>/dev/null || ok=0; done
  if [ "$ok" = 1 ]; then pass "$label"; else fail "$label"; fi
}
# hasall LABEL FILE ERE...: every pattern must match in FILE (one label for a group).
hasall() {
  local label=$1 f=$2 re ok=1; shift 2
  for re in "$@"; do grep -Eq -- "$re" "$f" 2>/dev/null || ok=0; done
  if [ "$ok" = 1 ]; then pass "$label"; else fail "$label"; fi
}
# lacks LABEL ERE FILE...: the pattern must match nowhere; offending lines are shown.
lacks() {
  local label=$1 re=$2; shift 2
  local out
  out=$(grep -En -- "$re" "$@" 2>/dev/null)
  if [ -z "$out" ]; then pass "$label"; else echo "$out"; fail "$label"; fi
}

BASE=base/Dockerfile
CLAUDE=claude/Dockerfile
COMPOSE=compose.yml
DOC=SANDBOX.md
ENTRY=base/sbx-entrypoint
DOCKERFILES="$BASE $CLAUDE"
ALLFILES="$BASE $CLAUDE $COMPOSE $ENTRY"

need $BASE $CLAUDE $COMPOSE $DOC $ENTRY

# --- base image ---
hasx "base image pinned to ubuntu:24.04" "FROM ubuntu:24.04" $BASE
hasall "Node 24.21.0 pinned and checksum-verified" $BASE '^ARG NODE_VERSION=24\.21\.0$' 'SHASUMS256\.txt.*sha256sum -c'
has "sandbox user is uid 1000" 'useradd .*-u 1000' $BASE
has "git safe.directory set system-wide" "^RUN git config --system safe\.directory '\*'$" $BASE
if awk '/^USER sandbox$/ { u=1 } u && /mkdir -p/ && /\/home\/sandbox\/\.local\/state\/sbx/ { f=1 } END { exit !f }' $BASE; then
  pass "home directories created as the sandbox user"
else
  fail "home directories created as the sandbox user"
fi
for f in $DOCKERFILES; do
  last=$(grep -E '^USER' "$f" | tail -n 1)
  name=${f%%/*}
  if [ "$last" = "USER sandbox" ]; then pass "$name image ends as USER sandbox"; else fail "$name image ends as USER sandbox"; fi
done
lacks "no sudo in images" '\bsudo\b' $DOCKERFILES

# --- claude image ---
hasall "claude image builds FROM the base" $CLAUDE '^ARG BASE_IMAGE=sbx-base:local$' '^FROM \$\{BASE_IMAGE\}$'
if [ "$(grep -c '^FROM' $CLAUDE)" -eq 1 ]; then pass "claude image has a single FROM"; else fail "claude image has a single FROM"; fi
hasall "Claude Code pinned to 2.1.285 via npm" $CLAUDE '^ARG CLAUDE_CODE_VERSION=2\.1\.285$' 'npm install -g .*@anthropic-ai/claude-code@\$\{CLAUDE_CODE_VERSION\}'
hasall "CLAUDE_CONFIG_DIR and DISABLE_UPDATES in image ENV" $CLAUDE 'CLAUDE_CONFIG_DIR=/home/sandbox/\.claude' 'DISABLE_UPDATES=1'

# --- compose ---
hasall "compose project and container named sbx-NAME" $COMPOSE '^name: "sbx-\$\{SBX_NAME:\?' 'container_name: "sbx-\$\{SBX_NAME\}"'
has "SBX_NAME and SBX_DIR are required" '\$\{SBX_DIR:\?' $COMPOSE
hasall "compose uses the local sbx-claude image only" $COMPOSE '^[[:space:]]*image: sbx-claude:local$' '^[[:space:]]*pull_policy: never'
hasall "init plus sleep infinity keep-alive" $COMPOSE '^[[:space:]]*init: true' '^[[:space:]]*command: \["sleep", "infinity"\]'
has "workspace bind target" '^[[:space:]]*target: /home/sandbox/workspace$' $COMPOSE
has "claude state bind target" '^[[:space:]]*target: /home/sandbox/\.claude$' $COMPOSE
n_bind=$(grep -Ec '^[[:space:]]*-?[[:space:]]*type: bind$' $COMPOSE)
n_chp=$(grep -Ec '^[[:space:]]*create_host_path: false$' $COMPOSE)
if [ "$n_bind" -ge 1 ] && [ "$n_bind" -eq "$n_chp" ]; then
  pass "every bind mount sets create_host_path false"
else
  fail "every bind mount sets create_host_path false"
fi
n_src=$(grep -Ec '^[[:space:]]*source:' $COMPOSE)
n_src_ok=$(grep -Ec '^[[:space:]]*source: "\$\{SBX_DIR' $COMPOSE)
if [ "$n_src" -ge 1 ] && [ "$n_src" -eq "$n_src_ok" ]; then
  pass "every mount source is under SBX_DIR"
else
  fail "every mount source is under SBX_DIR"
fi
lacks "nothing mounted over /home/sandbox" 'target:[[:space:]]*"?/home/sandbox"?[[:space:]]*$' $COMPOSE
lacks "no short-syntax mounts" '^[[:space:]]*-[[:space:]]*"?(\$\{|/|\.|~)' $COMPOSE
lacks "no docker socket mount" 'docker\.sock' $COMPOSE

# --- cross-file wiring: the claude state mount target is CLAUDE_CONFIG_DIR ---
cfg=$(grep -Eo 'CLAUDE_CONFIG_DIR=[^[:space:]\\]+' $CLAUDE | head -n 1 | cut -d= -f2)
if [ -n "$cfg" ] && grep -Fxq "        target: $cfg" $COMPOSE; then
  pass "CLAUDE_CONFIG_DIR is the claude state mount target"
else
  fail "CLAUDE_CONFIG_DIR is the claude state mount target"
fi

# --- shell history state (plan 01-02) ---
has "shell history bind target" '^[[:space:]]*target: /home/sandbox/\.local/state/sbx/shell$' $COMPOSE
hasall "HISTFILE and PROMPT_COMMAND in image ENV" $BASE 'HISTFILE=/home/sandbox/\.local/state/sbx/shell/bash_history' 'PROMPT_COMMAND="history -a"'
if awk '/^USER sandbox$/ { u=1 } u && /mkdir -p/ && /\/home\/sandbox\/\.local\/state\/sbx\/shell/ { f=1 } END { exit !f }' $BASE; then
  pass "history mount target created as sandbox"
else
  fail "history mount target created as sandbox"
fi

# --- gh and git state (plan 01-02) ---
hasall "gh 2.102.0 pinned and checksum-verified" $BASE '^ARG GH_VERSION=2\.102\.0$' 'checksums\.txt.*sha256sum -c'
hasall "gh and git config in image ENV" $BASE 'GH_CONFIG_DIR=/home/sandbox/\.local/state/sbx/gh' 'GIT_CONFIG_GLOBAL=/home/sandbox/\.local/state/sbx/git/config'
has "gh state bind target" '^[[:space:]]*target: /home/sandbox/\.local/state/sbx/gh$' $COMPOSE
has "git state bind target" '^[[:space:]]*target: /home/sandbox/\.local/state/sbx/git$' $COMPOSE
if awk '/^USER sandbox$/ { u=1 } u && /mkdir -p/ && /\/home\/sandbox\/\.local\/state\/sbx\/gh/ && /\/home\/sandbox\/\.local\/state\/sbx\/git/ { f=1 } END { exit !f }' $BASE; then
  pass "state mount targets created as sandbox"
else
  fail "state mount targets created as sandbox"
fi
if [ "$n_bind" -eq 5 ]; then pass "exactly five bind mounts"; else fail "exactly five bind mounts"; fi
has "quick-start creates every bind source" 'state/\{claude,shell,gh,git\}' $DOC

# --- mount-check entrypoint (plan 01-03) ---
if [ -x $ENTRY ]; then pass "entrypoint is executable"; else fail "entrypoint is executable"; fi
if bash -n $ENTRY 2>/dev/null; then pass "entrypoint parses"; else fail "entrypoint parses"; fi
last=$(grep -v '^[[:space:]]*$' $ENTRY | tail -n 1)
if grep -Fq '/proc/self/mountinfo' $ENTRY && grep -Fq 'SBX_MOUNTS' $ENTRY && [ "$last" = 'exec "$@"' ]; then
  pass "entrypoint checks mounts then execs"
else
  fail "entrypoint checks mounts then execs"
fi
ok=1
for t in /home/sandbox/workspace /home/sandbox/.local/state/sbx/shell /home/sandbox/.local/state/sbx/gh /home/sandbox/.local/state/sbx/git; do
  grep -Fq "$t" $ENTRY || ok=0
done
if [ "$ok" = 1 ]; then pass "entrypoint checks every base mount target"; else fail "entrypoint checks every base mount target"; fi
if grep -Fxq 'COPY sbx-entrypoint /usr/local/bin/sbx-entrypoint' $BASE \
   && grep -Fxq 'ENTRYPOINT ["/usr/local/bin/sbx-entrypoint"]' $BASE; then
  pass "base image installs and uses the entrypoint"
else
  fail "base image installs and uses the entrypoint"
fi
has "claude image adds its state mount to SBX_MOUNTS" 'SBX_MOUNTS=/home/sandbox/\.claude' $CLAUDE
has "docs show the entrypoint bypass for smoke tests" '--entrypoint claude sbx-claude:local' $DOC

# --- privileges and start-up safety (plan 01-03) ---
has "no-new-privileges set" 'no-new-privileges:true' $COMPOSE
if grep -A1 'cap_drop:' $COMPOSE | grep -Fq -- '- ALL'; then pass "all capabilities dropped"; else fail "all capabilities dropped"; fi
if grep -Fq 'MISSING: $SBX_DIR/$d' $DOC; then pass "docs carry the missing-folder preflight"; else fail "docs carry the missing-folder preflight"; fi
if grep -Fq 'docker compose logs' $DOC; then pass "docs tell the user to read compose logs"; else fail "docs tell the user to read compose logs"; fi

# --- forbidden patterns ---
lacks "no VOLUME instruction" '^[[:space:]]*VOLUME([[:space:]]|$)' $DOCKERFILES
lacks "no platform override" 'platform:|--platform|linux/amd64' $ALLFILES
lacks "no floating latest tags" ':latest|@latest' $ALLFILES
lacks "no pipe-to-shell installers" '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh([[:space:]]|$)' $DOCKERFILES
lacks "no compromised GSD package names" 'get-shit-done-cc|gsd-build' $ALLFILES $DOC
lacks "no runtime package runner" '\b(npx|bunx)\b|pnpm dlx|yarn dlx' $ALLFILES
lacks "no old cc_ names" 'cc_gsd|\bcc_' $ALLFILES

# --- quick-start doc ---
hasall "quick-start builds both images and starts with up --wait" $DOC '^docker build -t sbx-base:local base/$' '^docker build -t sbx-claude:local claude/$' '^docker compose up -d --wait$'
if grep -Eq '^[[:space:]]*image: sbx-claude:local$' $COMPOSE && grep -Fq 'docker build -t sbx-claude:local claude/' $DOC; then
  pass "quick-start builds the image compose runs"
else
  fail "quick-start builds the image compose runs"
fi
lacks "docs never remove volumes on down" 'down[^#]*(-v\b|--volumes)' $DOC $COMPOSE
lacks "docs use docker compose v2 only" 'docker-compose' $DOC $COMPOSE

# --- coexistence: the old layout stays byte-for-byte unchanged ---
BASE_COMMIT=934e2c5694dbc1524ae9993f2bf025ffa779358e
if git diff --quiet "$BASE_COMMIT" -- ClaudeCode OpenCode README.md \
   && [ -z "$(git ls-files --others --exclude-standard -- ClaudeCode OpenCode)" ]; then
  pass "old layout untouched"
else
  fail "old layout untouched"
fi

if [ "$FAILS" -eq 0 ]; then
  echo "All static checks passed"
  exit 0
fi
echo "$FAILS static check(s) failed"
exit 1
