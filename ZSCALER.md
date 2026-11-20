# Set up a sandbox on a computer behind Zscaler

- Zscaler opens HTTPS and signs it again with its own root certificate. macOS trusts that root (it is in the Keychain); the images do not, so a plain build stops with `curl: (60) SSL certificate problem`.
- The fix is to hand the root to `./build.sh` through `SBX_CA_CERT`. How it works and what trusts the root: "Behind a company HTTPS proxy" in [`README.md`](README.md).
- Keep Zscaler on for every step. Each step is a copy/paste block with what to expect under it.

## 1. Docker Desktop: use Docker VMM

Docker Desktop, Settings, General, Virtual Machine Manager: pick **Docker VMM**, then Apply & restart.

- With the Apple Virtualization Framework the sandbox builds and starts, but `sbx-init` FAILs its GSD step with `EACCES, Permission denied '/home/sandbox/workspace/state/claude/gsd-core/commands/gsd'` in the installer log.

## 2. Update the tools clone

```bash
T=$(dirname "$(dirname "$(command -v sbx-upgrade)")")
cd "$T" && git status --short
```

Expect: no output.

```bash
git switch main && git pull --ff-only
```

The host commands run through uv. Install it once, then make the first uv run with `UV_SYSTEM_CERTS=true`. That run fetches Python 3.12 through the proxy, and the variable makes uv trust the macOS Keychain, which already holds the Zscaler root:

```bash
brew install uv
```

```bash
UV_SYSTEM_CERTS=true sbx-list
```

Expect: a table of your sandboxes, or `no sandboxes registered`, and no certificate error. uv keeps the Python it fetched, so later runs need no variable.

- A sandbox registered before the JSON registry shows nothing yet; follow "Move the registry to JSON" in [`MIGRATION.md`](MIGRATION.md) first.

## 3. Export the Zscaler root and set the variable

```bash
security find-certificate -a -c "Zscaler Root CA" -p /Library/Keychains/System.keychain > "$HOME/zscaler-root-ca.pem"
```

```bash
echo 'export SBX_CA_CERT="$HOME/zscaler-root-ca.pem"' >> ~/.zshrc
```

Open a new terminal, then:

```bash
echo "$SBX_CA_CERT"
grep -c 'BEGIN CERTIFICATE' "$SBX_CA_CERT"
```

Expect: the path, then a number of 1 or more.

- The export holds certificates only, no key.
- Every terminal that builds needs the variable. It is in `~/.zshrc`, so a new terminal has it.

## 4. Build and upgrade the sandbox

`NAME` is your sandbox name. A new one: `sbx-add NAME HOST_PATH` first, or `sbx-add NAME HOST_PATH cursor` for a Cursor sandbox.

```bash
sbx-upgrade NAME
```

Expect:

- a banner of `*` lines with the Zscaler subject and fingerprint, before the build and after it;
- no `curl: (60)` at the `gh` download or at the Cursor CLI download from `downloads.cursor.com`;
- the tool versions line last.

## 5. Check the tools

```bash
sbx-shell NAME
```

In the sandbox shell, one line at a time:

```bash
sbx-init
```

Expect: a last line `sbx-init: N steps passed; run sbx-selfcheck to check the sandbox`. Only the best-practices step may FAIL, because there is no clone yet; the next two lines fix that.

```bash
sbx-gh-login
```

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://release-assets.githubusercontent.com/
```

```bash
gh api user --jq .login
```

```bash
npm view left-pad version
```

```bash
node -e "fetch('https://registry.npmjs.org/').then(r => console.log(r.status))"
```

```bash
mvn -q dependency:get -Dartifact=junit:junit:4.13.2
```

```bash
python3 -m venv /tmp/v && /tmp/v/bin/pip install requests
```

```bash
uv venv /tmp/u && uv pip install --python /tmp/u/bin/python requests
```

```bash
sbx-claude
```

Log in, send one message, then `/exit`.

In a Cursor sandbox, run this instead of `sbx-claude`:

```bash
sbx-cursor login
```

Open the printed link in the host browser, then start `sbx-cursor`, send one prompt and exit.

- The proxy must pass three Cursor hosts: `downloads.cursor.com` (the build), `cursor.com` (the login page) and `api2.cursor.sh` (the prompts).

| Check | Expect |
|---|---|
| curl | `200` or a similar code |
| gh | your login |
| npm | a version number |
| Node | `200` |
| Maven | no output (quiet means it worked) |
| pip | `Successfully installed ...` |
| uv | `Installed ...` |
| Claude Code | an answer |
| Cursor CLI | an answer |

None may print `curl: (60)`, `UNABLE_TO_VERIFY_LEAF_SIGNATURE`, `CERTIFICATE_VERIFY_FAILED` or `PKIX path building failed`.

## When something fails

| Symptom | Fix |
|---|---|
| uv fails with a certificate error on its first run | Run it once with `UV_SYSTEM_CERTS=true` (step 2). |
| `curl: (60)` during the build | The variable is missing in that terminal. Run `echo "$SBX_CA_CERT"`; open a new terminal if it is empty. |
| `build.sh: SBX_CA_CERT ...` | The rest of the line says what is wrong. It must be an absolute path to a readable PEM file. Nothing was built. |
| `the build failed; sbx-NAME was left as it was` | Read the build output above it. The sandbox still runs on the old image. |
| `FAIL: ...-gsd-sync` with `EACCES ... gsd-core/commands/gsd` in the log | Switch Docker Desktop to Docker VMM (step 1), then `sbx-start NAME` and `sbx-init`. |
| `ccusage` cannot fetch its price table | Add `--offline`. |
| `UNABLE_TO_VERIFY_LEAF_SIGNATURE` from a Node program run with `docker exec` | Run it from `sbx-shell`. |
