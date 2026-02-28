# joplin daily log

Containerized Python script that creates one Joplin daily note and fills it with:
- Trello open cards
- Google Calendar events (next 24 hours)
- Home Assistant entity states

The script is idempotent per date/title. If the note already exists, it does not create a duplicate.

## Files

- `daily_log.py`: main integration script
- `daily_log.joplin_cli.py`: alternate integration script that starts `joplin-cli server`
- `requirements.txt`: Python dependencies
- `Dockerfile.joplin_daily`: image build file
- `run_joplin_daily.sh`: wrapper to build image and run one-shot container
- `run_joplin_daily_cli.sh`: wrapper to run the CLI-based script directly on the host
- `$HOME/.env.joplin_daily`: runtime secrets and config (create locally, do not commit)

## Required env vars

- `JOPLIN_TOKEN`

## Optional env vars

- `JOPLIN_BASE_URL` default: `http://joplin:41184`
- `JOPLIN_NOTEBOOK` default: `Areas/Journal/`
- `TRELLO_KEY`, `TRELLO_TOKEN`
- `GOOGLE_CALENDAR_ID`
- `GOOGLE_SERVICE_ACCOUNT_FILE` default in wrapper: `/run/secrets/google_service_account.json`
- `HA_BASE_URL`, `HA_TOKEN`, `HA_ENTITIES` (comma-separated)
- `TIMEZONE`
- `JOPLIN_DAILY_ENV_FILE` default: `$HOME/.env.joplin_daily`

### Optional SSH tunnel settings (for clipper bound to 127.0.0.1 on remote host)

- `JOPLIN_TUNNEL_ENABLED` set `1` or `true` to enable
- `JOPLIN_TUNNEL_SSH_TARGET` example: `pi@192.168.1.235`
- `JOPLIN_TUNNEL_LOCAL_PORT` default: `41185`
- `JOPLIN_TUNNEL_REMOTE_HOST` default: `127.0.0.1`
- `JOPLIN_TUNNEL_REMOTE_PORT` default: `41184`

## Quick setup

1. Create `$HOME/.env.joplin_daily`.
2. Add required tokens and service URLs.
3. Optionally place service account JSON at:
   - `src/utils/local-ha-raspbian/joplin/daily/google_service_account.json`
4. Run:
   - `src/utils/local-ha-raspbian/joplin/daily/run_joplin_daily.sh`

## Tunnel example

If your Joplin clipper listens only on `127.0.0.1` on host `192.168.1.235`, add this to your env file:

```env
JOPLIN_TUNNEL_ENABLED=1
JOPLIN_TUNNEL_SSH_TARGET=pi@192.168.1.235
JOPLIN_TUNNEL_LOCAL_PORT=41185
JOPLIN_TUNNEL_REMOTE_HOST=127.0.0.1
JOPLIN_TUNNEL_REMOTE_PORT=41184
```

In tunnel mode, the wrapper uses Docker host networking and sets:
- `JOPLIN_BASE_URL=http://127.0.0.1:${JOPLIN_TUNNEL_LOCAL_PORT}`

## Local host example

If you run the wrapper directly on the same host where Joplin clipper is running, you can disable the tunnel and point `JOPLIN_BASE_URL` at loopback:

```env
JOPLIN_TUNNEL_ENABLED=0
JOPLIN_BASE_URL=http://127.0.0.1:41184
```

When `JOPLIN_BASE_URL` points to `127.0.0.1` or `localhost`, the wrapper automatically uses Docker host networking so the container can reach the host clipper service.

## Joplin CLI wrapper

If you want to avoid Joplin Desktop/Web Clipper entirely, use:

- `src/utils/local-ha-raspbian/joplin/daily/run_joplin_daily_cli.sh`

It runs `daily_log.joplin_cli.py` directly on the host, starts `joplin-cli server` if needed, and defaults `STATE_PATH` to:

- `$HOME/.local/state/joplin_daily/state.json`

If `JOPLIN_CLI_BIN` is not set, the wrapper tries `joplin-cli` first, then `joplin`.

## Cron

Use the entry in:
- `src/cronjobs/local-ha-raspbian/joplin-daily`

It calls the wrapper script and logs to:
- `/home/pi/.cache/.workflow/cronjob.log`
