# mDNS Publisher

The `halos-mdns-publisher` is a native systemd service that advertises container subdomain hostnames via mDNS, and configures the system to resolve multi-label mDNS names.

## Overview

When a container app is installed with a subdomain (e.g., `grafana`), the mDNS publisher automatically advertises `grafana.halos.local` on the local network via Avahi. This enables devices on the same network to resolve the subdomain without any DNS configuration.

## How It Works

1. On startup, scans all running Docker containers for `halos.subdomain` labels
2. Monitors Docker events for container start/stop
3. Spawns `avahi-publish-address` subprocesses for each subdomain
4. Cleans up mDNS records when containers stop
5. Periodic health checks restart failed avahi-publish processes

## Container Labels

Add the `halos.subdomain` label to any Docker container to advertise its subdomain:

```yaml
services:
  my-app:
    image: example/my-app:latest
    labels:
      - "halos.subdomain=myapp"    # Advertises myapp.halos.local
```

The publisher resolves the subdomain to the host's IP address.

## Multi-label mDNS Resolution

By default, Debian's `mdns4_minimal` resolver only handles single-label `.local` names (e.g., `halos.local`). Multi-label names like `grafana.halos.local` require additional configuration.

The `halos-mdns-publisher` package configures this automatically by:

1. Installing `/etc/mdns.allow` to permit resolution of all `.local` names
2. Updating `/etc/nsswitch.conf` to use `mdns4` instead of `mdns4_minimal`

These changes are reverted when the package is purged.

## Service Management

```bash
# Check status
sudo systemctl status halos-mdns-publisher

# View logs
sudo journalctl -u halos-mdns-publisher -f

# Restart service
sudo systemctl restart halos-mdns-publisher
```

## Command Line Options

```
Usage: halos-mdns-publisher [OPTIONS]

Options:
  -s, --socket <SOCKET>    Docker socket path [default: /var/run/docker.sock]
  -d, --debug              Enable debug logging
      --health-interval     Health check interval in seconds [default: 60]
  -h, --help               Print help
  -V, --version            Print version
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `avahi-daemon` | mDNS/DNS-SD service discovery daemon |
| `avahi-utils` | Provides `avahi-publish-address` command |
| `libnss-mdns` | NSS module for mDNS name resolution |

Docker is recommended but not required at startup -- the publisher waits gracefully for Docker to become available.

## Implementation

- Written in Rust using async I/O (tokio)
- Docker API client: `bollard` crate
- Spawns one `avahi-publish-address --no-reverse` subprocess per subdomain
- Automatic recovery if avahi-publish processes crash
- Logs to journald via systemd

## Troubleshooting

### Subdomain not resolving

1. Check the publisher is running: `systemctl status halos-mdns-publisher`
2. Verify the container has the correct label: `docker inspect <container> | grep halos.subdomain`
3. Check Avahi is running: `systemctl status avahi-daemon`
4. Test mDNS resolution: `avahi-resolve -n grafana.halos.local`

### Resolution works on device but not from other machines

Ensure the client machine supports multi-label mDNS resolution. On Linux, install `libnss-mdns` and configure `/etc/mdns.allow`. On macOS, multi-label mDNS works by default. Windows may require Bonjour or additional configuration.
