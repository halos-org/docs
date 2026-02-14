# Container Metadata

Reference for the `metadata.yaml` format used to define container applications.

## Overview

Every container app has a `metadata.yaml` file that describes the package, its tags, routing, and web UI configuration. The `container-packaging-tools` package reads this file to generate a Debian package.

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Human-readable application name |
| `app_id` | string | Unique identifier (lowercase, hyphens allowed) |
| `version` | string | Package version in `{upstream}-{revision}` format |
| `upstream_version` | string | Upstream application version |
| `description` | string | Short description (one line) |
| `maintainer` | string | Maintainer name and email |
| `license` | string | SPDX license identifier |
| `tags` | list | Debtag faceted classification tags |
| `debian_section` | string | Debian archive section (e.g., `web`, `net`) |
| `architecture` | string | Package architecture (`all`, `arm64`) |

## Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `long_description` | string | -- | Multi-line description for the app store |
| `homepage` | string | -- | Project homepage URL |
| `depends` | list | -- | Debian package dependencies |
| `recommends` | list | -- | Recommended packages |
| `provides` | list | -- | Virtual packages provided |
| `conflicts` | list | -- | Conflicting packages |
| `routing` | object | -- | Traefik routing configuration |
| `web_ui` | object | -- | Web UI configuration |
| `layout` | object | -- | Dashboard layout hints |
| `default_config` | object | -- | Default environment variables |
| `system_bin` | list | -- | System binaries provided |

## Tags

Tags use the [debtag](https://wiki.debian.org/Debtags) faceted classification system:

### Standard Facets

| Facet | Purpose | Examples |
|-------|---------|----------|
| `field::` | Application domain | `field::marine`, `field::core` |
| `role::` | Software type | `role::container-app` |
| `interface::` | UI type | `interface::web`, `interface::cli` |
| `use::` | Primary use case | `use::routing`, `use::monitoring` |
| `works-with::` | Data types handled | `works-with::maps`, `works-with::logfile` |
| `network::` | Network role | `network::server`, `network::client` |
| `scope::` | Application scope | `scope::application`, `scope::utility` |

### Custom HaLOS Facet

| Facet | Purpose | Examples |
|-------|---------|----------|
| `category::` | User-facing store category | `category::navigation`, `category::monitoring` |

### Tagging Guidelines

- Always include `role::container-app`
- Include at least one `field::` tag for store filtering
- Include at least one `category::` tag for store organization
- Multiple `category::` tags are allowed (app appears in each)
- Use standard facets for technical characteristics

## Routing Configuration

The `routing` section configures Traefik reverse proxy integration:

```yaml
routing:
  subdomain: grafana           # Subdomain name (grafana.halos.local)
  auth:
    mode: forward_auth         # Authentication mode
    forward_auth:              # Only for forward_auth mode
      headers:                 # Header remapping (optional)
        Remote-User: X-WEBAUTH-USER
        Remote-Groups: X-WEBAUTH-GROUPS
  host_port: 3000              # Only for host networking apps
```

### Auth Modes

| Mode | Description |
|------|-------------|
| `forward_auth` | Traefik checks authentication with Authelia (default) |
| `oidc` | App handles OIDC flow directly with Authelia |
| `none` | No authentication enforced |

### Subdomain

- Defaults to `app_id` if not specified
- Empty string (`""`) means root domain (used by Homarr)
- Must be unique across all installed apps
- Lowercase alphanumeric with hyphens only

## Web UI Configuration

```yaml
web_ui:
  enabled: true          # Whether the app has a web interface
  port: 3000             # Internal container port
  protocol: http         # http or https
  path: /                # Base path (usually /)
  visible: true          # Show in dashboard and store
```

## Layout Configuration

Dashboard layout hints for the Homarr adapter:

```yaml
layout:
  priority: 40           # Sort order (lower = earlier)
  width: 2               # Tile width (grid units)
  height: 2              # Tile height (grid units)
  x_offset: 0            # Horizontal position
  y_offset: 0            # Vertical position
```

## Default Configuration

Default environment variables for the container:

```yaml
default_config:
  MY_APP_PORT: "8080"
  MY_APP_DEBUG: "false"
  TZ: "${TZ:-UTC}"
```

Variables referencing `${HALOS_DOMAIN}` or `${TZ}` are expanded at runtime.

## Complete Example

```yaml
name: Signal K Server
app_id: signalk-server
version: 2.21.2-2
upstream_version: 2.21.2
description: Signal K server for marine data processing and routing
long_description: |
  Signal K is a modern and open data format for marine use. A Signal K server
  provides a central hub for collecting, processing, and distributing marine
  data from multiple sources including NMEA 0183, NMEA 2000, and other sensors.

homepage: https://signalk.org/
maintainer: Hat Labs <support@hatlabs.fi>
license: Apache-2.0

tags:
  - role::container-app
  - field::marine
  - category::communication
  - category::monitoring
  - interface::web
  - use::routing
  - network::server

debian_section: net
architecture: all

depends:
  - docker.io (>= 20.10) | docker-ce (>= 20.10)
  - python3-bcrypt

web_ui:
  enabled: true
  path: /
  port: 3000
  protocol: http
  visible: true

layout:
  priority: 40
  width: 2
  height: 2

routing:
  subdomain: signalk
  auth:
    mode: none
  host_port: 3000

default_config:
  SIGNALK_PORT: "3000"
  SIGNALK_OIDC_ENABLED: "true"
  SIGNALK_OIDC_ISSUER: "https://auth.${HALOS_DOMAIN}"
  SIGNALK_OIDC_CLIENT_ID: "signalk"
```
