# Project Zomboid server container (fixed fork of ich777's)

This is ich777's `projectzomboid` branch with three fixes. Everything else —
env var names, paths, UID 99 / GID 100 defaults, the `screen` session, the
watchdog, the `/opt/custom/user.sh` hook — is unchanged, so existing run
commands and Unraid templates keep working.

## Build and run

```bash
docker build -t pz-fixed .

docker run --name ProjectZomboid -d \
  -p 16261-16262:16261-16262/udp \
  --env 'ADMIN_PWD=yourpassword' \
  --env 'GAME_PARAMS=-Xmx8192m -Xms8192m' \
  --env 'UID=99' --env 'GID=100' \
  --volume /path/to/steamcmd:/serverdata/steamcmd \
  --volume /path/to/projectzomboid:/serverdata/serverfiles \
  pz-fixed
```

`UID=99 GID=100` is the Unraid convention. On a normal Docker host use your own
user, usually `1000`/`1000`.

## What was changed

**1. The `--` separator (the actual crash).** `ProjectZomboid64` is a native
launcher, not the server. Everything on its command line before `--` is passed
to `JNI_CreateJavaVM`; everything after goes to the game. Upstream runs:

```
ProjectZomboid64 -adminpassword ${ADMIN_PWD} ${GAME_PARAMS}
```

With no separator the JVM receives `-adminpassword`, rejects it, and the
container dies with `Unrecognized option: -adminpassword` / `Failed to create
Java VM`. Now:

```
ProjectZomboid64 ${GAME_PARAMS} -- -adminpassword ${ADMIN_PWD}
```

JVM options go in `GAME_PARAMS` and land ahead of the separator, which is where
they need to be anyway.

**2. `GAME_PARAMS` no longer defaults to the string `template`.** The upstream
Dockerfile ships `ENV GAME_PARAMS="template"`, inherited from the generic
SteamCMD image. Once the separator is in place that literal word would be
handed to the JVM as an option and crash it the same way, so the default is now
empty. `GAME_ID` defaults to `380870` instead of `template` for the same
reason, and the unused `GAME_NAME` was dropped — it is an SRCDS concept that
Project Zomboid has no use for.

**3. The config template is bundled into the image.** Upstream downloads
`cfg.zip` from GitHub on first boot and, if that fails, calls `sleep infinity`,
leaving a container that looks alive but never starts. It is now copied in at
build time, and kept as the plain `config/Zomboid/` folder rather than an
archive so it survives being moved between Windows and Linux without a
zip/unzip round trip.

## Notes

The bundled config template dates from 2019. That is fine — the game reads
the keys it recognises and rewrites the file with current defaults for anything
missing — but if you would rather have the server generate a clean modern
config, delete the `Zomboid` directory from your serverfiles volume before the
first start. The `-adminpassword` flag now reaches the game, so it will not
block on the interactive password prompt.

Set memory through `GAME_PARAMS`, not by editing
`serverfiles/ProjectZomboid64.json` — SteamCMD rewrites that file on every game
update, so edits there disappear on patch day.

If ich777 fixes this upstream, `docker build` against the original branch again
and drop this fork. Nothing here depends on it.
