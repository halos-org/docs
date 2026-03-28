# GPS

HaLOS Marine variants include [gpsd](https://gpsd.io/), a GPS service daemon that provides location data to applications. gpsd multiplexes GPS data from one or more receivers to multiple clients, and is required by [ubxtool](https://gpsd.io/ubxtool-man.html) for configuring u-blox GNSS receivers.

## How it works

gpsd listens for GPS data from configured serial devices and USB receivers, and makes it available to clients via a TCP socket on port 2947. Applications connect to this socket using gpsd's JSON-based protocol.

By default, HaLOS Marine configures gpsd with:

- **No fixed serial devices** — only USB auto-detection is enabled
- **USB auto-detection** (`USBAUTO=true`) — USB GPS receivers are detected and added automatically when plugged in

On [HALPI2](https://docs.hatlabs.fi/halpi2/), gpsd is additionally configured to use the GNSS HAT serial port (`/dev/ttyAMA0`). Any GNSS receiver HAT on this port will work. For u-blox receivers, HaLOS additionally auto-configures the module for marine use (10 Hz update rate, Sea dynamic model). See the [HALPI2 GNSS documentation](https://docs.hatlabs.fi/halpi2/user-guide/interfaces/#gnss-gps) for details.

## Accessing GPS data

**Signal K** connects to gpsd automatically and makes position data available through its API. No additional configuration is needed.

**Command-line tools** are available for diagnostics:

```bash
# Monitor GPS data in real-time (JSON)
gpsmon

# Output raw NMEA sentences
gpspipe -r

# Show current fix status
gpspipe -w | head -20
```

!!! note
    gpsd uses its own JSON protocol, not raw NMEA. Use `gpspipe -r` if you need raw NMEA 0183 sentences.

## Configuration

gpsd configuration is stored in `/etc/default/gpsd`. To add a serial GPS device:

```bash
# Edit gpsd defaults
sudo nano /etc/default/gpsd

# Change DEVICES to include your serial port, e.g.:
# DEVICES="/dev/ttyUSB0"

# Restart gpsd
sudo systemctl restart gpsd
```

## USB GPS receivers

USB GPS receivers are detected automatically when plugged in, thanks to the `USBAUTO=true` setting. No configuration is needed — gpsd will start reading data from the receiver immediately.
