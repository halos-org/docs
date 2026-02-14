# Cockpit Modules

HaLOS extends Cockpit with custom modules for container app management, package management, and user administration.

## Standard Cockpit Modules

These modules ship with Cockpit and are available in all HaLOS installations:

| Module | Sidebar Name | Purpose |
|--------|-------------|---------|
| Overview | Overview | System resource monitoring (CPU, memory, disk, network) |
| Terminal | Terminal | Browser-based command line |
| Services | Services | systemd service management (start, stop, restart) |
| Logs | Logs | journald log viewer with filtering |
| Users | Users | User account management, password changes |
| Networking | Networking | NetworkManager configuration (WiFi, Ethernet, static IP) |
| Storage | Storage | Disk and filesystem management |

## cockpit-apt (Packages)

APT package manager interface for Cockpit. Appears as **Packages** in the sidebar.

| Property | Value |
|----------|-------|
| Repository | [cockpit-apt](https://github.com/halos-org/cockpit-apt) |
| Sidebar name | Packages |
| Tech stack | Python backend + React/TypeScript frontend |

### Features

- Browse packages by Debian section
- Search packages by name or description
- View package details (version, dependencies, description)
- Install and remove packages
- Custom store views with tag-based filtering

### Architecture

Three-tier design:

1. **Backend**: Python CLI using `python-apt`, communicates via JSON
2. **API Layer**: TypeScript wrapper around `cockpit.spawn` calls
3. **UI Layer**: React + PatternFly components

## cockpit-container-apps (Container Apps)

Container app store interface. Appears as **Container Apps** in the sidebar.

| Property | Value |
|----------|-------|
| Repository | [cockpit-container-apps](https://github.com/halos-org/cockpit-container-apps) |
| Sidebar name | Container Apps |

### Features

- Browse container apps by category
- View app details with icons and descriptions
- One-click install and removal
- Store filtering (e.g., Marine store shows only marine apps)
- Category-based organization using debtag facets

### Relationship to cockpit-apt

cockpit-container-apps shares vendored utilities from cockpit-apt. It provides a curated, visual interface specifically for container applications, while cockpit-apt handles general Debian packages.

## cockpit-dockermanager-debian

Docker container manager for Cockpit.

| Property | Value |
|----------|-------|
| Repository | [cockpit-dockermanager-debian](https://github.com/halos-org/cockpit-dockermanager-debian) |

### Features

- View running Docker containers
- Start, stop, and restart containers
- View container logs
- Inspect container details (ports, volumes, environment)

## cockpit-authelia-users

Authelia user management module for Cockpit.

| Property | Value |
|----------|-------|
| Repository | [cockpit-authelia-users](https://github.com/halos-org/cockpit-authelia-users) |

### Features

- Manage Authelia SSO users
- Add and remove users
- Change user passwords
- Manage group memberships

### Relationship to System Users

This module manages Authelia users (for SSO/web app authentication), which are separate from Linux system users (managed by the standard Cockpit Users module).

## halos-cockpit-config

Cockpit branding and configuration for HaLOS.

| Property | Value |
|----------|-------|
| Repository | [halos-cockpit-config](https://github.com/halos-org/halos-cockpit-config) |

### Purpose

Configures Cockpit for the HaLOS environment:

- Custom branding (logo, colors)
- Default module visibility and ordering
- System-level Cockpit configuration

## Accessing Cockpit

Cockpit is always accessible at `https://halos.local:9090/` using Linux system credentials (`pi`/`halos` by default).

It is also accessible via `https://cockpit.halos.local` through Traefik, which requires Authelia SSO authentication.
