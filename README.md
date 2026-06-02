# Docker

## Start the container

First CHANGE THE VOLUME entry in docker compose to something that makes sense.
The idea is that Claude/OpenCode will use the internal folder in the container
and you will easily access it outside on your computer without risking the LLM
to do something destructive on your computer.

```
DEPRECATED: docker-compose up -d
```

Use new script:

As path, create a folder above the root of the project, which will be the
sandbox of the container

```
sh cc-up.sh ssg /Users/demian/GSD_StaticSiteGenerator/
```

```
docker ps -a
```

```
CONTAINER ID   IMAGE            COMMAND                  CREATED          STATUS          PORTS     NAMES
45d9105bbe5c   <CORRECT NAME>   "/usr/local/bin/dock…"   12 seconds ago   Up 11 seconds             <CORRECT NAME>
```

## Attach terminal

```
docker exec -it <CORRECT NAME> /bin/bash
```

CORRECT NAME, is something on the lines of cc_gsd_c / oc_gsd_c

## Stop the container

Note, -v destroys the container. Useful to change something in the container itself.

```
docker-compose down -v
```


# Claude

## Run Claude

Run on the actual root of the project. Not the home of sandbox user

```
claude --dangerously-skip-permissions
```

## Resume work if needed

```
/gsd:resume-work
```

# OpenCode

## Run OpenCode

Run the container as stated in the instructions above.

```
docker-compose up -d
```

Open http://127.0.0.1:4096/ on the host machine.

The command line to run opencode web are already baked in docker compose

```
opencode web --hostname 0.0.0.0
```

## Resume work if needed

```
/gsd:resume-work
```

# Links / Refs

Claude Code: https://code.claude.com/docs/en/quickstart

GSD: https://github.com/glittercowboy/get-shit-done
