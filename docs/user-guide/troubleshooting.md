# Troubleshooting

Common issues and how to resolve them.

## Can't access the web interface

**Symptom**: Browser can't reach `https://halos.local/`.

**Possible causes and solutions**:

1. **No internet on first boot**: Container images are downloaded on first boot. Without internet, only Cockpit on port 9090 works. Connect via Ethernet or use the AP image to configure WiFi first — see [First Boot](../getting-started/first-boot.md#connecting-to-halos).

2. **Not enough time**: Core containers take 2–3 minutes to download and start after boot. Wait and try again.

3. **Hostname not resolving**: mDNS (`.local`) resolution depends on your client device and network. Try:
    - Accessing by IP address instead (check your router's DHCP client list)
    - Using a different device or browser
    - On Windows, ensure the Bonjour service is running

4. **Not on the same network**: Your device must be on the same local network as the Raspberry Pi. If using WiFi, ensure you're connected to the right network.

5. **Try Cockpit directly**: Cockpit runs independently on port 9090 and doesn't depend on Traefik or Authelia. Try `https://halos.local:9090/` — if this works, the issue is with the reverse proxy containers.

## Certificate warnings

**Symptom**: Browser shows a security warning when accessing any HaLOS URL.

This is **expected behavior**. HaLOS uses self-signed certificates because automatic certificates (Let's Encrypt) aren't possible on local `.local` networks.

Accept the warning once per hostname. Since each app uses a different subdomain (`signalk.halos.local`, `grafana.halos.local`, etc.), you'll see the warning once for each subdomain you visit for the first time.

See [First Boot — Certificate warning](../getting-started/first-boot.md#certificate-warning) for browser-specific instructions.

## Container app store is empty

**Symptom**: The Container Apps section in Cockpit shows no applications.

**Solution**: Run a system update first:

```bash
sudo apt update && sudo apt upgrade
```

This downloads the latest package lists from the Hat Labs repository. After updating, the container store should show available apps.

## App not showing on the dashboard

**Symptom**: You installed an app but it doesn't appear on the Homarr dashboard.

**Check these in order**:

1. **Is the container running?** Check via Cockpit → Services or:
    ```bash
    sudo docker ps
    ```

2. **Wait for the adapter**: The `homarr-container-adapter` syncs containers to the dashboard periodically. Give it a minute after install.

3. **Check adapter logs**:
    ```bash
    sudo journalctl -u homarr-container-adapter -f
    ```

4. **Restart the adapter**:
    ```bash
    sudo systemctl restart homarr-container-adapter
    ```

## WiFi not connecting

**Symptom**: Can't connect to a WiFi network through Cockpit.

1. Open Cockpit → Networking and check the WiFi interface status.
2. Verify the WiFi credentials are correct.
3. Check Cockpit → Logs for NetworkManager errors.
4. If using an AP image, the device may be in AP mode. Switch to client mode through Cockpit NetworkManager.
5. As a fallback, connect via Ethernet and configure WiFi from the wired connection.

## SSH access

**Headless images**: SSH is enabled by default. Connect with:

```bash
ssh pi@halos.local
```

Default password: `halos`

**Desktop images**: SSH is disabled by default. Enable it via the Cockpit terminal or by connecting a keyboard and monitor:

```bash
sudo systemctl enable --now ssh
```

## Changed hostname, can't connect

**Symptom**: After changing the hostname, `halos.local` no longer works.

The old `.local` hostname stops resolving once the hostname is changed. Use the new hostname instead:

```
https://<new-hostname>.local/
```

If you've forgotten the new hostname, find the device by:

- Checking your router's DHCP client list for the device's IP address
- Connecting a monitor and keyboard to see the login prompt (which shows the hostname)
- Scanning the network: `ping -c1 halos.local` (if you haven't changed it) or use a network scanner

## Containers not starting

**Symptom**: Services show as failed or containers aren't running.

1. Check the service status:
    ```bash
    sudo systemctl status <service-name>.service
    ```

2. Check Docker:
    ```bash
    sudo docker ps -a
    sudo docker logs <container-name>
    ```

3. Check disk space — containers need room for images:
    ```bash
    df -h
    ```

4. Check if Docker is running:
    ```bash
    sudo systemctl status docker
    ```

## Getting help

- **[GitHub Discussions](https://github.com/hatlabs/halos-distro/discussions)** — Ask questions and share ideas with the community
- **[GitHub Issues](https://github.com/hatlabs/halos-distro/issues)** — Report bugs or request features
