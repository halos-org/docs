# Trust the device

Each HaLOS device runs its own small Certificate Authority (CA) on first boot and signs a single TLS leaf from it that all of the device's web services use — Traefik on `:443`, Cockpit on `:9090`, and every per-app port between 4430 and 4450.

By default your browser doesn't know about this CA, so you see a "Not secure" warning the first time you visit `https://halos.local/`. Clicking through works, but the warning comes back every time the device rotates its leaf and you have to re-decide for every port.

The cleaner path is to install the device's CA on your workstation once. After that:

- Every app on the device validates without a warning.
- Every port (`:443`, `:9090`, `:4430`+) validates without a warning.
- Leaf rotations are invisible — the trust anchor (the CA) is what your browser checks against, not the leaf itself.

Each HaLOS device has its own CA. If you have several devices, you install one CA per device on your workstation.

## Install the CA

Each device serves a guided installer at:

```
https://<your-device>/ca/
```

Open that URL and follow the steps for your platform. The page detects your operating system, covers macOS, Windows, Linux, iOS, Android, and Firefox, and fills in the exact filename your device saves — that filename embeds the device's hostname, so several devices' CAs stay easy to tell apart in your trust store.

You'll get a "Not secure" warning on this first visit — that's the chicken-and-egg of trusting the CA before you trust the host. Click through it. If you want stronger guarantees before you install, verify the fingerprint first.

## Verifying the fingerprint

To rule out a malicious network between your workstation and the device when you first download the CA, compare its SHA-256 fingerprint with what the device reports over SSH.

On your workstation:

```bash
curl -k -o /tmp/halos-ca.crt https://<your-device>/halos-ca.crt
openssl x509 -in /tmp/halos-ca.crt -noout -fingerprint -sha256
```

On the device (over SSH — out-of-band):

```bash
ssh <your-device> 'sudo openssl x509 -in /var/lib/container-apps/halos-core-containers/data/halos-core-containers/certs/ca/serving-ca.crt -noout -fingerprint -sha256'
```

The two fingerprints must match exactly. If they don't, abort — the file you downloaded isn't from the device.

The canonical version of this procedure lives in the developer docs: [docs/CERTS.md → Chicken-and-egg](https://github.com/halos-org/halos-core-containers/blob/main/docs/CERTS.md#chicken-and-egg-trusting-the-ca-before-you-trust-the-host).

## Regenerate the device CA

A device's CA is created once and then frozen the first time a client downloads it. This "adoption" keeps the CA stable, so anchors you have already installed keep working. The CA's name embeds the device's hostname at the moment it was created. If you later rename the device — or it first booted before it had its final hostname — the name can read stale, and a device imaged with an older HaLOS may carry a generic `HaLOS Device CA` name with no hostname at all.

A stale name is cosmetic: HTTPS still validates, because browsers check the TLS leaf's hostnames, not the CA's name. Regenerate only when the stale name actually gets in your way — for example, you manage several devices and can no longer tell their CAs apart.

To mint a fresh CA with the current hostname, reset the adoption sentinel over SSH and re-run certificate management:

```bash
ssh <your-device> 'echo -n pending | sudo tee \
  /var/lib/container-apps/halos-core-containers/data/halos-core-containers/certs/ca/adoption'
ssh <your-device> 'sudo systemctl start halos-manage-certs.service'
```

The next run regenerates the CA with the current hostname, re-signs the leaf, and reloads Traefik and Cockpit on its own — no container restart, and no need to delete `ca.crt` or `ca.key`.

!!! warning
    This replaces the CA. Every client that trusted the old one must remove it (see below) and install the new CA, which now downloads under a new, hostname-specific filename.

## Removing the trust anchor

If you decommission a HaLOS device or no longer want to trust it, remove the CA from your workstation:

- **macOS**: Keychain Access → find the cert → delete → admin password.
- **Windows**: `certmgr.msc` → Trusted Root Certification Authorities → Certificates → find and delete.
- **Linux**: `sudo rm /usr/local/share/ca-certificates/halos-ca.crt && sudo update-ca-certificates --fresh`.
- **iOS**: Settings → General → VPN & Device Management → tap the profile → Remove Profile.
- **Android**: Settings → search **credentials** → **User credentials** → tap the HaLOS CA → **Remove** (on stock Android: Security → Encryption & credentials → User credentials; the exact path varies by vendor).
- **Firefox**: Preferences → Certificates → View Certificates → Authorities → select → Delete or Distrust.

Subsequent visits to the device will fall back to "Not secure", as if you never installed the CA.

Re-flashing a device has the same effect: the new image generates a fresh CA, so any CA you previously installed for that hostname is now stale. Remove the old CA before installing the new one. If you visited the device on an older HaLOS version your browser may still have an HSTS pin cached, which blocks the usual click-through bypass on top of the cert mismatch — see [Troubleshooting → Browser refuses to load the device after re-flashing](troubleshooting.md#browser-refuses-to-load-the-device-after-re-flashing) for the one-time cleanup. Current HaLOS versions no longer emit HSTS, so once the cached pin is cleared the lockout will not recur.
