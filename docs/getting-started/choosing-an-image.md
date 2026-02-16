# Choosing an Image

HaLOS images are built along three axes: **hardware platform**, **desktop environment**, and **software stack**. This page helps you pick the right combination.

## Decision guide

**Do you have a HALPI2?** Use a HALPI2 image — it includes drivers for CAN bus, RS-485, I2C, and power management. Otherwise, use an RPI image for any Raspberry Pi 4 or 5.

**Do you need a desktop?** Most users don't — the headless images give you full control through the web interface. Choose a Desktop image only if you plan to connect a monitor and use graphical applications directly on the Pi.

**Do you need marine apps?** If you're installing HaLOS on a boat, choose a Marine image. It includes the Marine App Store with Signal K, InfluxDB, Grafana, AvNav, and other marine applications.

## Hardware platform

| Platform | Target hardware | Extras |
|----------|----------------|--------|
| **HALPI2** | [Hat Labs HALPI2](https://shop.hatlabs.fi/products/halpi2-computer) | CAN bus, RS-485, I2C, power management drivers |
| **RPI** | Raspberry Pi 4 or 5 | No hardware-specific drivers |

## Desktop environment

| Option | Description |
|--------|-------------|
| **Headless** (default) | No desktop GUI. All management through the web interface. SSH available. |
| **Desktop** | Includes XFCE desktop environment for local monitor use. |

## Software stack

| Stack | What's included |
|-------|----------------|
| **Standard** (default) | Cockpit web management, container store, Traefik, Authelia, Homarr |
| **Marine** | Everything in Standard, plus the Marine App Store with Signal K and other marine apps |

## Image comparison table

| Image | Hardware | Desktop | Marine Apps |
|-------|----------|---------|-------------|
| `Halos-HALPI2` | HALPI2 | No | No |
| `Halos-Desktop-HALPI2` | HALPI2 | Yes | No |
| `Halos-Marine-HALPI2` | HALPI2 | No | Yes |
| `Halos-Desktop-Marine-HALPI2` | HALPI2 | Yes | Yes |
| `Halos-RPI` | Generic RPi | No | No |
| `Halos-Desktop-RPI` | Generic RPi | Yes | No |
| `Halos-Marine-RPI` | Generic RPi | No | Yes |
| `Halos-Desktop-Marine-RPI` | Generic RPi | Yes | Yes |

### Access point variant

All headless images include a built-in WiFi access point for initial setup without Ethernet. On first boot, the device creates a WiFi network named **`Halos-XXXX`** (XXXX is unique to your device, password: **`halos1234`**) that you can connect to immediately.

For desktop images, only one variant includes the access point:

- **`Halos-Desktop-Marine-HALPI2-AP`** — Same as `Halos-Desktop-Marine-HALPI2` but with the WiFi access point pre-configured.

### Stock Raspberry Pi OS variants

These images include HALPI2 drivers but **not** the HaLOS web stack (no Traefik, Authelia, Homarr, or Cockpit). Use them if you want a standard Raspberry Pi OS with HALPI2 hardware support.

| Image | Description |
|-------|-------------|
| `Raspios-lite-HALPI2` | Headless Raspberry Pi OS with HALPI2 drivers |
| `Raspios-HALPI2` | Desktop Raspberry Pi OS with HALPI2 drivers |

## Download

All images are available on the [HaLOS releases page](https://github.com/halos-org/halos-pi-gen/releases/latest).

Once you've chosen your image, proceed to [Quick Start](quick-start.md#2-flash-the-image) for flashing instructions, or [First Boot](first-boot.md) for what happens next.
