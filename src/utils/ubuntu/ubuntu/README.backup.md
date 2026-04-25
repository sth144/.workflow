# Workflow Ubuntu Backup

This directory contains the Ubuntu backup path that is intended to be staged into
`/usr/local/bin/ubuntu/` for this workstation workflow.

## Goals

The backup job is designed to be competent for restoration, not just copying files:

- it creates dated snapshots under a local backup root on the `D` drive
- it mirrors the same snapshots to the `O` drive mount
- it captures package selections and apt configuration separately from user data
- it archives selected `/etc` content separately from user-home content
- it writes a manifest and `SHA256SUMS`
- it keeps a `current/` copy plus dated `snapshots/`
- it enforces retention after successful publication

## Files

- `run_local_backup.sh`: primary snapshot script
- `restore_local_backup.sh`: verification and restore helper
- `workflow-backup.conf.example`: example host configuration
- `package-backup.sh`: compatibility wrapper for the old entry point

## Snapshot Layout

Each snapshot directory contains:

- `manifest.json`: high-level snapshot metadata
- `SHA256SUMS`: checksum manifest for every file in the snapshot
- `RESTORE.txt`: quick restore notes copied with the snapshot
- `bin/restore_local_backup.sh`: restore helper bundled into the snapshot
- `metadata/workflow-backup.conf`: the effective config used to build the snapshot
- `packages/`: package selections, apt metadata, and keyring material
- `home/home.tar.zst` or `home/home.tar.gz`: archive of selected home paths
- `etc/etc.tar.zst` or `etc/etc.tar.gz`: archive of selected `/etc` paths

`current/` is refreshed from the latest completed snapshot after validation. It is a
copy, not a symlink, so it remains usable on mounted NTFS/CIFS destinations.

## Configuration

The backup job is configured by `workflow-backup.conf`, which is expected to live
next to the staged script at `/usr/local/bin/ubuntu/workflow-backup.conf`.

Important settings:

- `LOCAL_MOUNTPOINT` and `REMOTE_MOUNTPOINT`: required mounted filesystems
- `LOCAL_BACKUP_ROOT` and `REMOTE_BACKUP_ROOT`: destination roots
- `REQUIRE_REMOTE_MIRROR`: when `true`, the job fails if the `O` drive mount is unavailable
- `HOME_INCLUDE_PATHS`: authoritative home data to archive
- `HOME_EXCLUDE_PATTERNS`: rsync-style exclusions applied while building the home archive
- `ETC_INCLUDE_PATHS`: system paths to archive into the `/etc` tarball
- `KEEP_DAILY_DAYS`, `KEEP_WEEKLY_WEEKS`, `KEEP_MONTHLY_MONTHS`: retention policy

The restore quality of the backup is defined by these include lists. Keep them explicit.
Do not revert to backing up all of `/home` unless you are willing to handle the noise and
restore ambiguity that comes with it.

## Cron

The intended cron entry uses `flock` and runs as `root` so the job can read `/etc`:

```cron
0 1 * * 0 root /usr/bin/flock -n /var/lock/workflow-backup.lock /usr/local/bin/ubuntu/run_local_backup.sh >> /home/sthinds/.cache/.workflow/backup.log 2>&1
```

This gives one weekly full snapshot with a non-overlapping lock. If you want daily
backups, change only the schedule, not the command shape.

## Manual Operation

Run a backup manually with the staged script:

```bash
sudo /usr/local/bin/ubuntu/run_local_backup.sh
```

Override the config path when testing from the repo tree:

```bash
sudo WORKFLOW_BACKUP_CONFIG="$PWD/src/utils/local-ubuntu-pc/ubuntu/workflow-backup.conf" \
  "$PWD/src/utils/ubuntu/ubuntu/run_local_backup.sh"
```

## Restore

Verify a snapshot before restoring:

```bash
/usr/local/bin/ubuntu/restore_local_backup.sh verify /mnt/D/Archives/Backups/local-ubuntu-pc/current
```

Extract home data into `/`:

```bash
sudo /usr/local/bin/ubuntu/restore_local_backup.sh extract-home /mnt/D/Archives/Backups/local-ubuntu-pc/current /
```

Extract archived `/etc` content into `/`:

```bash
sudo /usr/local/bin/ubuntu/restore_local_backup.sh extract-etc /mnt/D/Archives/Backups/local-ubuntu-pc/current /
```

Restore package selections:

```bash
sudo /usr/local/bin/ubuntu/restore_local_backup.sh restore-packages /mnt/D/Archives/Backups/local-ubuntu-pc/current
```

Recommended restore order:

1. Verify the snapshot.
2. Extract `etc`.
3. Restore apt metadata and package selections.
4. Extract `home`.
5. Reboot and validate services.

## Notes

- The archive format prefers `zstd` and falls back to `gzip`.
- Package state is separated from file data so apt repair and file restore can be done independently.
- If local publication succeeds but remote sync fails, the local snapshot remains available and the job exits non-zero.
