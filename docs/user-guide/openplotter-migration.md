# Migrating from OpenPlotter

This guide moves your data from an existing OpenPlotter (Raspberry Pi OS) system to a fresh marine HaLOS install on the **same device**, using an external USB stick to carry the data across the reflash. Two scripts do the work: one backs up your data on OpenPlotter, the other restores it on HaLOS. If you'd rather move the data by hand, [**Data locations**](#data-locations) at the end of this guide maps every source path to its place on HaLOS.

The scripts migrate four things, and nothing else:

- **Signal K** — server configuration, plugins, users, and charts
- **InfluxDB** — your full history of logged sensor data
- **Grafana** — datasources and (where possible) dashboards
- **OpenCPN** — configuration and plugin data

!!! danger "Back up more than just these four before you reflash"
    Installing HaLOS wipes the disk, and the wipe is irreversible. The backup script copies **only** the four domains above — everything else is left behind: personal files, charts stored outside `~/.opencpn`, custom `/etc` configuration, and any apps you installed yourself. Copy anything else you care about to the stick before you reflash. Until the restore succeeds, that stick is the only copy of your data.

## Before you start

- **A USB stick large enough for your data.** InfluxDB history is usually the biggest part and can run to tens of gigabytes. The backup script measures your data and refuses to start if the stick is too small, so a 64 GB stick is a safe choice. Format it as exFAT or ext4 if your InfluxDB data exceeds 4 GB (FAT32 cannot hold files that large).
- **Both devices online.** The scripts are downloaded over the network on each device.
- **Run as your normal user** (for example `pi`). The scripts use `sudo` only where they need to.

## Step 1 — Back up on OpenPlotter

On the running OpenPlotter system, plug in the USB stick, then download and run the backup script:

```bash
curl -fsSLO https://docs.halos.fi/migrate/openplotter-backup.sh
bash openplotter-backup.sh
```

The script stops Signal K, InfluxDB and Grafana for a consistent copy (and asks you to close OpenCPN), copies each part to the stick, and verifies the result. When the migration backup is complete and verified it prints:

```
========================================
  MIGRATION BACKUP COMPLETE AND VERIFIED
========================================
```

followed by a reminder that this covers only the four migrated domains. If you do not see that banner, the backup is incomplete — re-run the script and resolve any error it reports. Remember the banner confirms only the migration backup; copy anything else you need (see the danger note above) before you reflash.

!!! tip "Keep the stick safe"
    Leave the USB stick plugged in, or set it aside somewhere safe. It is your only copy of the data until the restore on HaLOS succeeds. It also contains credentials (Signal K user accounts, Grafana and InfluxDB secrets), so don't hand it around — and wipe it once the migration is done.

## Step 2 — Flash HaLOS

Flash the **Marine** HaLOS image onto the device as usual. See [Choosing an Image](../getting-started/choosing-an-image.md) and [Quick Start](../getting-started/quick-start.md). Do not reuse or wipe the USB stick.

## Step 3 — Restore on HaLOS

Boot the freshly-flashed HaLOS device, plug in the same USB stick, then download and run the restore script:

```bash
curl -fsSLO https://docs.halos.fi/migrate/halos-restore.sh
bash halos-restore.sh
```

The script finds the backup on the stick, checks it is complete, and restores each part. For InfluxDB it installs the marine InfluxDB app if needed, swaps in your data, and renames your telemetry bucket to `marine` so HaLOS' built-in dashboards and datasource work against your history. If your old system had more than one data bucket, it asks which one is your main telemetry bucket.

When it finishes it prints a summary of what was restored.

## What is migrated, and what is not

| Migrated | Not migrated |
|----------|--------------|
| Signal K configuration and data | Other home-directory files |
| InfluxDB history (all buckets) | System configuration under `/etc` |
| Grafana datasources and dashboards | Docker apps you installed yourself |
| OpenCPN config and plugin data | Charts stored outside `~/.opencpn` |

## After migrating

- **Signal K logging into InfluxDB.** Your telemetry bucket is renamed to `marine`. HaLOS configures the Signal K → InfluxDB plugin for the `marine` bucket automatically, but if your old setup used a custom bucket name, open the Signal K admin UI and confirm the InfluxDB plugin is writing to `marine` so new data continues to be logged.
- **Grafana dashboards.** Your historical data is always available through HaLOS' built-in marine dashboards. Importing your *own* dashboards is best-effort and depends on the Grafana version your OpenPlotter system ran; if they do not appear, recreate them or use the built-in ones.
- **OpenCPN charts.** Charts you stored in a custom folder (outside `~/.opencpn`) are not copied automatically. The backup script warns you about these — copy them to the stick and into place manually.

!!! note "Rolling back"
    Before swapping in your data, the restore script moves the fresh HaLOS defaults aside to `*.halos-default` (for example `…/data/db.halos-default`). If a restore goes wrong, those let you return to the clean state.

## Troubleshooting

- **"Backup is marked incomplete"** — the backup did not finish. Re-run `openplotter-backup.sh` on the source system until it prints `MIGRATION BACKUP COMPLETE AND VERIFIED`.
- **A restore failed partway** — fix the problem it reported and run `halos-restore.sh` again; it re-extracts everything from the stick, and the `*.halos-default` copies from the first run are kept as the rollback state.
- **InfluxDB does not become healthy on restore** — InfluxDB could not open the restored data (a damaged copy, for example). The restore leaves the fresh HaLOS state at `…/data/db.halos-default`. Check `sudo journalctl -u marine-influxdb-container.service -e`.
- **No completion banner and the stick is full** — use a larger stick; the backup needs room for your whole InfluxDB history.

## Data locations

The scripts above handle these paths for you. This section is a reference for anyone moving the data by hand. On OpenPlotter each service keeps its data in the standard location used by its Debian package, so these paths apply equally to most plain Raspberry Pi OS setups that installed Signal K, InfluxDB, Grafana or OpenCPN from apt. On HaLOS the same services run as containers, so their data lives under `/var/lib/container-apps/<app>/data/`.

| Data | OpenPlotter / Raspberry Pi OS | HaLOS |
|------|-------------------------------|-------|
| Signal K | `~/.signalk` | `/var/lib/container-apps/marine-signalk-server-container/data/data` |
| InfluxDB 2 | `/var/lib/influxdb` (bolt at `/var/lib/influxdb/influxd.bolt`, engine at `/var/lib/influxdb/engine`) | `/var/lib/container-apps/marine-influxdb-container/data/db` |
| Grafana | `/var/lib/grafana/grafana.db` | `/var/lib/container-apps/marine-grafana-container/data/data/grafana.db` (re-imported, not copied — see below) |
| OpenCPN | `~/.opencpn`, `~/.local/share/opencpn` | same paths in your HaLOS home directory |

A few details worth knowing:

- **Grafana is re-imported, not copied.** Rather than swapping the SQLite database into place, the restore reads your OpenPlotter `grafana.db` and re-creates its datasources and dashboards through the HaLOS Grafana API. This is why dashboard import is best-effort across Grafana versions.
- **OpenCPN stays in the home directory.** Its config and plugin data restore to the same `~/.opencpn` and `~/.local/share/opencpn` paths on HaLOS.
