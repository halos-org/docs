# Quick Start

Get HaLOS running on your Raspberry Pi in under five minutes.

## Prerequisites

- **Raspberry Pi 4, Raspberry Pi 5, or [HALPI2](https://shop.hatlabs.fi/products/halpi2-computer)**
- **SD card or SSD** (16 GB minimum, 32 GB+ recommended)
- **Internet connection** — required on first boot to download container images
- **Ethernet cable** (recommended) or WiFi access via AP image
- **Another device** (laptop, phone, tablet) with a web browser

## 1. Download the image

Download your preferred image from the [HaLOS releases page](https://github.com/hatlabs/halos-pi-gen/releases/latest).

Not sure which image to pick? See [Choosing an Image](choosing-an-image.md). For a generic Raspberry Pi without marine needs, start with **`Halos-RPI`**.

## 2. Flash the image

1. Download and install [Raspberry Pi Imager](https://www.raspberrypi.org/software/).
2. Insert your SD card or connect your SSD via a USB adapter.
3. Open Raspberry Pi Imager, click **Choose OS → Use custom**, and select the downloaded HaLOS image.
4. Select your target drive and click **Write**.

!!! warning "Do not apply OS customization"
    When Raspberry Pi Imager offers to apply OS customization settings, click **No**. HaLOS has its own first-boot configuration.

For HALPI2 with an NVMe SSD, follow the [HALPI2 flashing instructions](https://docs.hatlabs.fi/halpi2/user-guide/software.html#flashing-an-operating-system-image-to-ssd) instead.

## 3. Boot and connect

!!! important "Internet required"
    HaLOS downloads container images on first boot. The device needs internet access before the web interface becomes available.

**With Ethernet** (recommended): Connect the Pi to your network with an Ethernet cable, then power on. The device gets internet access immediately via DHCP. Wait **2–3 minutes** for containers to download and start, then open **[https://halos.local/](https://halos.local/)**.

**Without Ethernet** (AP image only): Use an [AP image variant](choosing-an-image.md#access-point-variant). After powering on:

1. Connect your laptop/phone to the **`Halos-XXXX`** WiFi network (password: `halos1234`).
2. Open **[https://halos.local:9090/](https://halos.local:9090/)** — this is Cockpit, which runs without containers.
3. Log in with username `pi`, password `halos`.
4. Go to **Networking** and connect the device to your WiFi network (one that has internet access).
5. Wait **2–3 minutes** for containers to download, then open **[https://halos.local/](https://halos.local/)**.

## 4. Accept the certificate warning

Your browser will display a certificate warning because HaLOS uses a self-signed certificate. This is expected — accept the warning to proceed. You only need to do this once per hostname.

## 5. Log in

Enter the default SSO credentials:

| | |
|---|---|
| **Username** | `admin` |
| **Password** | `halos` |

!!! danger "Change default passwords immediately"
    After logging in, change the SSO password through the Authelia portal and the system password (`pi` user) through the Cockpit Users panel. See [First Boot — Default credentials](first-boot.md#default-credentials) for details.

You're now on the HaLOS dashboard — a launchpad for all installed services.

![HaLOS Dashboard](../assets/images/homarr_landing_page.jpg)

## Next steps

- [First Boot](first-boot.md) — Detailed walkthrough of the boot process, connectivity options, and initial setup
- [Web Interface](../user-guide/web-interface.md) — Learn how the web interface is organized
- [Installing Apps](../user-guide/installing-apps.md) — Browse and install applications from the container store
- [Marine Apps](../user-guide/marine-apps.md) — Set up Signal K, Grafana, and other marine applications
