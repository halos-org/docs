# System Management

[Cockpit](https://cockpit-project.org/) is the system administration interface for HaLOS. It provides a web-based control panel for managing packages, services, networking, storage, and users.

![Cockpit Overview](../assets/images/cockpit_default_screen.jpg)

## Accessing Cockpit

There are two ways to reach Cockpit:

| Method | URL | Authentication |
|--------|-----|----------------|
| Via reverse proxy | `https://cockpit.halos.local/` | Authelia SSO |
| Direct access | `https://halos.local:9090/` | System credentials (`pi` / `halos`) |

Direct access on port 9090 is always available, even if Traefik or Authelia are down. Use it as a fallback for troubleshooting.

## Available modules

### Overview

System resource monitoring: CPU usage, memory, disk space, and network activity. Shows system information (hostname, OS version, uptime).

### Packages

Install and manage Debian packages via APT.

Use this panel — or run `sudo apt update && sudo apt upgrade` in the terminal — to keep your system up to date.

### Terminal

A full command-line terminal in the browser. Useful for running commands without SSH.

### Services

View and manage systemd services. You can start, stop, restart, and enable/disable services. Container apps run as systemd services (e.g., `signalk-server-container.service`), so you can manage them here.

### Logs

Browse and filter system logs from `journald`. Filter by service, priority, or time range to find relevant entries.

### Users

Manage Linux system user accounts. This is where you should **change the default `pi` password** after first boot.

<!-- TODO: screenshot of Cockpit Users panel -->

### Container Apps

Browse and install containerized applications from the HaLOS app store. This is a separate module from the Packages panel — see [Installing Apps](installing-apps.md) for the full workflow.

### Networking

Configure network interfaces via NetworkManager. See [Networking](networking.md) for details on WiFi, Ethernet, and hostname configuration.

## System updates

Keep your system current by running updates regularly:

=== "Via Cockpit Packages panel"

    Open Cockpit → Packages → Check for updates → Apply.

=== "Via Cockpit Terminal"

    ```bash
    sudo apt update && sudo apt upgrade
    ```

!!! tip "First update after install"
    Run a system update immediately after first boot. This ensures the container app store has the latest package lists.

## Storage

Cockpit shows disk usage and partition information. For Raspberry Pi setups, storage is typically:

- **SD card or SSD**: Main storage with the OS and all data
- **USB drives**: Optional additional storage, mountable through Cockpit
