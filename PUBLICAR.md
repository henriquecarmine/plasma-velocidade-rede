# Publicar no store.kde.org

**Categoria:** Plasma 6 Add-Ons → Plasma Widgets
**Licença:** MIT
**Arquivo a enviar:** `dist/velocidade-rede.plasmoid` (também anexado no
[release v1.0.0](https://github.com/henriquecarmine/plasma-velocidade-rede/releases/tag/v1.0.0))
**Repositório:** https://github.com/henriquecarmine/plasma-velocidade-rede
**Logo:** `artwork/logo.png` (512) · `artwork/logo-256.png`
**Capturas:** `screenshots/01-live.png` · `screenshots/02-period.png` (em inglês, de propósito: a loja é internacional)

O arquivo **não leva versão no nome**: a loja lê a versão do `metadata.json`.

## O passo que só você pode dar

O envio é pela página da loja, **com login** (e-mail e senha, não o botão do
Google — o login social escolhe a conta `cesar.school` sozinho).

1. https://store.kde.org → *Add Product* → **Plasma 6 Add-Ons → Plasma Widgets**.
2. Colar os textos abaixo.
3. Enviar o `.plasmoid`, o logo e as duas capturas.
4. Em *Links*: o repositório e o release.

## Textos (colar como estão)

**Title**

    Network Speed

**Summary**

    Live network speed chart for the desktop, in your accent colour — with the Wi-Fi generation, negotiated speed and signal, and a bounded period view.

**Description**

    A desktop widget for KDE Plasma 6 that draws your download and upload speed as a live running chart, coloured with your system accent — download in the accent itself, upload in the same hue, lighter.

    **What you see**
    - The current download and upload, big, in their own band above the chart.
    - A 60-second chart with a single scale for both series, three labelled grid lines, and a thin dashed line at each series' current level — so the chart is a gauge, not just a shape.
    - Under the chart, the network identity: the network name; on Wi-Fi the generation (4 / 5 / 6 / 6E / 7 — read from the kernel via iw, since NetworkManager does not expose it), the negotiated link speed (e.g. 576/432 Mb/s) and the signal in dBm; on cable, the link speed (100 / 1000 / 10000 Mb/s).

    **The period view**
    A small clock icon switches the chart to the last 30 min, 1, 2, 4, 6, 12 or 24 hours: average per bucket as the area, peaks as a thin outline, the period average as the dashed lines, and the total transferred. The history is 240 buckets kept in the widget's own configuration — bounded by construction, never an ever-growing log — and it survives a Plasma restart.

    **Details**
    - Follows the default-route interface automatically (cable or Wi-Fi).
    - Unit selectable: MB/s (bytes) or Mb/s (bits).
    - Everything scales with the widget size.
    - Reads counters from /sys once a second; no daemon, no root.
    - English, Portuguese (Brazil), Spanish and French.

    Requires `iw` and `iproute` (both standard). Sibling project: Wi-Fi Generation, a system-tray applet by the same author.

**Tags**

    network, speed, bandwidth, monitor, download, upload, wifi, ethernet, chart, plasma6

## Capturas: como foram feitas

Renders reais (`plasmawindowed` + `spectacle -a`) com tráfego real limitado —
download a 3 MB/s e upload a 1,5 MB/s — e, para a vista do período, um anel
de 1 h injetado na configuração. Em inglês via `LANGUAGE=en_US`.
