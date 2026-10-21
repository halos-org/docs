# App Data and Migration

Every container app in HaLOS stores its persistent data on the host filesystem in a predictable location. This page explains where that data lives, how to migrate or back it up, and how to customise an app's Compose settings.

## Where app data is stored

All container apps store data under:

```
/var/lib/container-apps/<package-name>/data/
```

Each app gets its own isolated directory. Data persists across container restarts and app updates. Removing an app with `apt remove` or `apt purge` preserves the data. `apt purge` deletes only the app's configuration in `/etc/container-apps/<package-name>/`; for a clean reinstall, delete `/var/lib/container-apps/<package-name>/` by hand after purging.

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

## Customising an app with compose.d

Each container app is defined by a `docker-compose.yml` in `/var/lib/container-apps/<package-name>/`. Do not edit that file: the next package upgrade overwrites it. To change an app's Compose settings, put your own Compose file in the app's `compose.d/` directory:

```
/var/lib/container-apps/<package-name>/compose.d/
```

Files ending in `.yml` or `.yaml` are applied in byte order of filename, after `docker-compose.yml` and, for apps with a web address, after the generated routing labels. A file in `compose.d/` can therefore override any setting of the app. Package upgrades and `apt purge` leave these files in place.

The files merge with the app's definition by Docker Compose's [merge rules](https://docs.docker.com/reference/compose-file/merge/). Lists such as `group_add` add to the existing entries. To clear a setting, tag it with `!reset`; to replace it entirely, tag it with `!override`. HaLOS ships Compose 2.26, which supports both.

### Example: adding a supplementary group

To give the process in one of the app's services an extra group, create for example `compose.d/10-groups.yml`:

```yaml
services:
  <service>:
    group_add:
      - "<gid>"
```

`<service>` is the service name from the app's `docker-compose.yml`. Use the numeric group ID from the host (`getent group <group>` shows it); a group name is looked up inside the container, where it may not exist.

Relative paths in a `compose.d/` file resolve against the app directory, `/var/lib/container-apps/<package-name>/`. A top-level `name:` in a `compose.d/` file has no effect, because the service sets the project name itself.

### Applying the change

Changes take effect when the app restarts. Check the result first, then restart:

```bash
sudo /var/lib/container-apps/<package-name>/compose check
sudo systemctl restart <package-name>
```

`compose check` validates the app's Compose configuration with the same environment the service uses, and lists the active `compose.d/` files. Part of that environment is generated when the service starts, so run the check while the app is running or after it has started at least once since boot. It needs `sudo` because the app's `runtime.env` is readable only by root.

If a `compose.d/` file makes the configuration invalid, the app does not start. See [App fails to start after adding a compose.d file](troubleshooting.md#app-fails-to-start-after-adding-a-composed-file).
