---
created: 2026-10-24
title: H-18 waits a fixed second for the fake API and can leave a stale server behind
area: tests
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-REVIEW.md (WR-03)
---

File: `tests/host/h18-scope-and-deny.sh:36-40`.

`run_scenario` starts `node fake-claude-api.js` in the background, sleeps 1 second, then starts Claude. On a slow start Claude hits a closed port and the check reports "Claude never reached the fake API", a false failure. Also, `run_timeout 120 docker exec ...` kills only the `docker exec` client on timeout; the node server keeps running in the container on port 8799. The next scenario's server then fails to bind, and Claude talks to the old server with the old script, so the result is wrong with no obvious cause. `kill $serverPid` is skipped if the shell is interrupted.

Suggested fix: poll for readiness instead of sleeping, and always clean up inside the in-container script.

```sh
node $containerRoot/logs/fake-claude-api.js >/dev/null 2>&1 </dev/null &
serverPid=$!
trap 'kill $serverPid 2>/dev/null' EXIT
```

Poll port 8799 until it answers (`/dev/tcp` needs bash, so run the script with `bash -c`, or poll with `node -e`). Also `pkill -f fake-claude-api.js` at the start of each scenario.
