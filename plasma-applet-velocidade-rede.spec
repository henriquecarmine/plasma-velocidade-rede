%global plasmoid_id com.henrique.velocidaderede

# NÃO grampear a mtime dos arquivos na data do changelog: o cache de QML do
# Qt decide se está velho olhando a mtime do fonte, e dois pacotes do mesmo
# dia chegariam com a MESMA mtime — o Plasma continuaria rodando o QML antigo.
%global clamp_mtime_to_source_date_epoch 0

Name:           plasma-applet-velocidade-rede
Version:        1.0.0
Release:        1%{?dist}
Summary:        Plasma desktop widget with live network speed chart and network info

License:        MIT
URL:            https://github.com/henriquecarmine/plasma-velocidade-rede
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  coreutils

# Geração/nominal/sinal vêm do kernel via `iw`; a rota padrão e o IP via `ip`.
Requires:       iw
Requires:       iproute
Requires:       bash
Requires:       plasma-workspace >= 6.0

%description
A desktop widget that draws download and upload speed as a live running chart
in the system accent colour, with the current speeds on top and the network
identity underneath: the network name; on Wi-Fi the generation (4/5/6/6E/7),
the negotiated link speed and the signal; on cable the link speed
(100/1000/10000). Units switchable between MB/s and Mb/s.

Available in English, Portuguese (Brazil), Spanish and French.

%prep
%setup -q

%install
install -d %{buildroot}%{_datadir}/plasma/plasmoids/%{plasmoid_id}
cp -a %{plasmoid_id}/. %{buildroot}%{_datadir}/plasma/plasmoids/%{plasmoid_id}/
chmod 0755 %{buildroot}%{_datadir}/plasma/plasmoids/%{plasmoid_id}/contents/code/velocidade-rede
rm -f %{buildroot}%{_datadir}/plasma/plasmoids/%{plasmoid_id}/LICENSE
rm -f %{buildroot}%{_datadir}/plasma/plasmoids/%{plasmoid_id}/README.md

%files
%license %{plasmoid_id}/LICENSE
%doc %{plasmoid_id}/README.md
%{_datadir}/plasma/plasmoids/%{plasmoid_id}/

%changelog
* Tue Sep 22 2026 Henrique Carmine <henriquecarmine@gmail.com> - 1.0.0-1
- First public release. Desktop widget with a live 60 s dual-area chart
  (download/upload) in the system accent colour; current speeds in their own
  band above the chart; a quantitative chart with a single "nice" scale, three
  labelled grid lines and a thin dashed line at each series' current level.
- Period view behind a small clock toggle: the last 30 min / 1 / 2 / 4 / 6 / 12
  / 24 h as 240 buckets (average, peak, bytes), persisted in the widget's own
  configuration — bounded by construction, never an ever-growing log. Shows the
  period average as the dashed lines and the total transferred.
- Network line: name; on Wi-Fi the generation (4/5/6/6E/7, read from the
  kernel via iw), the negotiated link speed and the signal; on cable the link
  speed (100/1000/10000). Follows the default-route interface automatically.
- Unit selectable (MB/s or Mb/s); everything scales with the widget size.
- Portuguese (Brazil), Spanish and French translations.

* Mon Sep 21 2026 Henrique Carmine <henriquecarmine@gmail.com> - 0.1.0-1
- First release. Live dual-area chart (download/upload) in the system accent
  colour, auto-scaled per series; big current numbers; network identity line:
  name, Wi-Fi generation (4/5/6/6E/7), negotiated speed and signal, or cable
  link speed (100/1000/10000). Unit selectable (MB/s or Mb/s). Follows the
  default-route interface automatically (cable or Wi-Fi).
