# Dashboard Integration

Homarr provides the main landing page for HaLOS at `https://halos.local/`. It displays tiles for all installed applications, giving users a single place to access everything.

## Components

The dashboard system consists of three packages:

| Package | Type | Role |
|---------|------|------|
| `homarr-container` | Docker container | The Homarr dashboard application |
| `homarr-container-adapter` | Native Rust binary | First-boot setup and container auto-discovery |
| `halos-homarr-branding` | Static assets | HaLOS logos, theme colors, default credentials |

## Container Auto-Discovery

The `homarr-container-adapter` runs as a systemd timer (every 60 seconds) and automatically discovers installed container apps:

1. Queries the Docker API for all running containers
2. Reads `homarr.*` labels from each container
3. Compares with the current Homarr dashboard state
4. Adds new apps as tiles, skips apps the user has manually removed
5. Saves state to `/var/lib/homarr-container-adapter/state.json`

### Docker Labels

Container apps declare their dashboard presence via Docker labels:

```yaml
labels:
  # Required
  - "homarr.enable=true"
  - "homarr.name=Signal K Server"
  - "homarr.url=https://signalk.${HALOS_DOMAIN}"

  # Optional
  - "homarr.description=Marine data processing and routing"
  - "homarr.icon=/icons/signalk.png"
  - "homarr.category=Marine"
```

These labels are generated automatically by `container-packaging-tools` from the app's `metadata.yaml`.

### Removed App Tracking

When a user removes an app tile from the Homarr dashboard:

1. The adapter detects the tile is missing on next sync
2. The app is added to the `removed_apps` list in the state file
3. The adapter will not re-add the tile, even after restarts

Users can always re-add apps manually through the Homarr UI.

## First-Boot Setup

On first boot, the adapter performs initial Homarr configuration:

1. **Completes onboarding** -- Steps through Homarr's setup wizard via its API
2. **Creates admin user** -- Username and password from branding config (default: `admin`/`halos`)
3. **Configures settings** -- Disables analytics, sets search engine directives
4. **Creates default board** -- Named "HaLOS Dashboard" with a Cockpit tile
5. **Sets home board** -- Makes the dashboard the default landing page
6. **Applies theme** -- Dark mode by default (from branding config)

First-boot detection checks two conditions: the state file shows `first_boot_completed: false` and Homarr has no boards configured.

## Branding

The `halos-homarr-branding` package provides theming configuration at `/etc/halas-homarr-branding/branding.toml`:

```toml
[identity]
product_name = "HaLOS"
logo_path = "/usr/share/halos-homarr-branding/logo.svg"

[theme]
default_mode = "dark"
primary_color = "#1a73e8"
accent_color = "#4285f4"

[credentials]
admin_username = "admin"
admin_password = "halos"
```

This separates HaLOS customization from the upstream Homarr container, making it easy to update Homarr without losing branding.

## User Customization

Users can customize the dashboard through Homarr's built-in UI:

- Add, remove, and reorder app tiles
- Customize app icons and names
- Group apps into categories
- Add widgets (weather, system stats)
- Switch between themes and layouts
- Drag and drop to reorganize

All customizations are preserved across adapter syncs and system updates.

## Homarr API

The adapter communicates with Homarr via its tRPC API using session-based authentication. Key endpoints:

| Operation | Endpoint |
|-----------|----------|
| Create board | `POST /api/trpc/board.createBoard` |
| Save board | `POST /api/trpc/board.saveBoard` |
| Set home board | `POST /api/trpc/board.setHomeBoard` |
| Create app | `POST /api/trpc/app.create` |
| Get all apps | `GET /api/trpc/app.getAll` |
| Init user | `POST /api/trpc/user.initUser` |
| Change color scheme | `POST /api/trpc/user.changeColorScheme` |

The adapter logs in via Homarr's credentials callback to obtain session cookies, which are then used for all subsequent API calls.
