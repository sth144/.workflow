# joplin daily log

Containerized Python script that creates one Joplin daily note and fills it with:
- Trello open cards
- Google Calendar events (next 24 hours)
- Home Assistant entity states

The script is idempotent per date/title. If the note already exists, it does not create a duplicate.

## Files

- `daily_log.py`: main integration script
- `requirements.txt`: Python dependencies
- `Dockerfile.joplin_daily`: image build file
- `run_joplin_daily.sh`: wrapper to build image and run one-shot container
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

## Cron

Use the entry in:
- `src/cronjobs/local-ha-raspbian/joplin-daily`

It calls the wrapper script and logs to:
- `/home/pi/.cache/.workflow/cronjob.log`
