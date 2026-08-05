# Remote Access

To reach HaLOS from outside the LAN, the device's canonical hostname must resolve from the remote network. The shipped default `${hostname}.local` is mDNS-only. Don't try to alias it to a routable IP: `.local` is reserved for mDNS, operating systems handle it through special resolution paths (macOS via `mDNSResponder`, Linux typically via NSS plus systemd-resolved's built-in mDNS), and whether a hosts-file or DNS-server override "wins" varies by platform, browser, and resolver configuration.

Enabling remote access has two parts:

1. Change the canonical from `${hostname}.local` to a fully-qualified domain name (FQDN, a name with at least one dot in it, like `halos.example`) that resolves on your LAN. The canonical is the first line of `/etc/halos/hostnames.conf`.
2. Make the same FQDN resolve from the remote network.

You'll also need a VPN connecting the remote network to the device's LAN. Configuring the VPN itself is out of scope for this page.

## Step 1: Set an FQDN as the canonical

The new FQDN must already resolve on your LAN to the device's LAN IP, otherwise on-LAN clients break too. Two ways to get there, depending on whether your router already publishes a name for the device.

### If your router already serves a name for the device

Many home and SOHO routers automatically create a DNS entry for every device that takes a DHCP lease, combining the device's hostname with a domain suffix the router advertises (e.g., `halos.home`, `halos.lan`, or `halos.<something>`). Routers running dnsmasq do this out of the box, which covers OpenWrt, OPNsense, pfSense, Pi-hole used as the DHCP+DNS server, and many consumer routers.

Test from a LAN client that isn't the HaLOS device itself:

    nslookup halos.<your-domain>

If that returns the device's LAN IP, you already have an FQDN that works. Tell HaLOS to use it as the canonical by editing `/etc/halos/hostnames.conf` and putting the special `${fqdn}` token on the first line:

    ${fqdn}
    ${hostname}.local

`${fqdn}` expands at service start to `<device-hostname>.<dhcp-domain>`, which is the same name your router publishes. Using the token (rather than hard-coding the name) means the canonical tracks the device automatically if the hostname or DHCP domain changes.

### If you need to add the name yourself

If the `nslookup` above didn't work — your router doesn't auto-register DHCP leases, or the DHCP domain isn't a name you'd want as the canonical (`.lan`, `.home`, an ISP-pushed default) — add a DNS record yourself on whatever serves DNS on your LAN. Pick a name like `halos.example`, point it at the HaLOS device's LAN IP, and reserve that IP in DHCP so it doesn't move.

Then edit `/etc/halos/hostnames.conf` and put the chosen name on the first line:

    halos.example
    ${hostname}.local

### Restart and verify

In both cases, keep `${hostname}.local` in the list — typing `halos.local` in a browser still works on the LAN via mDNS, but the canonical (the OIDC issuer URL) is now the FQDN.

Restart and verify:

```bash
sudo systemctl restart halos-core-containers.service
journalctl -u halos-core-containers.service -n 30 --no-pager | grep -i domain
```

Expect a `Domain: <your-fqdn>` line. From a LAN client, confirm that browsing to `https://<your-fqdn>/` works end-to-end, including clicking Login and returning to the dashboard.

## Step 2: Make the FQDN resolve on remote clients

On the remote device, add an override mapping the FQDN to whatever IP that device can route to the HaLOS device through. How you do this varies by platform.

### Desktop hosts file

Add a line to the hosts file pointing at the VPN-reachable IP:

    10.7.0.42  halos.example

Locations and admin requirements per OS:

- **macOS / Linux:** `/etc/hosts`. Edit with `sudo`.
- **Windows:** `C:\Windows\System32\drivers\etc\hosts`. Edit with an editor opened as Administrator (otherwise saves fail silently).

Works the same on all three because the name isn't `.local`.

### Mobile

Stock iOS and Android don't expose a hosts file without jailbreak or root. Use either VPN-side DNS (next section) or an on-device DNS-filter app (AdGuard, NextDNS, Personal DNS Filter) configured with the host override.

### Using Tailscale as the VPN

Tailscale gives you a tunnel between the HaLOS device and your personal devices without running your own VPN server. Install it on both ends; the HaLOS device gets a tailnet IP that you put in the hosts-file override above. Get it from `tailscale status`:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale status
```

Point the override at that tailnet IP. The canonical stays your chosen FQDN, and only your tailnet-connected devices use the override. On-LAN clients aren't affected.

### Routing the FQDN via the LAN DNS server

Most VPNs can route specific DNS queries through the tunnel to a server on the LAN side. This works for host-to-site VPN (one client back to a LAN) and site-to-site VPN (two networks linked) alike: the LAN's DNS server answers for remote clients too, reached through the tunnel. No per-device overrides to maintain.

The pattern is **split-DNS**: only queries for your chosen domain go to the LAN DNS server, and everything else uses the client's normal resolver. Each VPN exposes it differently.

- **WireGuard.** The `DNS =` line in the client config sets the interface's nameserver and search domain. Split-DNS itself (routing only specific suffixes through the WireGuard nameserver) is handled by the client OS's resolver, not wg-quick directly. On Linux with systemd-resolved, the common approach is a `PostUp` hook:

        [Interface]
        DNS = 192.168.1.1
        PostUp = resolvectl domain %i ~example
        PostDown = resolvectl revert %i

    `~example` marks `example` as a routing-only domain for the interface; queries ending in `.example` go to `192.168.1.1`, everything else uses the system's normal resolver. The official WireGuard GUI clients on macOS and Windows handle DNS configuration in their own settings panels and don't always expose split-DNS routing.

- **OpenVPN.** Pushing a DNS server with `push "dhcp-option DNS <ip>"` causes the client to use that server for all queries while connected. True split-DNS (only routing specific suffixes) needs `push "dhcp-option DOMAIN-ROUTE <suffix>"` on OpenVPN 2.5+ with a client that respects it (Linux with systemd-resolved does; not all GUI clients do).

- **Tailscale.** Configure Split DNS in the admin console's DNS settings. Add the LAN DNS server's IP and the domain it should handle (e.g., `example`); the tailnet routes queries for that suffix to the specified server. The LAN DNS server has to be reachable from the tailnet, which means either running Tailscale on it as well, or advertising a subnet route from another tailnet member (typically the HaLOS device, with `sudo tailscale up --advertise-routes=192.168.1.0/24` plus an approval in the admin console).

You don't need a separate VPN-side view of the DNS. The LAN's answer (the device's LAN IP) works for remote clients because the VPN routes them to that IP.

## Hostname-choice guidance

Avoid:

- **`.lan`, `.home`, `.localnet`** and other widely-used informal defaults. Many consumer routers ship with one of these as their DHCP option-15 domain. When two networks both call themselves `.lan`, anything bridging them or any client cache crossing the boundary gets ambiguous resolution.
- **Real TLDs you don't own.** `.boat`, `.dev`, and other registered TLDs invite collisions with public DNS.
- **`.local`** for anything other than its mDNS-default role.

What to use:

- **A clearly-made-up suffix you've picked for your site** (`halos.example`, `halos.boat-name`, `halos.hurma`). Simplest option; just needs to be a name your LAN DNS server is willing to serve.
- **`.home.arpa`**. RFC 8375 reserves this suffix for private home-network use, so it won't collide with public DNS.
- **A subdomain of a domain you actually own** (`halos.matti.example.com`). Best fit if your setup involves real public DNS infrastructure.

## Gotchas

### DNS-over-HTTPS bypassing your resolver

Modern browsers (Firefox by default, Chrome and Edge optionally) can ship queries directly to a public DoH resolver, bypassing the operating system's resolver entirely. Your LAN DNS or VPN-pushed DNS isn't consulted, and the canonical returns NXDOMAIN.

Symptoms: `nslookup` from the same machine returns the right IP, but the browser fails to load the page.

Fix: disable DoH in the browser, or set the bypass list to include your canonical's domain.

- **Firefox:** Settings → Privacy & Security → DNS over HTTPS → Off.
- **Chrome / Edge:** chrome://settings/security → Use secure DNS → Off, or "With your current service provider."

### mDNS does not cross tunnels

Don't try to make `halos.local` work over a VPN by reflecting mDNS across the tunnel. Multicast across tunnels scales poorly and creates resolution loops. Switching the canonical to an FQDN avoids this.

## Reverting

To go back to the shipped default, edit `/etc/halos/hostnames.conf` and put `${hostname}.local` back on the first line:

    ${hostname}.local
    <any other registered hostnames>

Restart:

```bash
sudo systemctl restart halos-core-containers.service
```

Active sessions tied to the previous canonical become invalid. Users log in once.

## See also

- [Networking](networking.md). Base hostname configuration, mDNS, access point mode.
- [Single Sign-On](../architecture/sso.md). How OIDC, Authelia, and Traefik fit together.
- [Trust the device](trust-the-device.md). Installing the device's CA so TLS validates without warnings.
