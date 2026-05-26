# Trust the device

Each HaLOS device runs its own small Certificate Authority (CA) on first boot and signs a single TLS leaf from it that all of the device's web services use — Traefik on `:443`, Cockpit on `:9090`, and every per-app port between 4430 and 4450.

By default your browser doesn't know about this CA, so you see a "Not secure" warning the first time you visit `https://halos.local/`. Clicking through works, but the warning comes back every time the device rotates its leaf and you have to re-decide for every port.

The cleaner path is to install the device's CA on your workstation once. After that:

- Every app on the device validates without a warning.
- Every port (`:443`, `:9090`, `:4430`+) validates without a warning.
- Leaf rotations are invisible — the trust anchor (the CA) is what your browser checks against, not the leaf itself.

Each HaLOS device has its own CA. If you have several devices, you install one CA per device on your workstation.

## Download the CA

The active CA is published by the device at:

```
https://<your-device>/halos-ca.crt
```

Open that URL in your browser. The browser offers to download the file, and on most platforms opens the OS-level certificate install dialog directly.

You'll get a "Not secure" warning on this first visit — that's the chicken-and-egg of trusting the CA before you trust the host. Click through. If you want stronger guarantees, see [Verifying the fingerprint](#verifying-the-fingerprint) below.

## Install on your workstation

### macOS

1. Open the downloaded `halos-ca.crt` — **Keychain Access** opens.
2. Choose the **System** keychain when prompted (not Login — System is what Safari and the system trust chain consult).
3. After import, find the certificate in Keychain Access, double-click it, expand **Trust**, and set **When using this certificate** to **Always Trust**.
4. Close the window; macOS prompts for your admin password to save the trust setting.
5. Restart any open browsers.

Verify by visiting `https://<your-device>/` — Safari should now show a closed padlock with no warnings.

### Windows

1. Double-click the downloaded `halos-ca.crt` — the **Certificate Import Wizard** opens.
2. Click **Install Certificate**, choose **Local Machine** (requires admin), click **Next**.
3. Select **Place all certificates in the following store**, click **Browse**, choose **Trusted Root Certification Authorities**, click **OK**, then **Next** and **Finish**.
4. Windows shows a security warning confirming you trust the certificate — click **Yes**.
5. Restart any open browsers.

Edge and Chrome use the Windows store and will pick this up immediately. Firefox has its own trust store — see [Firefox](#firefox) below.

### Linux (Debian / Ubuntu / HaLOS workstation)

```bash
sudo cp halos-ca.crt /usr/local/share/ca-certificates/halos-ca.crt
sudo update-ca-certificates
```

This populates `/etc/ssl/certs/` with the new anchor. Chromium and most CLI tools (`curl`, `wget`, `git`) pick it up immediately. Firefox has its own trust store — see [Firefox](#firefox) below.

### iOS / iPadOS

1. AirDrop or email the `halos-ca.crt` file to the device.
2. Open the file — iOS prompts to download a **Configuration Profile**.
3. Open **Settings → General → VPN & Device Management** (sometimes called Profile Management), find the downloaded profile, and tap **Install**.
4. Open **Settings → General → About → Certificate Trust Settings** and toggle the HaLOS CA to **on**. This last step is required — without it, Safari ignores the installed root.
5. Restart Safari.

### Android

Android's user-installed trust store is honored by Chrome (for Web pages), by Firefox, and by most stock browsers. It is **not** honored by app-embedded WebViews (so apps that authenticate against your HaLOS device may still fail), and starting with Android 7 it requires apps to opt in via `network_security_config`.

For the install procedure and the constraints, see the [Android Network Security Configuration documentation](https://developer.android.com/privacy-and-security/security-config).

### Firefox

Firefox uses its own trust store and does not pick up OS-level installations.

1. Open **Preferences → Privacy & Security → Certificates → View Certificates**.
2. Switch to the **Authorities** tab and click **Import**.
3. Select `halos-ca.crt`, check **Trust this CA to identify websites**, click **OK**.

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

## Removing the trust anchor

If you decommission a HaLOS device or no longer want to trust it, remove the CA from your workstation:

- **macOS**: Keychain Access → find the cert → delete → admin password.
- **Windows**: `certmgr.msc` → Trusted Root Certification Authorities → Certificates → find and delete.
- **Linux**: `sudo rm /usr/local/share/ca-certificates/halos-ca.crt && sudo update-ca-certificates --fresh`.
- **iOS**: Settings → General → VPN & Device Management → tap the profile → Remove Profile.
- **Firefox**: Preferences → Certificates → View Certificates → Authorities → select → Delete or Distrust.

Subsequent visits to the device will fall back to "Not secure", as if you never installed the CA.
