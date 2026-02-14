# Package System

HaLOS packages container applications as standard Debian `.deb` packages. This means Docker apps are installed, updated, and removed with APT -- the same package manager used for all other system software.

## Why Debian Packages?

Packaging containers as `.deb` files provides several advantages over Docker Compose files alone:

- **Single install command**: `sudo apt install marine-grafana-container`
- **Dependency management**: APT resolves dependencies automatically (e.g., Docker)
- **Clean removal**: `apt remove` stops containers and cleans up
- **Automatic updates**: Standard `apt upgrade` workflow
- **System integration**: systemd services, icons, mDNS, dashboard tiles -- all in one package
- **Repository distribution**: Published to `apt.hatlabs.fi` like any APT package

## What's in a Container App Package?

Each container app package contains:

```
/var/lib/container-apps/{app-name}/
├── docker-compose.yml          # Docker Compose definition
├── runtime.env                 # Environment variables
└── icon.png                    # Application icon

/etc/systemd/system/
└── {app-name}-container.service  # systemd service unit

/usr/share/pixmaps/
└── {app-name}.png              # Icon for store and dashboard
```

The systemd service runs `docker compose up -d` on start and `docker compose down` on stop.

## App Definition Format

Developers define container apps using three files:

### metadata.yaml

The central definition file. Contains package metadata, version, tags, routing configuration, and Docker labels.

```yaml
name: Grafana
app_id: grafana
version: 12.3.2-1
upstream_version: 12.3.2
description: Data visualization and monitoring platform
homepage: https://grafana.com/
maintainer: Hat Labs <support@hatlabs.fi>
license: AGPL-3.0

tags:
  - role::container-app
  - field::marine
  - category::visualization
  - category::monitoring
  - interface::web

routing:
  subdomain: grafana
  auth:
    mode: forward_auth

web_ui:
  enabled: true
  port: 3000
  protocol: http
```

See the [Container Metadata Reference](../reference/container-metadata.md) for the full schema.

### docker-compose.yml

Standard Docker Compose file. The `container-packaging-tools` adds Traefik labels, mDNS labels, and Homarr labels automatically based on `metadata.yaml`.

### config.yml (optional)

User-configurable settings that are exposed as environment variables in `runtime.env`.

## container-packaging-tools

The `generate-container-packages` command converts app definitions into Debian packages:

```
apps/grafana/                    generate-container-packages
├── metadata.yaml          ──────────────────────────►     grafana-container_12.3.2-1_all.deb
├── docker-compose.yml
├── config.yml
└── icon.png
```

The tool:

1. Validates the metadata against the schema
2. Generates Traefik routing labels from the `routing` configuration
3. Generates Homarr dashboard labels from the metadata
4. Generates mDNS publisher labels from the subdomain
5. Creates Debian packaging files (control, rules, postinst, prerm, postrm)
6. Builds the `.deb` package with `dpkg-buildpackage`

## Tag-Based Categorization

Packages use a tag-based categorization system with [debtag](https://wiki.debian.org/Debtags) facets. This enables domain-specific stores to organize packages meaningfully.

### Key Facets

| Facet | Purpose | Examples |
|-------|---------|----------|
| `field::` | Application domain | `field::marine`, `field::core` |
| `category::` | User-facing store category | `category::navigation`, `category::monitoring` |
| `role::` | Package type | `role::container-app` |
| `interface::` | UI type | `interface::web` |

### How Store Filtering Works

1. A store configuration defines filter rules (e.g., `include_tags: [field::marine]`)
2. The backend filters all packages matching those tags
3. Categories are auto-discovered from `category::*` tags on matched packages
4. The store UI displays packages organized by category

```yaml
# store/marine.yaml
id: marine
name: Marine Navigation & Monitoring
filters:
  include_tags:
    - field::marine
category_metadata:
  - id: navigation
    label: Navigation & Charts
    icon: MapIcon
```

New categories appear automatically when a package uses a new `category::*` tag -- no store configuration update needed.

## APT Repository

Container app packages are published to `apt.hatlabs.fi`:

| Channel | Purpose | Tag format |
|---------|---------|-----------|
| `trixie-stable` | Production releases | `v{version}+{N}` |
| `trixie-unstable` | Pre-release testing | `v{version}+{N}_pre` |

The CI/CD pipeline builds packages on push to main, publishes to unstable, and promotes to stable when a GitHub release is published.

## Install Lifecycle

### Installation

```
apt install marine-grafana-container
  → dpkg extracts files
  → postinst creates data directories, generates secrets
  → systemd starts grafana-container.service
    → docker compose up -d
      → Traefik detects labels, creates route
      → mDNS publisher advertises grafana.halos.local
      → Homarr adapter adds dashboard tile
```

### Removal

```
apt remove marine-grafana-container
  → prerm stops grafana-container.service
    → docker compose down
      → Traefik removes route
      → mDNS publisher removes advertisement
      → Homarr adapter detects removal
  → dpkg removes package files
```

### Updates

```
apt upgrade
  → dpkg extracts updated files
  → systemd restarts the service
    → docker compose pulls new image and recreates container
  → Persistent data in /var/lib/container-apps/{app}/ is preserved
```

## Version Management

Container app packages use a two-part version scheme:

- **Upstream version**: The application version (e.g., `12.3.2`)
- **Revision**: Auto-incremented by CI (e.g., `-1`, `-2`)

The full Debian version is `{upstream}-{revision}` (e.g., `12.3.2-1`). Revisions increment automatically on each CI build, even if the upstream version hasn't changed.
