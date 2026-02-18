# Adding Apps

This guide covers creating a new container application for HaLOS.

## The Quick Way: Ask Claude

If you're working with Claude Code from the `halos-distro` workspace (see [Workspace Setup](workspace-setup.md)), adding an app is a conversation:

> *"Add a new marine container app called yacht-radar. It uses the image `example/yacht-radar:2.1.0`, has a web UI on port 8080, and should use forward auth. Put it in the navigation category."*

Claude reads the existing apps in `halos-marine-containers/apps/`, follows the established patterns, and produces the complete set of files: `metadata.yaml`, `docker-compose.yml`, icon, and configuration. It handles the conventions documented below -- auth modes, Traefik labels, tag taxonomy, volume paths -- without you needing to look them up.

This works because the workspace has rich context: every existing app serves as an example, and each repository's `AGENTS.md` documents the conventions. The rest of this page documents those conventions for reference.

## App Structure

Each app lives in a directory under `apps/` in either `halos-core-containers` (pre-installed) or `halos-marine-containers` (store apps):

```
apps/my-app/
├── metadata.yaml        # Package metadata, tags, routing
├── docker-compose.yml   # Docker service definition
├── config.yml           # User-configurable settings (optional)
├── prestart.sh          # Pre-start script (optional)
└── icon.png             # Application icon (256x256, PNG)
```

## Step 1: Create metadata.yaml

The metadata file defines everything about the package:

```yaml
name: My App
app_id: my-app
version: 1.0.0-1
upstream_version: 1.0.0
description: Short description of the application
long_description: |
  Longer description with details about features
  and capabilities. Shown in the app store.

homepage: https://example.com/
maintainer: Hat Labs <support@hatlabs.fi>
license: MIT

tags:
  # Domain (required for store filtering)
  - role::container-app
  - field::marine

  # User-facing categories
  - category::monitoring

  # Technical characteristics
  - interface::web

debian_section: web
architecture: all

depends:
  - docker.io (>= 20.10) | docker-ce (>= 20.10)

routing:
  subdomain: my-app
  auth:
    mode: forward_auth    # or: oidc, none

web_ui:
  enabled: true
  port: 8080
  protocol: http
```

### Authentication Modes

Choose the appropriate auth mode in `routing.auth.mode`:

| Mode | When to use |
|------|------------|
| `forward_auth` | Default. App has no SSO support. Traefik handles auth transparently. |
| `oidc` | App has native OIDC support (e.g., Grafana, Homarr). |
| `none` | App should be publicly accessible or handles its own auth. |

### Tags

Tags determine where the app appears in the store:

- `field::marine` -- Include in the Marine store
- `category::navigation` -- Appear under "Navigation & Charts" category
- `role::container-app` -- Identifies this as a container app
- `interface::web` -- Has a web UI

See the [Container Metadata Reference](../reference/container-metadata.md) for all available fields.

## Step 2: Create docker-compose.yml

Write a standard Docker Compose file. Do **not** include Traefik, Homarr, or mDNS labels -- these are generated automatically from `metadata.yaml`.

```yaml
services:
  my-app:
    image: example/my-app:${UPSTREAM_VERSION:-1.0.0}
    container_name: my-app
    init: true
    restart: unless-stopped
    env_file:
      - runtime.env
    volumes:
      - ${CONTAINER_DATA_ROOT}/my-app/data:/app/data
    networks:
      - halos-proxy-network
    logging:
      driver: journald
      options:
        tag: "{{.Name}}"

networks:
  halos-proxy-network:
    external: true
```

Key conventions:

- **Init**: Always set `init: true` so Docker uses tini as PID 1 for proper signal handling (graceful shutdown)
- **Restart policy**: Always `unless-stopped`
- **Logging**: Use `journald` driver so logs are accessible via Cockpit
- **Network**: Join `halos-proxy-network` for Traefik routing
- **No port exposure**: Do not add a `ports:` section unless the app needs non-HTTP protocol access
- **Data volumes**: Use `${CONTAINER_DATA_ROOT}` for persistent data

### Host Networking Apps

If the app needs hardware access (USB, serial, CAN bus):

```yaml
services:
  my-app:
    image: example/my-app:latest
    init: true
    network_mode: host
    # No networks section when using host networking
```

Add `host_port` to `routing` in metadata.yaml:

```yaml
routing:
  subdomain: my-app
  auth:
    mode: forward_auth
  host_port: 8080
```

## Step 3: Add config.yml (Optional)

Define user-configurable settings:

```yaml
settings:
  MY_APP_PORT:
    default: "8080"
    description: "HTTP port for the application"
  MY_APP_TIMEZONE:
    default: "${TZ:-UTC}"
    description: "Application timezone"
```

These become environment variables in `runtime.env`, editable through the Cockpit configuration UI.

## Step 4: Add an Icon

Include a `icon.png` file (256x256 pixels, PNG format). This is displayed in:

- The container app store
- The Homarr dashboard tile
- The Cockpit service list

## Step 5: Build and Test

### Build the Package

```bash
# From the app repository root
./tools/build-all.sh

# Output: build/*.deb
```

This requires `container-packaging-tools` to be installed.

### Test Locally

1. Copy the `.deb` to a test device
2. Install: `sudo apt install ./my-app-container_1.0.0-1_all.deb`
3. Verify the container starts: `docker ps`
4. Check the subdomain resolves: `https://my-app.halos.local`
5. Verify the app appears in the Homarr dashboard
6. Test removal: `sudo apt remove my-app-container`

## Step 6: Submit a PR

1. Create a feature branch in the appropriate repository
2. Add your app directory under `apps/`
3. Create a PR with a clear description
4. CI will build and validate the package

For marine apps, add the app to `halos-marine-containers`. For core infrastructure apps, add to `halos-core-containers`.

## Example: Complete Marine App

Here's a complete example of a marine monitoring app:

=== "metadata.yaml"

    ```yaml
    name: Marine Monitor
    app_id: marine-monitor
    version: 1.0.0-1
    upstream_version: 1.0.0
    description: Real-time marine sensor monitoring
    homepage: https://example.com/marine-monitor
    maintainer: Hat Labs <support@hatlabs.fi>
    license: MIT

    tags:
      - role::container-app
      - field::marine
      - category::monitoring
      - interface::web
      - use::monitoring

    debian_section: net
    architecture: all

    depends:
      - docker.io (>= 20.10) | docker-ce (>= 20.10)

    routing:
      subdomain: marine-monitor
      auth:
        mode: forward_auth

    web_ui:
      enabled: true
      port: 3000
      protocol: http
    ```

=== "docker-compose.yml"

    ```yaml
    services:
      marine-monitor:
        image: example/marine-monitor:${UPSTREAM_VERSION:-1.0.0}
        container_name: marine-monitor
        init: true
        restart: unless-stopped
        env_file:
          - runtime.env
        volumes:
          - ${CONTAINER_DATA_ROOT}/marine-monitor/data:/data
        networks:
          - halos-proxy-network
        logging:
          driver: journald
          options:
            tag: "{{.Name}}"

    networks:
      halos-proxy-network:
        external: true
    ```
