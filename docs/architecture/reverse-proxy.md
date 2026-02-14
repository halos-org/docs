# Reverse Proxy

Traefik serves as the central entry point for all HaLOS web traffic, providing subdomain-based routing, TLS termination, and authentication enforcement.

## Why a Reverse Proxy?

Without Traefik, each application would be accessed by IP address and port number (e.g., `http://192.168.1.50:3000`). With Traefik:

- Applications get clean subdomain URLs (`https://grafana.halos.local`)
- All traffic is encrypted with HTTPS
- Authentication is enforced centrally
- No port conflicts between applications
- Only ports 80 and 443 are exposed to the network

## Routing

Traefik uses Docker labels to discover and route to applications automatically. When a container starts with the appropriate labels, Traefik creates a route for it -- no configuration files to edit.

### Subdomain Scheme

Every application gets a subdomain of the device hostname:

| URL | Application |
|-----|-------------|
| `halos.local` | Homarr dashboard (root domain) |
| `auth.halos.local` | Authelia login portal |
| `grafana.halos.local` | Grafana |
| `signalk.halos.local` | Signal K Server |
| `influxdb.halos.local` | InfluxDB |
| `avnav.halos.local` | AvNav |
| `cockpit.halos.local` | Cockpit web console |

Path-based routing (e.g., `halos.local/grafana`) is not supported. All apps use subdomains exclusively.

### Docker Labels

Applications declare their routing via Docker labels in their `docker-compose.yml`:

```yaml
services:
  grafana:
    image: grafana/grafana:latest
    labels:
      # Enable Traefik routing
      - "traefik.enable=true"

      # HTTP router (redirects to HTTPS)
      - "traefik.http.routers.grafana.rule=Host(`grafana.${HALOS_DOMAIN}`)"
      - "traefik.http.routers.grafana.entrypoints=web"
      - "traefik.http.routers.grafana.middlewares=redirect-to-https@file"

      # HTTPS router with authentication
      - "traefik.http.routers.grafana-secure.rule=Host(`grafana.${HALOS_DOMAIN}`)"
      - "traefik.http.routers.grafana-secure.entrypoints=websecure"
      - "traefik.http.routers.grafana-secure.tls=true"
      - "traefik.http.routers.grafana-secure.middlewares=authelia@file"

      # Backend service port
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"

      # mDNS subdomain advertisement
      - "halos.subdomain=grafana"
    networks:
      - halos-proxy-network
```

The `HALOS_DOMAIN` environment variable is set to the device hostname (e.g., `halos.local`), making the configuration portable across hostname changes.

## TLS / HTTPS

### Self-Signed Certificates

HaLOS generates a self-signed wildcard certificate on first boot:

- Covers `halos.local` and `*.halos.local`
- Valid for 365 days
- Browsers show a certificate warning on first access to each subdomain

The wildcard SAN (`*.halos.local`) means a single certificate covers all subdomain URLs.

### Let's Encrypt

Let's Encrypt is not supported for `.local` mDNS domains, as certificate authorities require publicly resolvable domain names. This may be added in the future for users with public domain names.

## Network Architecture

### Shared Docker Network

All proxied containers join a shared bridge network called `halos-proxy-network`:

```
halos-proxy-network (bridge)
├── traefik (owner)
├── authelia
├── homarr
├── grafana-container
├── influxdb-container
└── ... other container apps
```

Traefik can route to any container on this network by its service name and port.

### Host Networking

Some applications require host networking for hardware access (e.g., Signal K needs USB/serial devices). These apps use `network_mode: host` and are reached by Traefik via `host.docker.internal`:

```yaml
services:
  signalk:
    network_mode: host
    labels:
      - "traefik.http.services.signalk.loadbalancer.server.port=3000"
```

Host networking apps are accessible both via their subdomain URL and their direct port.

### Port Exposure Policy

By default, container apps should **not** expose ports directly. All HTTP access goes through Traefik. Exceptions are allowed for:

- **Non-HTTP protocols**: NMEA TCP streams, CAN bus data
- **Host networking**: Required for hardware access (USB, serial)
- **External tool compatibility**: When third-party tools require specific ports

## Traefik Configuration

### Entry Points

| Entry Point | Port | Purpose |
|-------------|------|---------|
| `web` | 80 | HTTP (redirects to HTTPS) |
| `websecure` | 443 | HTTPS |

### Providers

- **Docker provider**: Watches for container labels, creates routes automatically
- **File provider**: Loads static middleware definitions (Authelia ForwardAuth, per-app customizations)

### Authentication Middleware

The default Authelia ForwardAuth middleware is defined as a file provider configuration:

```yaml
http:
  middlewares:
    authelia:
      forwardAuth:
        address: "http://authelia:9091/api/authz/forward-auth"
        trustForwardHeader: true
        authResponseHeaders:
          - Remote-User
          - Remote-Groups
          - Remote-Email
          - Remote-Name
```

Applications reference this middleware in their Traefik labels to enable authentication. OIDC apps and no-auth apps omit the middleware reference.

## Cockpit Integration

Cockpit runs on port 9090 with its own TLS certificate, independent of Traefik. It is also accessible via `cockpit.halos.local` through Traefik for users who prefer subdomain access.

Cockpit serves as a fallback if Traefik is down -- it's always directly accessible at `https://halos.local:9090/`.
