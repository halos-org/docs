# Building Images

HaLOS images are built using [pi-gen](https://github.com/RPi-Distro/pi-gen), the official Raspberry Pi OS image builder. The `halos-pi-gen` repository extends pi-gen with custom stages for HaLOS.

## Prerequisites

- Docker (for containerized builds)
- Sufficient disk space (~10 GB per image variant)

No other tools are needed -- the build runs entirely inside Docker.

## Build Commands

```bash
cd halos-pi-gen

# Build a specific image variant
./run docker-build "Halos-Marine-HALPI2"

# Build all enabled variants
./run docker-build-all

# Clean up build artifacts
./run docker-clean
```

Builds produce a compressed `.img` file suitable for flashing to an SD card or SSD.

## Image Variants

Each variant is defined by a `config.*` file that specifies the image name and which stages to include.

### Available Variants

| Config File | Image Name | Hardware | Desktop | Marine |
|-------------|-----------|----------|---------|--------|
| `config.halos-halpi2` | Halos-HALPI2 | HALPI2 | No | No |
| `config.halos-desktop-halpi2` | Halos-Desktop-HALPI2 | HALPI2 | Yes | No |
| `config.halos-marine-halpi2` | Halos-Marine-HALPI2 | HALPI2 | No | Yes |
| `config.halos-desktop-marine-halpi2` | Halos-Desktop-Marine-HALPI2 | HALPI2 | Yes | Yes |
| `config.halos-rpi` | Halos-RPI | Generic RPi | No | No |
| `config.halos-desktop-rpi` | Halos-Desktop-RPI | Generic RPi | Yes | No |
| `config.halos-marine-rpi` | Halos-Marine-RPI | Generic RPi | No | Yes |
| `config.halos-desktop-marine-rpi` | Halos-Desktop-Marine-RPI | Generic RPi | Yes | Yes |

Additional variants:

- `config.halos-desktop-marine-halpi2-ap` -- Pre-installation image with default WiFi access point
- `config.raspios-lite-halpi2` -- Stock RPi OS (headless) with HALPI2 drivers
- `config.raspios-halpi2` -- Stock RPi OS (desktop) with HALPI2 drivers

### Config File Format

Each config file defines the image name and the list of stages to include:

```bash
IMG_NAME="Halos-Marine-HALPI2"
STAGE_LIST="stage0 stage1 stage2 stage-common stage-halpi2-common stage-halos-base stage-halpi2-marine stage-halos-marine stage-halos-headless stage-export"
```

## Stage System

Pi-gen uses a stage-based build system. Stages run in order, and each stage can install packages, copy files, and run scripts.

### Standard Pi-gen Stages

| Stage | Purpose |
|-------|---------|
| `stage0` | Bootstrap (debootstrap) |
| `stage1` | Essential packages |
| `stage2` | Lite system (networking, users) |
| `stage-common` | Common configuration |

### Custom HaLOS Stages

| Stage | Purpose | Included In |
|-------|---------|-------------|
| `stage-halos-base` | Cockpit, Docker, Traefik, Authelia, Homarr | All HaLOS variants |
| `stage-halpi2-common` | HALPI2 hardware drivers (CAN, RS-485, I2C, firmware) | HALPI2 variants |
| `stage-halpi2-marine` | HALPI2 marine hardware (GNSS HAT, UART) | HALPI2 + Marine |
| `stage-halos-marine` | Marine app store, pre-installed marine apps | Marine variants |
| `stage-halos-headless` | Headless-specific config (no desktop) | Headless variants |

### Stage File Structure

Each stage directory contains numbered tasks:

```
stage-halos-base/
├── 00-install-docker/
│   ├── 00-packages            # APT packages to install
│   └── 01-run-chroot.sh       # Script to run inside the image
├── 01-install-cockpit/
│   ├── 00-packages
│   └── 01-run-chroot.sh
├── 02-install-core-containers/
│   ├── 00-run.sh              # Script to run on the host
│   └── 01-run-chroot.sh
└── ...
```

Task types:

- `00-packages` -- List of APT packages to install
- `00-run.sh` -- Script that runs on the host (has access to the filesystem)
- `01-run-chroot.sh` -- Script that runs inside the image (chroot environment)
- `files/` -- Configuration files to copy into the image

## Customization

### Adding a Package

To add a package to all HaLOS images, create a new task in `stage-halos-base`:

```bash
# stage-halos-base/03-my-package/00-packages
my-package-name
```

### Adding a Configuration File

```bash
# stage-halos-base/03-my-config/files/etc/my-config.conf
# (the file content)

# stage-halos-base/03-my-config/01-run-chroot.sh
install -m 644 files/etc/my-config.conf /etc/my-config.conf
```

### Creating a New Stage

1. Create a directory: `stage-my-stage/`
2. Add numbered task directories with scripts and package lists
3. Reference the stage in the appropriate `config.*` files

## CI/CD

### PR Checks

PRs run lightweight validation:

- shellcheck on all scripts
- Stage and config file validation

### Main Branch Builds

Pushes to main trigger full image builds for all variants:

1. Each variant builds in a Docker container
2. Completed images are uploaded as release artifacts
3. A draft GitHub release is created

Image builds are resource-intensive and can take 30-60 minutes per variant.
