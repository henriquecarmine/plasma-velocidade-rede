# Network Speed — Plasma desktop widget

Live download and upload speed for the KDE Plasma 6 desktop, drawn as a running
chart in the **system accent colour**, with the network identity underneath.

- **Chart:** dual area (download / upload), sixty seconds of history, each series
  auto-scaled so both stay readable whatever the magnitude.
- **Numbers:** current download and upload, big. Unit selectable: **MB/s**
  (bytes) or **Mb/s** (bits).
- **Network line:** the network name; on **Wi-Fi** the generation
  (4 / 5 / 6 / 6E / 7), the negotiated link speed (e.g. `576/432 Mb/s`) and the
  signal in dBm; on **cable** the link speed (`100` / `1000` / `10000 Mb/s`).
- Follows the interface of the default route automatically (cable or Wi-Fi),
  and falls back to any port with a carrier.
- Colours derive from the theme: download is the accent; upload is the accent
  with its hue turned — it harmonises with whatever accent you pick.

The Wi-Fi generation is read from the kernel (nl80211, via `iw`) — it is not
exposed by NetworkManager.

## Requirements

`iw`, `iproute`, `bash`, Plasma 6.

## Build

```
./build.sh
```

Produces `dist/velocidade-rede.plasmoid` (KDE Store) and the source tarball for
`rpmbuild -ba plasma-applet-velocidade-rede.spec`.

## Sibling project

[Wi-Fi Generation](../plasma-wifi-generation) — the system-tray applet this
widget grew out of.

MIT License.
