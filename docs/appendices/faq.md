# FAQ

Frequently asked questions about HaLOS.

## General

### What is HaLOS?

HaLOS (Hat Labs Operating System) is a custom Raspberry Pi OS distribution that turns a Raspberry Pi into a managed appliance with a web-based interface. It provides a dashboard, app store, single sign-on, and reverse proxy out of the box.

### What hardware does HaLOS support?

HaLOS runs on **Raspberry Pi 4** and **Raspberry Pi 5** boards (64-bit/arm64). The HALPI2 variants additionally support the [HALPI2 hardware module](https://hatlabs.fi) with CAN bus, RS-485, and I2C interfaces for marine and industrial use.

### Is HaLOS free?

Yes. HaLOS is open-source software. The source code is available on [GitHub](https://github.com/hatlabs) under various open-source licenses.

### How is HaLOS different from other Pi distributions?

HaLOS is purpose-built as a managed appliance platform. Unlike general-purpose Pi distributions, it includes a web dashboard, app store, SSO authentication, and reverse proxy pre-configured and ready to use. The marine variants add curated navigation and monitoring apps.

## Installation

### Which image should I download?

See [Choosing an Image](../getting-started/choosing-an-image.md) for a detailed comparison. In short:

- **HALPI2 images** if you have HALPI2 hardware
- **RPI images** for standard Raspberry Pi 4/5
- **Marine variants** if you want pre-installed marine navigation and monitoring apps
- **Desktop variants** if you need a local display

### Can I install HaLOS on an existing Raspberry Pi OS?

Yes, if you're running **Debian Trixie (arm64)**. See [Installing on Existing OS](../getting-started/installing-on-existing-os.md) for instructions.

### How long does the first boot take?

The initial boot takes **2-3 minutes** while Docker containers start for the first time. Subsequent boots are faster.

## Access and Authentication

### What are the default credentials?

HaLOS has two authentication systems:

| System | Username | Password | Used for |
|--------|----------|----------|----------|
| Authelia SSO | `admin` | `halos` | Web applications (dashboard, apps) |
| Linux system | `pi` | `halos` | Cockpit, SSH, terminal |

!!! warning
    Change both sets of credentials after first boot.

### Why do I get a certificate warning?

HaLOS uses a self-signed TLS certificate generated on first boot. Browsers don't trust self-signed certificates, so they show a warning. This is expected -- accept the warning to proceed. The connection is still encrypted.

### How do I access the system if the web interface is down?

Connect via SSH (`ssh pi@halos.local`) or access Cockpit directly at `https://halos.local:9090/`. Cockpit uses Linux system authentication, which is independent of the SSO system.

## Apps and Services

### How do I install apps?

Open Cockpit and navigate to **Container Apps** for container applications or **Packages** for general Debian packages. See [Installing Apps](../user-guide/installing-apps.md) for details.

### Where is app data stored?

Container app data is stored under `/var/lib/container-apps/<app-name>/`. Each app has its own directory with configuration files and persistent data volumes.

### How do I update apps?

Run `sudo apt update && sudo apt upgrade` from the terminal or use Cockpit's Packages module. Container app updates are delivered as Debian package updates.

### Can I add my own Docker containers?

Yes, but for full integration (dashboard tile, SSO, subdomain routing), package them using the [container-packaging-tools](../developer-guide/adding-apps.md). Standalone Docker containers will work but won't appear in the dashboard or use the SSO system.

## Networking

### How does `*.halos.local` name resolution work?

HaLOS uses mDNS (multicast DNS) via Avahi. The `halos-mdns-publisher` service automatically advertises subdomain hostnames for installed apps. See [Networking](../user-guide/networking.md) for details.

### Can I change the hostname from `halos`?

The hostname can be changed, but it affects all URLs (`*.halos.local` becomes `*.newhostname.local`). The TLS certificate is regenerated to match the new hostname. Bookmarks and saved URLs will need to be updated.

### Can I access HaLOS from the internet?

HaLOS is designed for local network use. Internet access requires additional configuration (port forwarding, dynamic DNS, proper TLS certificates) that is not provided out of the box.

## Troubleshooting

### The dashboard shows no app tiles

The `homarr-container-adapter` may not have synced yet. Wait a minute for auto-discovery, or check that containers are running with `docker ps`.

### An app's subdomain doesn't resolve

1. Check the app's container is running: `docker ps`
2. Check the mDNS publisher: `systemctl status halos-mdns-publisher`
3. Test resolution: `avahi-resolve -n <app>.halos.local`

See [Troubleshooting](../user-guide/troubleshooting.md) for more solutions.

### How do I get help?

- Check the [Troubleshooting](../user-guide/troubleshooting.md) guide
- Open an issue on [GitHub](https://github.com/hatlabs)
- See [Contributing](../developer-guide/contributing.md) for community channels
