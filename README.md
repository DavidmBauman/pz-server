# Project Zomboid server container (fixed fork of ich777's)

This is ich777's `projectzomboid` branch with five fixes. Everything else —
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

**3. No bundled config template.** Upstream downloads a `cfg.zip` from GitHub
on first boot and, if that fails, calls `sleep infinity` — a container that
looks alive but never starts. That template also dates from 2019: 108 settings
where current builds have roughly twice as many, and it silently presets
`Password=Docker`, `PVP=true`, `MaxPlayers=64`, and a `PublicName` of "Docker
ProjectZomboid". New users hit "wrong server password given" with no idea why.

It is gone. The server now writes its own current, complete config on first
start. This is only possible because of fix 1 — the interactive admin-password
prompt that made a template necessary is skipped once `-adminpassword` actually
reaches the game.

**4. `SERVER_PASSWORD` env var.** Sets the join password without hand-editing
the ini. Leave it unset and the ini is never touched, so manual edits survive
restarts. Set it empty (`SERVER_PASSWORD=`) to explicitly clear the password.
Note this is the *join* password every player types; `ADMIN_PWD` is a separate
thing, used only to log in as admin once already in the game.

On a brand-new server the ini does not exist yet during the first start, so
`SERVER_PASSWORD` applies from the second start onward. On any server that has
run once, it applies immediately.

**5. Loud warning if `ADMIN_PWD` is left at its default.** The default is
published in this file and is therefore public knowledge. The server still
starts — it just tells you.

## Notes

To start over with a fresh config on an existing server, delete the `Zomboid`
directory from your serverfiles volume and restart. This wipes settings, the
player database, and the world, so back it up first if you want to keep the
save.

Set memory through `GAME_PARAMS`, not by editing
`serverfiles/ProjectZomboid64.json` — SteamCMD rewrites that file on every game
update, so edits there disappear on patch day.

If ich777 fixes this upstream, `docker build` against the original branch again
and drop this fork. Nothing here depends on it.

## Server join password

No password by default. To set one, either add `--env 'SERVER_PASSWORD=yourpw'`
to the run command, or edit `Password=` in
`serverfiles/Zomboid/Server/servertest.ini` and restart.

If you see "wrong server password given" on a server built from the upstream
image, that is the 2019 template's preset `Password=Docker`. Blank that line
and restart.
