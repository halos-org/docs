# Installing Apps

HaLOS provides a container app store — a curated collection of applications packaged as Debian packages that run as Docker containers. Browse, install, and manage apps through the Cockpit web interface.

![Container Apps Store](../assets/images/cockpit_container_apps.jpg)

## How it works

Each container app is a standard Debian package (`.deb`) that contains:

- A Docker Compose file defining the container(s)
- A systemd service that manages the container lifecycle
- Docker labels for Traefik routing and Homarr dashboard integration

When you install an app, `apt` downloads the package, `systemd` starts the container, Traefik picks up the routing labels, and the app appears on your [dashboard](dashboard.md) — all automatically.

## Browsing the store

1. Open **Cockpit** (via the dashboard tile or `https://halos.local:9090/`).
2. Navigate to **Container Apps** in the left sidebar.
3. Browse by category or use the search bar to find specific apps.

The store shows apps from all configured stores. The Marine variant adds a dedicated [Marine App Store](marine-apps.md) with curated marine applications.

## Installing an app

1. Click on an app to view its details (description, version, dependencies).
2. Click **Install**.
3. Wait for the package to download and the container to start (typically 30–60 seconds).
4. The app appears on your Homarr dashboard and is accessible via its subdomain URL.

## Managing installed apps

**Start/Stop/Restart**: Open Cockpit → Services. Find the service (named `<app-name>-container.service`) and use the controls to start, stop, or restart it.

**View logs**: Open Cockpit → Services → select the service → Logs tab. Or use the terminal:

```bash
sudo journalctl -u <app-name>-container.service -f
```

**Check container status**: Via the Cockpit terminal:

```bash
sudo docker ps
```

## Removing apps

Remove an app like any Debian package:

=== "Via Cockpit Packages panel"

    Open Cockpit → Packages → find the package → Remove.

=== "Via terminal"

    ```bash
    sudo apt remove <app-name>-container
    ```

Removing a package stops the container and removes it from the dashboard. Container data volumes are preserved by default — reinstalling the app restores its data.

To remove data volumes as well:

```bash
sudo apt purge <app-name>-container
```

## Keeping apps updated

Container app packages are updated through the same APT mechanism as system packages:

```bash
sudo apt update && sudo apt upgrade
```

This updates both system packages and container apps to their latest versions.
