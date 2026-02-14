# Marine Apps

The Marine variant of HaLOS includes a curated Marine App Store with applications for boat electronics, navigation, and data logging. These apps integrate with NMEA 2000, NMEA 0183, and other marine data protocols.

## Overview

Install HaLOS with the **Marine** stack (see [Choosing an Image](../getting-started/choosing-an-image.md)) to get the Marine App Store. It appears alongside the standard container store in Cockpit and includes applications specifically selected for marine use.

Key marine apps available in the store:

- **Signal K Server** — Marine data hub for NMEA 2000 and NMEA 0183
- **InfluxDB** — Time-series database for logging sensor data
- **Grafana** — Dashboards and data visualization
- **AvNav** — Navigation and chart plotting
- **OpenCPN** — Full-featured chart plotter (desktop app, also available as an experimental container)

## Signal K Server

**URL**: `https://signalk.halos.local/`

[Signal K](https://signalk.org/) is an open-source marine data server. It acts as a central hub for all your boat's sensor data:

- Receives data from NMEA 2000 and NMEA 0183 networks
- Provides a unified REST and WebSocket API
- Feeds data to other applications (Grafana, AvNav, OpenCPN)
- Extensible with plugins for additional data sources and integrations

Signal K is typically the first marine app to set up. Connect your NMEA data sources (via CAN bus on HALPI2, USB adapters, or network connections), and other apps can consume the data through Signal K's API.

![Signal K Dashboard](../assets/images/signalk_dashboard.jpg)

## InfluxDB

**URL**: `https://influxdb.halos.local/`

[InfluxDB](https://www.influxdata.com/) is a time-series database optimized for sensor data. In the marine context, it stores historical data from Signal K — wind speed, boat speed, depth, engine parameters, battery voltage, and any other metrics your instruments produce.

Use InfluxDB to:

- Record long-term trends (fuel consumption over a season, battery health)
- Store data for Grafana dashboards
- Query historical data for analysis

## Grafana

**URL**: `https://grafana.halos.local/`

[Grafana](https://grafana.com/) provides dashboards and data visualization. Connect it to InfluxDB to create custom displays for your boat data:

- Real-time gauges (speed, wind, depth)
- Historical charts (engine hours, battery voltage over time)
- Alerts (low battery, high engine temperature)
- Custom dashboards tailored to your instruments

<!-- TODO: screenshot of a Grafana marine dashboard -->

## AvNav

**URL**: `https://avnav.halos.local/`

[AvNav](https://www.wellenvogel.net/software/avnav/docs/beschreibung.html) is a navigation application with chart display and route planning. It reads position and instrument data from Signal K and provides:

- Chart display with multiple chart formats
- Route planning and waypoint management
- Instrument displays (heading, speed, wind, depth)
- Anchor watch alarm

![AvNav Chart Plotter](../assets/images/avnav.jpg)

## OpenCPN

[OpenCPN](https://opencpn.org/) is a full-featured chart plotter and navigation system with worldwide chart support, AIS display, weather routing, and a large plugin ecosystem.

OpenCPN is primarily a desktop application. On HaLOS Desktop images, install it natively for the best experience:

```bash
sudo apt install opencpn
```

Or install it via Cockpit → Packages.

!!! note "Experimental container"
    An experimental containerized version is available in the Marine App Store (`https://opencpn.halos.local/`), providing web-based remote desktop access. This is useful on headless images but is not yet production-ready.

## Installing marine apps

Marine apps are installed the same way as any other container app:

1. Open Cockpit → Container Apps.
2. Browse the Marine App Store category or search by name.
3. Click an app and select Install.

See [Installing Apps](installing-apps.md) for the full workflow.

## Data flow

A typical marine setup chains the applications together:

1. **NMEA instruments** send data via CAN bus (NMEA 2000) or serial (NMEA 0183)
2. **Signal K** receives and normalizes the data
3. **InfluxDB** stores historical records (fed by a Signal K plugin)
4. **Grafana** visualizes the data from InfluxDB
5. **AvNav** displays navigation data from Signal K
