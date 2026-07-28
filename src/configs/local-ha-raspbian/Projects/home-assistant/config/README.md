# Home Assistant config (local-ha-raspbian)

Home Assistant runs as the `home-assistant` container (`lscr.io/linuxserver/homeassistant`)
on the Pi, with `/home/pi/Projects/home-assistant/config` bind-mounted to `/config`.
The container uses **host networking**, so it reaches LAN devices directly.

Only files that are safe to track live here. `configuration.yaml` is **not** mirrored —
it carries host-specific integration blocks and `!secret` references.

## Required `configuration.yaml` entries

```yaml
template: !include templates.yaml
```

`automation: !include_dir_merge_list automation/` is already present, which is how
`automation/sports-auto-tune.yaml` gets picked up.

Adding a new top-level key requires a **full HA restart**, not a reload.

## Contents

| File | Purpose |
|---|---|
| `templates.yaml` | `sensor.live_tracked_game` — dynamic roster of in-progress TeamTracker games |
| `automation/sports-auto-tune.yaml` | Wakes the TV + Shield and launches the app carrying a tracked team's live game |
| `custom_templates/streaming_apps.jinja.example` | Scaffold for the network → app map |

### `custom_templates/streaming_apps.jinja` is NOT tracked

The live file is gitignored, because which networks are mapped reveals which
streaming services the household subscribes to. To deploy on a fresh host:

```bash
cp custom_templates/streaming_apps.jinja.example \
   custom_templates/streaming_apps.jinja
# fill in your own services, then:
#   action: homeassistant.reload_custom_templates
```

The automation imports it as a Jinja macro, so a missing file breaks the
`activity` variable. The `.example` documents the contract and how to discover
package names / deep links over ADB.

## Sports auto-tune

Triggered off `sensor.live_tracked_game`, which derives from
`integration_entities('teamtracker')` at render time. **Teams are not listed
anywhere** — adding a team to the TeamTracker integration is enough, no edits here.

The network → app mapping lives in `custom_templates/streaming_apps.jinja`
(untracked, see above) and is called as `app_for(network)`. It returns an Android
TV package name, a deep link, or `unsupported` — the last of which routes to a
notification instead of touching the TV.

Values there were read off the Shield itself via `androidtv.adb_command`
(`pm list packages`, `cmd package dump`), not guessed. Two findings worth keeping:
Prime Video on this device is the Shield-specific `…livingroom.nvidia` build, and
YouTube TV is installed, making it a sound catch-all for linear channels that lack
a dedicated app.

### Guards

- **08:00–23:00 only.** Evaluated at kickoff, so a 22:45 start still fires.
- **Never interrupts.** Requires the TV to be *positively* `off`/`standby`
  (`unavailable`/`unknown` are rejected — they mean HA lost track of the TV, which
  is when a hijack is most likely), plus no androidtv/ADB media_player `playing`
  or `paused`, plus no Plex playback on the Shield.

Consequence of failing safe: if the `samsungtv` integration goes `unavailable`,
auto-tune stops firing rather than risking a hijack.

### Manual testing

```yaml
action: automation.trigger
target:
  entity_id: automation.sports_auto_tune_tv_at_kickoff
data:
  variables:
    test_network: "NBC"
    test_game: "sensor.ncaaf_wisconsin_badgers"
```

## Verified end to end

2026-07-28, from both devices cold: TV `off`→`on` (~18s, Wake-on-LAN), Shield
`off`→`on`, `current_activity=com.peacocktv.peacockandroid`.

Prerequisites that made it work, all on the TV
(`All Settings → General → Network → Expert Settings`):

- **TV must be connected to the network.** It had been running headless as a display
  for the Shield. Without it, `media_player.samsung_q60aa_65_tv` reads `off` even when
  the TV is physically on — which also silently disables the interrupt guard's TV check.
- **Power On with Mobile** — enabled; this is what makes Wake-on-LAN work.
- The TV's IP moves around (seen at `.25`, then `.37`). HA's DHCP discovery
  auto-corrects the config entry, but a **DHCP reservation** is worth setting.

## Known limitations

1. **Last mile inside the app.** Neither Peacock nor Prime publishes a deep link to a
   specific live event, so after launching the app the automation presses `DPAD_CENTER`
   once, betting the game is the focused hero tile. Usually right during a live window;
   not guaranteed. `foxsports://live` is the exception — it lands on live content directly.
2. **MLS / Austin FC is not automatable.** The Shield has no Apple TV app, and core
   `samsungtv` exposes only `['TV','HDMI']` as sources with `play_media` supporting
   `channel` only — so the TV's Apple TV app can't be launched from HA. Falls through to
   a notification. The HACS integration `ollo69/ha-samsungtv-smart` (app_list +
   SmartThings) would fix this.
3. **HDMI-CEC does not work on this link.** Anynet+ is enabled on the TV and the Shield
   reports `mHdmiControlEnabled: true`, `mCecOneTouchPlayEnabled: true` and a valid
   address (`0x2000`, HDMI 2), yet the TV never appears on the Shield's CEC bus
   (`dumpsys hdmi_control` lists only the Shield, `logical_address: 0x04`). Suspected
   HDMI cable without the CEC line, or a port quirk. Not blocking — Wake-on-LAN covers
   TV power — but fixing it would add automatic input switching.
