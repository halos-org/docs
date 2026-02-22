# App Data and Migration

Every container app in HaLOS stores its persistent data on the host filesystem in a predictable location. This page explains where that data lives and how to migrate or back it up.

## Where app data is stored

All container apps store data under:

```
/var/lib/container-apps/<package-name>/data/
```

Each app gets its own isolated directory. Data persists across container restarts and app updates. Removing an app with `apt remove` preserves the data; `apt purge` deletes it.

### Finding an app's data path

The package name determines the path. For any installed container app:

```bash
# List all container app data directories
ls /var/lib/container-apps/
```

For example, a CasaOS app like Uptime Kuma would store data at `/var/lib/container-apps/casaos-uptimekuma-container/data/`.

### Data paths for marine apps

| App | Package | Host path | Container path |
|-----|---------|-----------|----------------|
| Signal K | `marine-signalk-server-container` | `.../data/data/` | `/home/node/.signalk` |
| InfluxDB | `marine-influxdb-container` | `.../data/config/` | `/etc/influxdb2` |
| | | `.../data/db/` | `/var/lib/influxdb2` |
| Grafana | `marine-grafana-container` | `.../data/data/` | `/var/lib/grafana` |
| AvNav | `marine-avnav-container` | `.../data/data/` | `/var/lib/avnav` |
| OpenCPN | `marine-opencpn-container` | `.../data/config/` | `/config` |

All paths above are relative to `/var/lib/container-apps/<package-name>/`. For example, Signal K data lives at `/var/lib/container-apps/marine-signalk-server-container/data/data/`.

### Data paths for core containers

| Component | Host path | Contents |
|-----------|-----------|----------|
| Authelia | `.../data/authelia/` | `users_database.yml`, OIDC config, session data |
| Homarr | `.../data/homarr/data/` | Dashboard boards, settings |
| Traefik | `.../data/traefik/certs/` | TLS certificates, ACME data (`acme.json`) |

All paths above are relative to `/var/lib/container-apps/halos-core-containers/`.

## Migrating data from another system

The general procedure for migrating any app's data to HaLOS:

1. Install the app on HaLOS (so the directory structure and systemd service exist).
2. Stop the app's service.
3. Copy your data files to the correct host path.
4. Fix file ownership if needed (some containers run as non-root users).
5. Start the service.

!!! warning
    Always stop the container before copying data. Writing to the data directory while the container is running can corrupt data.

```bash
# General pattern
sudo systemctl stop <package-name>
scp -r user@old-system:/path/to/app/data/* /tmp/app-migration/
sudo cp -a /tmp/app-migration/* /var/lib/container-apps/<package-name>/data/<subdir>/
sudo chown -R <uid>:<gid> /var/lib/container-apps/<package-name>/data/<subdir>/
sudo systemctl start <package-name>
```

The container's UID/GID can be found in its `docker-compose.yml` and `prestart.sh`. Look for the `user:` field in the compose file or `chown` commands in `prestart.sh`.

For step-by-step migration guides for marine apps (Signal K, InfluxDB, Grafana, AvNav), see [Marine Apps — Migrating from an existing system](marine-apps.md#migrating-from-an-existing-system).

## Backing up app data

The simplest backup approach is to copy the container data directory:

```bash
# Back up all app data
sudo tar czf halos-app-data-$(date +%Y%m%d).tar.gz \
  /var/lib/container-apps/

# Back up a single app
sudo tar czf signalk-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/container-apps/marine-signalk-server-container/
```

For a consistent backup, stop the app before backing up its data.

### Restoring from backup

!!! warning
    Restoring overwrites the app's existing data. If you need to preserve current data, back it up first.

```bash
# Stop the app
sudo systemctl stop <package-name>

# Restore
sudo tar xzf backup.tar.gz -C /

# Start the app
sudo systemctl start <package-name>
```
