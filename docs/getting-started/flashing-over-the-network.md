# Flashing Over the Network

Re-flash a running HaLOS device without removing the SD card or SSD, using [flash-live-system](https://github.com/hatlabs/flash-live-system).

## When to use this

- **Re-flashing** a device that's already running and reachable over SSH
- **HALPI2** with NVMe SSD — the drive isn't easily removable
- **Automated deployments** with pre-configured hostname, user, WiFi, and SSH keys

!!! danger "This completely erases the target device"
    flash-live-system overwrites the entire boot disk. All data on the device is lost. Make sure you're flashing the right device.

## Prerequisites

- A HaLOS device running and reachable over SSH
- The `flash-live-system` tool installed on your computer (see below)
- A HaLOS image file (`.img`, `.img.xz`, or `.img.gz`)

## 1. Install flash-live-system

Download the pre-built script on your computer:

```bash
sudo curl -Lo /usr/local/bin/flash-live-system \
  https://github.com/hatlabs/flash-live-system/releases/latest/download/flash-live-system
sudo chmod +x /usr/local/bin/flash-live-system
```

## 2. Download the image

Download your preferred image from the [HaLOS releases page](https://github.com/halos-org/halos-pi-gen/releases/latest). Not sure which image to pick? See [Choosing an Image](choosing-an-image.md).

## 3. Create a config file (optional)

A config file lets you pre-configure the new image on first boot — hostname, user account, WiFi, and SSH keys are all set automatically, so you don't need to go through the manual [first-boot setup](first-boot.md).

Create a file (e.g., `myboat.conf`):

```ini
hostname=myboat
user=captain
password=changeme
ssh-key=~/.ssh/id_ed25519.pub
wifi-ssid=MyNetwork
wifi-password=MyWifiPass
wifi-country=FI
```

| Key | Description |
|---|---|
| `hostname` | System hostname |
| `user` | Username (renames the default UID 1000 user) |
| `password` | User password |
| `ssh-key` | SSH public key file path (repeatable for multiple keys) |
| `wifi-ssid` | WiFi network name (requires `wifi-password`) |
| `wifi-password` | WiFi password (requires `wifi-ssid`) |
| `wifi-country` | WiFi regulatory domain, e.g. `FI`, `US`, `GB` (default: `GB`) |

!!! tip "SSH keys"
    If you set `user` without any `ssh-key` lines, your `~/.ssh/*.pub` keys are added automatically. Tilde (`~/`) in paths is expanded.

## 4. Flash the device

=== "Remote (recommended)"

    Flash a device over SSH from your computer:

    ```bash
    flash-live-system --remote halos.local --config myboat.conf Halos-Marine-HALPI2.img.xz
    ```

    The tool copies the compressed image to the device's RAM, then decompresses and writes it to disk. If the transfer fails, no destructive action has happened — the device is fully recoverable.

=== "On the device"

    Run directly on the device being flashed:

    ```bash
    sudo flash-live-system --config myboat.conf Halos-Marine-HALPI2.img.xz
    ```

    The tool auto-detects the safest flash method based on available RAM and disk layout.

Before writing, the tool asks you to confirm by typing a phrase:

```
Type "nuke halos.local from orbit" to proceed:
```

## 5. Wait for reboot

After flashing, the device reboots automatically. If you provided a config file, first boot takes an extra minute to apply settings (hostname, user, WiFi) before rebooting once more into the fully configured system.

Once the device is back up, continue with [First Boot](first-boot.md) to verify everything is working.

!!! note "Console messages during flashing"
    You may see EXT4-fs errors on the device's console while flashing. These are expected and harmless — the old filesystem is being overwritten, and the kernel reports the underlying data changes as corruption.

## Ramfs vs. stream mode

By default, flash-live-system uses **ramfs mode**: the compressed image is copied to RAM first, verified, then written to disk. This is the safest option — a failed transfer doesn't touch the disk.

If the device doesn't have enough RAM to hold the compressed image (~4 GB+), use **stream mode** with `--stream`. This pipes the image directly to disk without buffering in RAM.

!!! warning "Stream mode risk"
    In stream mode, if the transfer fails mid-write, the device has a partial image and will need to be re-flashed manually (e.g., by removing the SD card and using Raspberry Pi Imager).

For full details on modes and advanced usage, see the [flash-live-system documentation](https://github.com/hatlabs/flash-live-system).

## Next steps

- [First Boot](first-boot.md) — What to expect after the device reboots
- [Troubleshooting](../user-guide/troubleshooting.md) — Common issues and solutions
