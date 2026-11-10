# Set up a sandbox on a computer behind Zscaler

- Zscaler opens HTTPS and signs it again with its own root certificate. The Mac trusts that root; the images do not, so a plain build stops with `curl: (60) SSL certificate problem`.
- The fix is to hand the root to `./build.sh` through `SBX_CA_CERT`. How it works and what trusts the root: "Behind a company HTTPS proxy" in [`README.md`](README.md).
- Keep Zscaler on for every step. Each step is a copy/paste block with what to expect under it.

## 1. Docker Desktop: use Docker VMM

Docker Desktop, Settings, General, Virtual Machine Manager: pick **Docker VMM**, then Apply & restart.

- With the Apple Virtualization Framework the sandbox builds but does not start: the start hook stops with `EACCES, Permission denied '/home/sandbox/workspace/state/claude/gsd-core/commands/gsd'`.

## 2. Update the tools clone

```bash
T=$(dirname "$(dirname "$(command -v sbx-upgrade)")")
cd "$T" && git status --short
```

Expect: no output.

```bash
git switch main && git pull --ff-only
```

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

`NAME` is your sandbox name. A new one: `sbx-add NAME HOST_PATH` first.

```bash
sbx-upgrade NAME
```

Expect:

- a banner of `*` lines with the Zscaler subject and fingerprint, before the build and after it;
- no `curl: (60)` at the `gh` download;
- the tool versions line last.

## 5. Check the tools

```bash
sbx-shell NAME
```

In the sandbox shell, one line at a time:

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

None may print `curl: (60)`, `UNABLE_TO_VERIFY_LEAF_SIGNATURE`, `CERTIFICATE_VERIFY_FAILED` or `PKIX path building failed`.

## When something fails

| Symptom | Fix |
|---|---|
| `curl: (60)` during the build | The variable is missing in that terminal. Run `echo "$SBX_CA_CERT"`; open a new terminal if it is empty. |
| `build.sh: SBX_CA_CERT ...` | The rest of the line says what is wrong. It must be an absolute path to a readable PEM file. Nothing was built. |
| `the build failed; sbx-NAME was left as it was` | Read the build output above it. The sandbox still runs on the old image. |
| `EACCES ... gsd-core/commands/gsd` at the start | Switch Docker Desktop to Docker VMM (step 1), then `sbx-start NAME`. |
| `ccusage` cannot fetch its price table | Add `--offline`. |
| `UNABLE_TO_VERIFY_LEAF_SIGNATURE` from a Node program run with `docker exec` | Run it from `sbx-shell`. |
