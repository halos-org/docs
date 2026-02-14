# Networking

HaLOS uses NetworkManager for network configuration, with Cockpit providing a web-based interface for managing connections. The mDNS publisher service handles hostname resolution for all services.

## WiFi

Configure WiFi through the Cockpit NetworkManager module:

1. Open Cockpit → Networking.
2. Click on the WiFi interface.
3. Select a network from the list of available networks.
4. Enter the password and connect.

![WiFi Configuration](../assets/images/cockpit_networkmanager_wifi.jpg)

### WiFi on headless images

Headless images have no desktop environment, so WiFi must be configured through Cockpit or the command line. If you don't have Ethernet for initial access, use an [AP image variant](../getting-started/choosing-an-image.md#access-point-variant).

## Access point mode

The AP image variant (`Halos-Desktop-Marine-HALPI2-AP`) creates a WiFi access point on first boot:

- **Network name**: `Halos-XXXX` (XXXX is unique to your device)
- **Password**: `halos1234`

This allows you to connect and configure the device without Ethernet. Once connected to the AP, access the web interface at `https://halos.local/` and configure a regular WiFi connection through Cockpit → Networking.

After configuring a WiFi client connection, the access point is no longer needed for initial setup. Consult NetworkManager documentation for running AP and client mode simultaneously.

## Ethernet

Ethernet works out of the box with DHCP. The device obtains an IP address automatically from your network's DHCP server.

To configure a static IP:

1. Open Cockpit → Networking.
2. Click on the Ethernet interface.
3. Switch from "Automatic (DHCP)" to "Manual".
4. Enter the desired IP address, netmask, gateway, and DNS servers.

## Hostname and mDNS

HaLOS uses mDNS (multicast DNS) for local hostname resolution. The default hostname is `halos`, making the device reachable at `halos.local`.

### How subdomain resolution works

HaLOS services use subdomain URLs like `signalk.halos.local` and `grafana.halos.local`. These are multi-label mDNS names that require special handling:

1. The **`halos-mdns-publisher`** service monitors Docker containers for the `halos.subdomain` label.
2. When a container with `halos.subdomain=signalk` starts, the publisher uses Avahi to advertise `signalk.halos.local` on the network.
3. When the container stops, the mDNS record is removed.

This means subdomain resolution is automatic — install an app, and its subdomain just works on your local network.

!!! info "Multi-label mDNS"
    Standard mDNS only resolves single-label names like `halos.local`. Multi-label names like `signalk.halos.local` require the `mdns4` resolver (instead of the default `mdns4_minimal`) and an `/etc/mdns.allow` configuration. HaLOS configures this automatically via the `halos-mdns-publisher` package.

### Changing the hostname

If you change the device hostname (via Cockpit → Overview or `hostnamectl`), all URLs change accordingly. A device named `myboat` uses:

- `https://myboat.local/` — Dashboard
- `https://signalk.myboat.local/` — Signal K
- `https://myboat.local:9090/` — Cockpit direct access

After changing the hostname:

- The old `.local` name stops resolving. Update your bookmarks.
- TLS certificates are regenerated on next service restart to cover the new hostname.
- mDNS advertisements update automatically.

## Troubleshooting network issues

**mDNS not resolving**: Some networks or client devices have issues with `.local` resolution. Try accessing by IP address instead. Check your router's DHCP client list for the device's IP.

**WiFi won't connect**: Verify credentials through Cockpit NetworkManager. Check Cockpit → Logs for NetworkManager entries. As a fallback, use Ethernet and configure WiFi from the wired connection.

**Subdomains not resolving**: Verify the `halos-mdns-publisher` service is running:

```bash
sudo systemctl status halos-mdns-publisher
```

Check its logs for errors:

```bash
sudo journalctl -u halos-mdns-publisher -f
```
