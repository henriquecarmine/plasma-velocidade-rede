/*
 * Velocidade da Rede — widget de área de trabalho.
 *
 * Um cartão com o gráfico de área dupla correndo em tempo real (download e
 * upload), os números grandes por cima, e embaixo o que identifica a rede: o
 * nome; no wifi a geração (4/5/6/6E/7), a velocidade nominal negociada e o
 * sinal; no cabo a velocidade do link (100/1000/10000).
 *
 * Cores: TUDO deriva da cor de destaque do sistema. Download usa o destaque
 * puro; upload usa o destaque com o matiz girado — harmoniza com qualquer cor
 * que a pessoa escolha no tema, sem uma paleta própria brigando com o desktop.
 *
 * TODA string visível passa por i18nd. O script emite tokens, nunca prosa.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string dom: "plasma_applet_com.henrique.velocidaderede"

    // O script viaja DENTRO do pacote; o caminho se resolve em tempo de
    // execução. Invocado por `bash <caminho>`: o bit de execução não importa
    // (instaladores de plasmoid descompactam sem preservar permissões).
    readonly property string script: {
        const u = Qt.resolvedUrl("../code/velocidade-rede").toString();
        return u.replace(/^file:\/\//, "");
    }
    function cmd(args) { return "/bin/bash '" + script + "' " + args; }

    // O cartão é desenhado aqui; o fundo padrão do Plasma dobraria a moldura.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // ---- configuração ----------------------------------------------------
    readonly property bool emBits:    Plasmoid.configuration.unidadeBits
    readonly property bool mostrarIp: Plasmoid.configuration.mostrarIp

    // ---- tonalidade do sistema -------------------------------------------
    //
    // Um item só para ter um escopo de tema PRÓPRIO. No desktop, applet sem
    // fundo recebe o conjunto Complementary (texto claro sobre wallpaper) — e
    // o FUNDO desse conjunto é escuro e translúcido, igual ao wallpaper: o
    // cartão desaparecia e sobrava número solto sobre o papel de parede.
    // Lendo do conjunto Window, o cartão é o cartão do esquema de cores.
    Item {
        id: tema
        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
    }
    readonly property color corBaixa: tema.Kirigami.Theme.highlightColor
    readonly property color corSobe: Qt.hsla(
        (tema.Kirigami.Theme.highlightColor.hslHue + 0.42) % 1.0,
        Math.min(1.0, tema.Kirigami.Theme.highlightColor.hslSaturation * 0.9),
        Math.min(0.72, tema.Kirigami.Theme.highlightColor.hslLightness + 0.10), 1.0)
    readonly property color corTexto: tema.Kirigami.Theme.textColor
    readonly property color corFundo: tema.Kirigami.Theme.backgroundColor

    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255)
             + "," + Math.round(c.b * 255) + "," + a + ")";
    }

    // ---- estado da rede (do --estado) -----------------------------------
    property string tipo:    "none"   // none | wifi | cabo
    property string dev:     ""
    property string gen:     ""       // 4 | 5 | 6 | 6E | 7 | abg | ""
    property string nominal: ""       // "576/432" (rx/tx negociados, Mb/s)
    property string dbm:     ""
    property string link:    ""       // "1000" no cabo
    property string ip:      ""
    property string ssid:    ""

    // ---- taxas (do --taxa) ----------------------------------------------
    property real down: 0
    property real up:   0
    property var  histDown: []
    property var  histUp:   []
    readonly property int nHist: 60
    property real ultRx: -1
    property real ultTx: -1
    property real ultT:  0

    function textoGen() {
        switch (root.gen) {
        case "7":   return i18nd(root.dom, "Wi-Fi 7");
        case "6E":  return i18nd(root.dom, "Wi-Fi 6E");
        case "6":   return i18nd(root.dom, "Wi-Fi 6");
        case "5":   return i18nd(root.dom, "Wi-Fi 5");
        case "4":   return i18nd(root.dom, "Wi-Fi 4");
        case "abg": return "802.11 a/b/g";
        default:    return "";
        }
    }

    // Número e unidade separados: tipografia grande no número, pequena na
    // unidade. Bytes ou bits conforme a configuração.
    function num(b) {
        const loc = Qt.locale();
        const v = root.emBits ? b * 8 : b;
        if (v >= 1e6) return Number(v / 1e6).toLocaleString(loc, 'f', 1);
        if (v >= 1e3) return Number(v / 1e3).toLocaleString(loc, 'f', 0);
        return Number(v).toLocaleString(loc, 'f', 0);
    }
    function unid(b) {
        const v = root.emBits ? b * 8 : b, s = root.emBits ? "b" : "B";
        return v >= 1e6 ? "M" + s + "/s" : (v >= 1e3 ? "K" + s + "/s" : s + "/s");
    }

    // A linha de identificação da rede, embaixo do gráfico.
    function textoInfo() {
        if (root.tipo === "wifi") {
            if (root.ssid.length === 0) return i18nd(root.dom, "Wi-Fi not connected");
            let s = root.ssid;
            const g = root.textoGen();
            if (g.length > 0) s += "  ·  " + g;
            if (root.nominal.length > 0 && root.nominal !== "0/0")
                s += "  ·  " + i18nd(root.dom, "%1 Mb/s", root.nominal);
            if (root.mostrarIp && root.ip.length > 0) s += "  ·  " + root.ip;
            return s;
        }
        if (root.tipo === "cabo") {
            let s = root.dev;
            if (root.link.length > 0) s += "  ·  " + i18nd(root.dom, "%1 Mb/s", root.link);
            if (root.mostrarIp && root.ip.length > 0) s += "  ·  " + root.ip;
            return s;
        }
        return i18nd(root.dom, "No network");
    }

    // Escala AUTOMÁTICA por série: o maior valor recente, com um piso. Sem o
    // piso, uma rede parada vira ruído amplificado até o teto; sem a escala,
    // 100 MB/s de download achatariam 1 MB/s de upload a uma linha reta.
    function maxDe(h) {
        // Piso de 10 KB/s: a conversa de fundo de uma rede "parada" (1–3
        // KB/s) ainda desenha textura no terço de baixo — o gráfico é a
        // identidade deste widget, e um traço reto no chão o descaracteriza.
        // Com tráfego de verdade a escala cresce e o chão achata, como deve.
        let m = 10e3;
        for (let i = 0; i < h.length; i++) if (h[i] > m) m = h[i];
        return m * 1.08;
    }

    function aplicarEstado(saida) {
        // Resposta VAZIA não é "sem rede": é o motor de execução engasgando
        // (acontece no primeiro quadro). Fica o último estado conhecido; a
        // ausência de rede de verdade chega explícita, como "none|…".
        if (saida.indexOf("|") < 0) return;
        const c = saida.split("|");
        root.tipo    = c[0] || "none";
        root.dev     = c[1] || "";
        root.gen     = c[2] || "";
        root.nominal = c[3] || "";
        root.dbm     = c[4] || "";
        root.link    = c[5] || "";
        root.ip      = c[6] || "";
        // SSID por último: pode ter "|", junta o resto.
        root.ssid    = c.slice(7).join("|");
    }

    function aplicarTaxa(saida) {
        // Vazio aqui seria lido como contador 0 — e a leitura seguinte
        // viraria um pico de centenas de MB/s. Ignora e espera a próxima.
        if (saida.indexOf("|") < 0) return;
        const c = saida.split("|");
        const rx = parseFloat(c[0]) || 0, tx = parseFloat(c[1]) || 0;
        const t = Date.now() / 1000;
        if (root.ultRx >= 0 && t > root.ultT) {
            const dt = t - root.ultT;
            // Contador que anda para trás é interface reiniciada, não tráfego
            // negativo.
            const d = Math.max(0, (rx - root.ultRx) / dt);
            const u = Math.max(0, (tx - root.ultTx) / dt);
            root.down = d; root.up = u;
            let hd = root.histDown.slice(); hd.push(d);
            if (hd.length > root.nHist) hd.shift(); root.histDown = hd;
            let hu = root.histUp.slice(); hu.push(u);
            if (hu.length > root.nHist) hu.shift(); root.histUp = hu;
        }
        root.ultRx = rx; root.ultTx = tx; root.ultT = t;
    }

    // Trocou de interface (cabo entrou, wifi caiu): zera as bases, senão a
    // primeira taxa sai como a diferença entre contadores de placas distintas.
    onDevChanged: {
        root.ultRx = -1; root.ultTx = -1;
        root.histDown = []; root.histUp = [];
        root.down = 0; root.up = 0;
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            const saida = (data["stdout"] || "").trim();
            disconnectSource(source);
            // Despacha pelo FLAG exato (o prefixo de cmd("") tem tamanho
            // fixo), imune ao conteúdo dos argumentos.
            const pref = root.cmd("");
            let flag = "";
            if (source.indexOf(pref) === 0)
                flag = source.substring(pref.length).split(" ")[0];
            if (flag === "--estado")    root.aplicarEstado(saida);
            else if (flag === "--taxa") root.aplicarTaxa(saida);
        }
    }

    // Identidade da rede: devagar, muda pouco. Contadores: a cada segundo —
    // é uma leitura de dois arquivos do /sys, e é o que dá vida ao gráfico.
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: exec.connectSource(root.cmd("--estado"))
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: if (root.dev.length > 0) exec.connectSource(root.cmd("--taxa " + root.dev))
    }

    // ---- desenho da série (Canvas) ----------------------------------------
    function linha(ctx, w, h, dados, maxV, cor, esp) {
        if (dados.length < 2) return;
        // Ancorado à DIREITA: o agora fica na borda direita e o passado entra
        // rolando para a esquerda, como num monitor de atividade. Ancorado à
        // esquerda, o primeiro minuto era um toco no canto crescendo devagar.
        const desloc = root.nHist - dados.length;
        const pontos = [];
        for (let i = 0; i < dados.length; i++) {
            pontos.push([(i + desloc) / (root.nHist - 1) * w,
                         h - Math.min(1, dados[i] / maxV) * (h - 3) - 1.5]);
        }
        // Área com degradê, depois a linha por cima.
        ctx.beginPath();
        ctx.moveTo(pontos[0][0], pontos[0][1]);
        for (let i = 1; i < pontos.length; i++) ctx.lineTo(pontos[i][0], pontos[i][1]);
        ctx.lineTo(pontos[pontos.length - 1][0], h); ctx.lineTo(pontos[0][0], h); ctx.closePath();
        const g = ctx.createLinearGradient(0, 0, 0, h);
        g.addColorStop(0, root.rgba(cor, 0.42));
        g.addColorStop(1, root.rgba(cor, 0.02));
        ctx.fillStyle = g; ctx.fill();
        ctx.beginPath();
        ctx.moveTo(pontos[0][0], pontos[0][1]);
        for (let i = 1; i < pontos.length; i++) ctx.lineTo(pontos[i][0], pontos[i][1]);
        ctx.strokeStyle = root.rgba(cor, 1); ctx.lineWidth = esp;
        ctx.lineJoin = "round"; ctx.lineCap = "round"; ctx.stroke();
    }

    fullRepresentation: Item {
        id: janela
        // Redimensionável no desktop; o gráfico ocupa o que houver.
        Layout.minimumWidth:    Kirigami.Units.gridUnit * 14
        Layout.minimumHeight:   Kirigami.Units.gridUnit * 8
        Layout.preferredWidth:  Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 13

        Kirigami.ShadowedRectangle {
            // O mesmo conjunto Window para TUDO que está dentro: os rótulos
            // sem cor explícita herdam daqui, e ficam legíveis sobre o cartão
            // em esquema claro ou escuro.
            Kirigami.Theme.inherit: false
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            radius: Kirigami.Units.cornerRadius * 2
            color: Qt.alpha(root.corFundo, 0.92)
            border.width: 1
            border.color: Qt.alpha(root.corTexto, 0.14)
            shadow.size: Kirigami.Units.largeSpacing * 2
            shadow.color: Qt.rgba(0, 0, 0, 0.35)
            clip: true

            Canvas {
                id: grafico
                anchors.fill: parent
                anchors.topMargin: Kirigami.Units.smallSpacing
                anchors.bottomMargin: rodape.height + Kirigami.Units.largeSpacing * 1.5
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    // Grade discreta: quatro faixas.
                    ctx.strokeStyle = root.rgba(root.corTexto, 0.06); ctx.lineWidth = 1;
                    for (let i = 1; i < 4; i++) {
                        const y = height * i / 4;
                        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                    }
                    root.linha(ctx, width, height, root.histDown, root.maxDe(root.histDown), root.corBaixa, 2.2);
                    root.linha(ctx, width, height, root.histUp,   root.maxDe(root.histUp),   root.corSobe,  2.2);
                }
                Connections {
                    target: root
                    function onHistUpChanged() { grafico.requestPaint(); }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // Os números, por cima do gráfico.
            ColumnLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: 0

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.Label { text: "↓"; font.pointSize: 18; color: root.corBaixa }
                    PlasmaComponents.Label {
                        text: root.num(root.down)
                        font.pointSize: 26; font.weight: Font.DemiBold; color: root.corBaixa
                    }
                    PlasmaComponents.Label {
                        text: root.unid(root.down)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.7
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 6
                    }
                }
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.Label { text: "↑"; font.pointSize: 13; color: root.corSobe }
                    PlasmaComponents.Label {
                        text: root.num(root.up)
                        font.pointSize: 17; font.weight: Font.DemiBold; color: root.corSobe
                    }
                    PlasmaComponents.Label {
                        text: root.unid(root.up)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.7
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 3
                    }
                }
            }

            // Rodapé: quem é a rede.
            RowLayout {
                id: rodape
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: root.tipo === "cabo" ? "network-wired-symbolic"
                          : root.tipo === "wifi" ? "network-wireless-symbolic"
                          : "network-disconnect-symbolic"
                    color: root.tipo === "none" ? root.corTexto : root.corBaixa
                    opacity: root.tipo === "none" ? 0.5 : 1
                    Layout.preferredWidth:  Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                PlasmaComponents.Label {
                    text: root.textoInfo()
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.65
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
                PlasmaComponents.Label {
                    visible: root.tipo === "wifi" && root.dbm.length > 0
                    text: i18nd(root.dom, "%1 dBm", root.dbm)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.65
                }
            }
        }
    }
}
