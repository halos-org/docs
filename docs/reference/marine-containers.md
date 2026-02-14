# Marine Containers

Reference for the marine container applications available in the Marine App Store.

## Marine App Store

The marine apps are defined in the `halos-marine-containers` repository and distributed via the `marine-container-store` package. The store filters packages by the `field::marine` tag and organizes them into categories.

Install the marine stack with the `halos-marine` metapackage, or install individual apps from the Container Apps store in Cockpit.

## Signal K Server

Marine data server and API hub.

| Property | Value |
|----------|-------|
| Package | `marine-signalk-server-container` |
| URL | `https://signalk.halos.local` |
| Direct port | 3000 (host networking) |
| Auth mode | `none` (OIDC configured separately) |
| License | Apache-2.0 |

### Description

Signal K provides a central hub for collecting, processing, and distributing marine data. It supports NMEA 0183, NMEA 2000 (via CAN bus on HALPI2), and other sensor inputs. Features a WebSocket API for real-time data streaming, a plugin system, and a built-in web application server.

### Network

Uses host networking (`network_mode: host`) for direct access to USB/serial devices and CAN bus interfaces. Still accessible via Traefik subdomain routing.

### OIDC Integration

Signal K has native OIDC support and authenticates directly with Authelia. Configuration is set via environment variables:

- `SIGNALK_OIDC_ENABLED=true`
- `SIGNALK_OIDC_ISSUER=https://auth.${HALOS_DOMAIN}`
- `SIGNALK_OIDC_AUTO_LOGIN=true`

## InfluxDB

Time-series database for marine data logging.

| Property | Value |
|----------|-------|
| Package | `marine-influxdb-container` |
| URL | `https://influxdb.halos.local` |
| Auth mode | `none` |
| License | MIT |

### Description

InfluxDB stores timestamped data from Signal K, sensors, and other sources. Provides a built-in web UI for data exploration and supports the Flux query language. Commonly paired with Grafana for visualization.

### Default Configuration

| Variable | Default |
|----------|---------|
| `INFLUXDB_ADMIN_USER` | `admin` |
| `INFLUXDB_ADMIN_PASSWORD` | `halos-default` |
| `INFLUXDB_DB` | `marine` |

!!! warning
    Change the default InfluxDB credentials after first setup.

## Grafana

Data visualization and monitoring platform.

| Property | Value |
|----------|-------|
| Package | `marine-grafana-container` |
| URL | `https://grafana.halos.local` |
| Auth mode | `none` (uses native OAuth with Authelia) |
| License | AGPL-3.0 |

### Description

Grafana creates dashboards to visualize marine data from InfluxDB, Signal K, and other data sources. Supports rich visualization options including graphs, gauges, maps, and alerts. Grafana handles OAuth authentication natively via its prestart script, which registers with Authelia.

### Recommended Packages

- `marine-influxdb-container` -- Data source for Grafana dashboards

## AvNav

Touch-optimized chart plotter for sailing and motor yachts.

| Property | Value |
|----------|-------|
| Package | `marine-avnav-container` |
| URL | `https://avnav.halos.local` |
| Auth mode | `forward_auth` |
| License | GPL-3.0 |

### Description

AvNav is navigation software designed for touch operation on tablets and smartphones. Features include chart plotting (mbtiles, gemf, xml formats), route planning, AIS integration, anchor watch, and NMEA data display. Has a plugin system for extensions.

## OpenCPN

Open source chart plotter and navigation software.

| Property | Value |
|----------|-------|
| Package | `marine-opencpn-container` |
| URL | `https://opencpn.halos.local` |
| Auth mode | `none` |
| License | GPL-2.0 |

### Description

OpenCPN is a full-featured chart plotter supporting raster and vector charts, AIS target tracking, GPS and autopilot integration, weather routing, and an extensive plugin system.

!!! note "Experimental Container"
    The OpenCPN container uses remote desktop streaming (selkies-gstreamer) to provide a web interface for a desktop application. This is experimental and may have performance limitations.

    For a better experience, install OpenCPN natively on Desktop images:

    ```bash
    sudo apt install opencpn
    ```

## Store Configuration

The marine store is defined in `store/marine.yaml`:

```yaml
id: marine
name: Marine Navigation & Monitoring
description: |
  Applications for marine navigation, monitoring, and boat systems.

filters:
  include_origins:
    - "Hat Labs"
  include_tags:
    - field::marine

category_metadata:
  - id: navigation
    label: Navigation & Charts
  - id: chartplotters
    label: Chart Plotters
  - id: monitoring
    label: Data & Monitoring
  - id: communication
    label: Communication
  - id: visualization
    label: Visualization
```

Packages with the `field::marine` tag automatically appear in this store, organized by their `category::*` tags.
