# Installing on Existing OS

Already running Raspberry Pi OS? You can install the HaLOS software stack without reflashing.

## Requirements

- **Raspberry Pi OS Trixie** (Debian 13), arm64 architecture
- **Raspberry Pi 4 or 5**
- An active internet connection

!!! warning "Trixie only"
    HaLOS packages are built for Debian Trixie. They are not tested on Bookworm or other Debian releases.

## 1. Add the Hat Labs APT repository

Import the GPG signing key and add the repository source:

```bash
# Import the GPG key
curl -fsSL https://apt.hatlabs.fi/hat-labs-apt-key.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/hatlabs.gpg

# Add the repository
echo "deb [signed-by=/usr/share/keyrings/hatlabs.gpg] https://apt.hatlabs.fi trixie-stable main" \
  | sudo tee /etc/apt/sources.list.d/hatlabs.list

# Update package lists
sudo apt update
```

## 2. Install HaLOS

Choose the metapackage that fits your needs:

=== "Standard"

    Installs the base HaLOS stack: Traefik reverse proxy, Authelia SSO, Homarr dashboard, Cockpit system management, and the container app store.

    ```bash
    sudo apt install halos
    ```

=== "Marine"

    Includes everything in Standard, plus the Marine App Store with curated marine applications (Signal K, InfluxDB, Grafana, and more).

    ```bash
    sudo apt install halos-marine
    ```

## 3. Wait for containers to start

After installation, the core containers (Traefik, Authelia, Homarr) need **2–3 minutes** to pull images and start up.

## 4. Access the web interface

Open a browser and go to:

```
https://<your-hostname>.local/
```

Replace `<your-hostname>` with your Pi's actual hostname (check with `hostname` in the terminal).

- Accept the self-signed certificate warning (see [First Boot — Certificate warning](first-boot.md#certificate-warning))
- Log in with SSO credentials: `admin` / `halos`
- Change the default password immediately

## Differences from a HaLOS image

When installing on an existing OS rather than using a pre-built image:

- The system hostname is whatever you already have configured (not `halos`). Your URLs will be `https://<your-hostname>.local/` and `https://<app>.<your-hostname>.local/`.
- Your existing user account and SSH configuration are preserved.
- Desktop environment and other packages you've installed remain untouched.
- HALPI2 hardware drivers are **not** included — those are only in the HALPI2 image variants.

## Next steps

- [Web Interface](../user-guide/web-interface.md) — Learn how the web interface is organized
- [Installing Apps](../user-guide/installing-apps.md) — Browse and install applications
