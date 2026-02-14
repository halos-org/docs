# Core Containers

The core containers provide the foundational web infrastructure for HaLOS. They are pre-installed in all HaLOS images and managed as a single unit by the `halos-core-containers` package.

## Overview

| Container | Image | Purpose |
|-----------|-------|---------|
| **Traefik** | `traefik:v3.6` | Reverse proxy, TLS termination, routing |
| **Authelia** | `authelia/authelia:4.39` | SSO identity provider (ForwardAuth + OIDC) |
| **Authelia Valkey** | `valkey/valkey:9.0-alpine` | Session cache for Authelia |
| **Homarr** | `ghcr.io/homarr-labs/homarr:v1.51` | Dashboard landing page |

All containers are managed by a single systemd service: `halos-core-containers.service`.

## Traefik

### Purpose

Reverse proxy that receives all incoming HTTP/HTTPS traffic and routes it to the appropriate application based on the `Host` header.

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 80 | HTTP | Redirects to HTTPS |
| 443 | HTTPS | All application traffic |

### Configuration

| Path | Purpose |
|------|---------|
| `/var/lib/container-apps/halos-core-containers/assets/traefik/traefik.yml` | Static configuration |
| `/etc/halos/traefik-dynamic.d/` | Dynamic middleware directory (apps drop files here) |
| `/var/lib/container-apps/halos-core-containers/traefik/certs/` | TLS certificates |

### Docker Network

Traefik creates and owns `halos-proxy-network`. All proxied containers must join this network.

### Key Labels

Traefik discovers routes from Docker container labels. See [Reverse Proxy](../architecture/reverse-proxy.md) for the label format.

## Authelia

### Purpose

Identity provider that authenticates users and provides SSO across all HaLOS web applications.

### Access

- URL: `https://auth.halos.local`
- No direct port exposure -- accessed through Traefik

### Authentication Methods

- **ForwardAuth**: Default for most apps. Traefik checks each request with Authelia.
- **OIDC**: For apps with native OpenID Connect support (Homarr, Signal K).

### Configuration

| Path | Purpose |
|------|---------|
| `/var/lib/container-apps/halos-core-containers/authelia/configuration.yml` | Base configuration (regenerated on restart) |
| `/var/lib/container-apps/halos-core-containers/authelia/oidc-clients.yml` | Merged OIDC client definitions |
| `/var/lib/container-apps/halos-core-containers/authelia/users_database.yml` | User credentials (argon2id hashes) |
| `/etc/halos/oidc-clients.d/` | OIDC client snippets (per-app) |

### User Database

File-based user storage. Default admin user: `admin`/`halos`.

See [Single Sign-On](../architecture/sso.md) for details on authentication modes and OIDC client registration.

## Authelia Valkey

### Purpose

Redis-compatible in-memory cache for Authelia session data. Uses Valkey (open-source Redis fork).

### Configuration

- Data persisted to `/var/lib/container-apps/halos-core-containers/authelia/valkey/`
- Append-only file (AOF) enabled for durability
- Connected to Authelia via an internal-only Docker network

## Homarr

### Purpose

Dashboard application that serves as the main landing page at `https://halos.local/`.

### Access

- URL: `https://halos.local` (root domain via Traefik)
- Internal port: 7575 (localhost only, for `homarr-container-adapter`)

### Configuration

| Path | Purpose |
|------|---------|
| `/var/lib/container-apps/halos-core-containers/homarr/data/` | Persistent Homarr data (boards, settings) |
| `/etc/halas-homarr-branding/branding.toml` | HaLOS theming (from `halos-homarr-branding` package) |

### SSO Integration

Homarr uses OIDC authentication with Authelia. Auto-login is enabled -- users are redirected to Authelia automatically and returned to the dashboard after authentication.

### Related Packages

| Package | Purpose |
|---------|---------|
| `homarr-container-adapter` | First-boot setup and container auto-discovery |
| `halos-homarr-branding` | HaLOS logos, theme colors, default credentials |

See [Dashboard Integration](../architecture/dashboard.md) for the auto-discovery mechanism.

## Service Management

```bash
# Check status
sudo systemctl status halos-core-containers

# View logs
sudo journalctl -u halos-core-containers -f

# Restart all core containers
sudo systemctl restart halos-core-containers

# Check individual container status
sudo docker ps --filter "name=traefik" --filter "name=authelia" --filter "name=homarr"
```

## System Binaries

The core containers package provides system binaries that other container packages use:

| Binary | Purpose |
|--------|---------|
| `configure-container-routing` | Sets up Traefik routing for an app |
| `reload-oidc-clients` | Regenerates merged OIDC client configuration |
