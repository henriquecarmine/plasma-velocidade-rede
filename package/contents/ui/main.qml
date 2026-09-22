/*
 * Velocidade da Rede — widget de área de trabalho.
 *
 * Um cartão em três faixas: em cima os números atuais (download e upload,
 * lado a lado); no meio o gráfico de 60 s, QUANTITATIVO — escala única
 * "bonita", três linhas de grade rotuladas e uma linha fina no nível atual
 * de cada série; embaixo a identidade da rede: o nome, e no wifi a geração
 * (4/5/6/6E/7), a velocidade nominal e o sinal; no cabo a velocidade do link.
 *
 * Cores: tudo deriva da cor de destaque do sistema. Download é o destaque;
 * upload é uma variação SÓBRIA dele (mesmo tom mais leve, neutro, ou
 * análogo — `paleta`), nunca um matiz oposto brigando com o desktop.
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

    // O script viaja DENTRO do pacote; invocado por `bash <caminho>`, o bit
    // de execução não importa (instaladores descompactam sem permissões).
    readonly property string script: {
        const u = Qt.resolvedUrl("../code/velocidade-rede").toString();
        return u.replace(/^file:\/\//, "");
    }
    function cmd(args) { return "/bin/bash '" + script + "' " + args; }

    // O cartão é desenhado aqui; o fundo padrão do Plasma dobraria a moldura.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // ---- configuração ----------------------------------------------------
    readonly property bool emBits:      Plasmoid.configuration.unidadeBits
    readonly property bool mostrarIp:   Plasmoid.configuration.mostrarIp
    readonly property int  periodoMin:  Plasmoid.configuration.periodoMin   // 30…1440
    readonly property bool modoPeriodo: Plasmoid.configuration.modoPeriodo  // o ícone-relógio

    // ---- tonalidade do sistema -------------------------------------------
    //
    // Escopo de tema PRÓPRIO: no desktop, applet sem fundo recebe o conjunto
    // Complementary, cujo fundo é escuro e translúcido como o wallpaper — o
    // cartão sumia. Lendo do conjunto Window, o cartão é o do esquema de cores.
    Item {
        id: tema
        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
    }
    readonly property color corTexto: tema.Kirigami.Theme.textColor
    readonly property color corFundo: tema.Kirigami.Theme.backgroundColor
    readonly property color corBaixa: tema.Kirigami.Theme.highlightColor

    // Upload: uma variação sóbria do destaque.
    //   0 = mesmo tom, mais leve (ESCOLHA do dono) · 1 = neutro · 2 = análogo
    readonly property int paleta: 0
    readonly property color corSobe: {
        const d = tema.Kirigami.Theme.highlightColor;
        if (root.paleta === 1) return Qt.alpha(tema.Kirigami.Theme.textColor, 0.55);
        if (root.paleta === 2) return Qt.hsla((d.hslHue + 0.91) % 1.0,   // −0,09: rumo ao ciano, não ao violeta
                                             Math.min(1.0, d.hslSaturation * 0.75),
                                             Math.min(0.72, d.hslLightness + 0.08), 1.0);
        return Qt.hsla(d.hslHue, d.hslSaturation * 0.55, Math.min(0.82, d.hslLightness + 0.24), 1.0);
    }

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
        // Inteiro exato sai sem decimal (5 MB/s, não 5,0) — a grade agradece.
        if (v >= 1e6) return Number(v / 1e6).toLocaleString(loc, 'f',
            (v >= 10e6 || Math.abs(v / 1e6 - Math.round(v / 1e6)) < 1e-9) ? 0 : 1);
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

    function taxa(b) { return root.num(b) + " " + root.unid(b); }
    function bytesTexto(b) {
        const loc = Qt.locale();
        if (b >= 1e9) return Number(b / 1e9).toLocaleString(loc, 'f', 1) + " GB";
        if (b >= 1e6) return Number(b / 1e6).toLocaleString(loc, 'f', 0) + " MB";
        if (b >= 1e3) return Number(b / 1e3).toLocaleString(loc, 'f', 0) + " KB";
        return Number(b).toLocaleString(loc, 'f', 0) + " B";
    }
    function periodoTexto() {
        const m = root.periodoMin;
        return m < 60 ? i18nd(root.dom, "%1 min", m) : i18nd(root.dom, "%1 h", m / 60);
    }

    // ---- período: o anel de baldes -----------------------------------------
    //
    // O gráfico de 60 s responde "e agora?"; o período responde "e na última
    // hora / no último dia?". Sem log eterno: são SEMPRE ~240 baldes, seja o
    // período 30 min (um balde a cada 7,5 s) ou 24 h (um a cada 6 min). Cada
    // balde guarda média, pico e bytes de download e upload. O anel vive na
    // configuração do widget (limitado), para um reinício do Plasma não
    // apagar as últimas horas. Trocar o período zera o anel: baldes de
    // tamanhos diferentes não se misturam.
    readonly property int  nBaldes:  240
    readonly property real baldeSeg: root.periodoMin * 60 / root.nBaldes
    property var  anel: []      // [{ad, md, au, mu, bd, bu}] média/pico/bytes
    property real bIni: 0       // início do balde corrente (época, s)
    property real bSd: 0
    property real bSu: 0
    property real bMd: 0
    property real bMu: 0
    property real bSeg: 0
    property bool anelSujo: false

    function fecharBalde(t) {
        const seg = root.bSeg > 0 ? root.bSeg : 1;
        let a = root.anel.slice();
        a.push({ ad: root.bSd / seg, md: root.bMd, au: root.bSu / seg, mu: root.bMu,
                 bd: root.bSd, bu: root.bSu });
        // Baldes perdidos (máquina dormiu, rede sumiu): zeros, para o eixo
        // do tempo continuar honesto.
        const prox = root.bIni + root.baldeSeg;
        let k = Math.floor((t - prox) / root.baldeSeg);
        if (k < 0) k = 0;
        for (let i = 0; i < k && i < root.nBaldes; i++)
            a.push({ ad: 0, md: 0, au: 0, mu: 0, bd: 0, bu: 0 });
        while (a.length > root.nBaldes) a.shift();
        root.anel = a; root.anelSujo = true;
        root.bIni = prox + k * root.baldeSeg;
        root.bSd = 0; root.bSu = 0; root.bMd = 0; root.bMu = 0; root.bSeg = 0;
    }
    function acumular(d, u, dt, t) {
        if (root.bIni === 0) root.bIni = t - (t % root.baldeSeg);
        if (t >= root.bIni + root.baldeSeg) root.fecharBalde(t);
        root.bSd += d * dt; root.bSu += u * dt; root.bSeg += dt;
        if (d > root.bMd) root.bMd = d;
        if (u > root.bMu) root.bMu = u;
    }
    function salvarAnel() {
        if (!root.anelSujo) return;
        Plasmoid.configuration.historico = JSON.stringify({ p: root.periodoMin, ini: root.bIni, a: root.anel });
        root.anelSujo = false;
    }
    function carregarAnel() {
        try {
            const o = JSON.parse(Plasmoid.configuration.historico || "{}");
            if (o && o.p === root.periodoMin && Array.isArray(o.a)) {
                root.anel = o.a.slice(-root.nBaldes);
                root.bIni = o.ini || 0;
            }
        } catch (e) { }
    }
    function zerarAnel() {
        root.anel = []; root.bIni = 0;
        root.bSd = 0; root.bSu = 0; root.bMd = 0; root.bMu = 0; root.bSeg = 0;
        root.anelSujo = true; root.salvarAnel();
    }
    Component.onCompleted: root.carregarAnel()
    onPeriodoMinChanged: if (root.anel.length > 0 || root.bIni > 0) root.zerarAnel()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.salvarAnel() }

    // Estatísticas do período, recalculadas quando o anel muda.
    readonly property var estat: {
        let sd = 0, su = 0, bd = 0, bu = 0, pico = 0;
        const n = root.anel.length;
        for (let i = 0; i < n; i++) {
            const b = root.anel[i];
            sd += b.ad; su += b.au; bd += b.bd; bu += b.bu;
            if (b.md > pico) pico = b.md;
            if (b.mu > pico) pico = b.mu;
        }
        return { medD: n ? sd / n : 0, medU: n ? su / n : 0, totD: bd, totU: bu, pico: pico };
    }

    // ---- escala do gráfico ------------------------------------------------
    //
    // UMA escala para as duas séries, senão o gráfico não é quantitativo: o
    // olho compara alturas, e alturas em escalas diferentes mentem. O teto é
    // um número "bonito" (1, 2, 4, 5, 8, 10 × 10^k) NA UNIDADE EXIBIDA, para
    // as três linhas de grade caírem em rótulos redondos (5 · 10 · 15).
    // Piso de 10 KB/s: a conversa de fundo de uma rede parada ainda desenha
    // textura, em vez de um traço reto no chão.
    function bonito(x) {
        if (x <= 0) return 1;
        const k = Math.pow(10, Math.floor(Math.log(x) / Math.LN10));
        const m = x / k;
        const degraus = [1, 2, 4, 5, 8, 10];
        for (let i = 0; i < degraus.length; i++) if (m <= degraus[i]) return degraus[i] * k;
        return 10 * k;
    }
    readonly property real topo: {
        let m = 10e3;
        if (root.modoPeriodo) {
            if (root.estat.pico > m) m = root.estat.pico;
        } else {
            for (let i = 0; i < histDown.length; i++) if (histDown[i] > m) m = histDown[i];
            for (let i = 0; i < histUp.length;   i++) if (histUp[i]   > m) m = histUp[i];
        }
        const b = root.emBits ? 8 : 1;
        return root.bonito(m * b * 1.05) / b;   // bonito na unidade exibida, guardado em bytes
    }

    function aplicarEstado(saida) {
        // Resposta VAZIA não é "sem rede": é o motor de execução engasgando.
        // Fica o último estado; a ausência de rede chega explícita, "none|…".
        if (saida.indexOf("|") < 0) return;
        const c = saida.split("|");
        root.tipo    = c[0] || "none";
        root.dev     = c[1] || "";
        root.gen     = c[2] || "";
        root.nominal = c[3] || "";
        root.dbm     = c[4] || "";
        root.link    = c[5] || "";
        root.ip      = c[6] || "";
        root.ssid    = c.slice(7).join("|");   // SSID por último: pode ter "|"
    }

    function aplicarTaxa(saida) {
        // Vazio seria lido como contador 0 — e a próxima leitura, um pico
        // de centenas de MB/s. Ignora e espera a seguinte.
        if (saida.indexOf("|") < 0) return;
        const c = saida.split("|");
        const rx = parseFloat(c[0]) || 0, tx = parseFloat(c[1]) || 0;
        const t = Date.now() / 1000;
        if (root.ultRx >= 0 && t > root.ultT) {
            const dt = t - root.ultT;
            // Contador que anda para trás é interface reiniciada.
            const d = Math.max(0, (rx - root.ultRx) / dt);
            const u = Math.max(0, (tx - root.ultTx) / dt);
            root.down = d; root.up = u;
            root.acumular(d, u, dt, t);
            let hd = root.histDown.slice(); hd.push(d);
            if (hd.length > root.nHist) hd.shift(); root.histDown = hd;
            let hu = root.histUp.slice(); hu.push(u);
            if (hu.length > root.nHist) hu.shift(); root.histUp = hu;
        }
        root.ultRx = rx; root.ultTx = tx; root.ultT = t;
    }

    // Trocou de interface: zera as bases, senão a primeira taxa sai como a
    // diferença entre contadores de placas distintas.
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
            // Despacha pelo FLAG exato (prefixo de cmd("") tem tamanho fixo).
            const pref = root.cmd("");
            let flag = "";
            if (source.indexOf(pref) === 0)
                flag = source.substring(pref.length).split(" ")[0];
            if (flag === "--estado")    root.aplicarEstado(saida);
            else if (flag === "--taxa") root.aplicarTaxa(saida);
        }
    }

    // Identidade da rede: devagar, muda pouco. Contadores: a cada segundo —
    // dois arquivos do /sys, e é o que dá vida ao gráfico.
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: exec.connectSource(root.cmd("--estado"))
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: if (root.dev.length > 0) exec.connectSource(root.cmd("--taxa " + root.dev))
    }

    // ---- desenho (Canvas) ------------------------------------------------
    function yDe(v, h, maxV) { return h - Math.min(1, v / maxV) * (h - 2) - 1; }

    // A série: área com degradê e a linha por cima. Ancorada à DIREITA: o
    // agora fica na borda e o passado entra rolando, como num monitor.
    function serie(ctx, w, h, dados, maxV, cor, esp, alfaArea, n) {
        if (dados.length < 2) return;
        const desloc = n - dados.length;
        const p = [];
        for (let i = 0; i < dados.length; i++)
            p.push([(i + desloc) / (n - 1) * w, root.yDe(dados[i], h, maxV)]);
        if (alfaArea > 0) {
            ctx.beginPath();
            ctx.moveTo(p[0][0], p[0][1]);
            for (let i = 1; i < p.length; i++) ctx.lineTo(p[i][0], p[i][1]);
            ctx.lineTo(p[p.length - 1][0], h); ctx.lineTo(p[0][0], h); ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, 0, h);
            g.addColorStop(0, root.rgba(cor, alfaArea));
            g.addColorStop(1, root.rgba(cor, 0.01));
            ctx.fillStyle = g; ctx.fill();
        }
        ctx.beginPath();
        ctx.moveTo(p[0][0], p[0][1]);
        for (let i = 1; i < p.length; i++) ctx.lineTo(p[i][0], p[i][1]);
        ctx.strokeStyle = root.rgba(cor, alfaArea > 0 ? 1 : 0.45); ctx.lineWidth = esp;
        ctx.lineJoin = "round"; ctx.lineCap = "round"; ctx.stroke();
    }

    // A linha fina no NÍVEL ATUAL da série: tracejada, atravessa o gráfico.
    // É a régua que diz "a velocidade de agora está AQUI na escala".
    function marcador(ctx, w, h, v, maxV, cor) {
        const y = Math.round(root.yDe(v, h, maxV)) + 0.5;
        ctx.strokeStyle = root.rgba(cor, 0.7); ctx.lineWidth = 1;
        ctx.beginPath();
        for (let x = 0; x < w; x += 7) { ctx.moveTo(x, y); ctx.lineTo(Math.min(w, x + 4), y); }
        ctx.stroke();
    }

    fullRepresentation: Item {
        id: janela
        // Redimensionável no desktop; o gráfico ocupa o que houver.
        Layout.minimumWidth:    Kirigami.Units.gridUnit * 9
        Layout.minimumHeight:   Kirigami.Units.gridUnit * 5
        Layout.preferredWidth:  Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 13

        // Fator de escala da tipografia: o tamanho atual em relação ao de
        // projeto, pelo MENOR dos dois eixos. Piso para não ficar ilegível,
        // teto para um widget enorme não virar outdoor.
        readonly property real escala: Math.max(0.45, Math.min(3.0,
            Math.min(width  / (Kirigami.Units.gridUnit * 22),
                     height / (Kirigami.Units.gridUnit * 13))))
        readonly property real ptPeq: Math.max(6, Kirigami.Theme.smallFont.pointSize * escala)

        Kirigami.ShadowedRectangle {
            id: cartao
            // O conjunto Window para TUDO que está dentro: os rótulos sem cor
            // explícita herdam o par fundo/texto certo em tema claro ou escuro.
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

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Math.max(Kirigami.Units.smallSpacing,
                                          Kirigami.Units.largeSpacing * janela.escala)
                spacing: Kirigami.Units.smallSpacing * janela.escala

                // ---- faixa 1: os números, lado a lado, FORA do gráfico ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing * 1.5 * janela.escala

                    Repeater {
                        model: [
                            { seta: "↓", val: root.down, cor: root.corBaixa },
                            { seta: "↑", val: root.up,   cor: root.corSobe }
                        ]
                        delegate: RowLayout {
                            spacing: Kirigami.Units.smallSpacing * janela.escala
                            PlasmaComponents.Label {
                                text: modelData.seta
                                color: modelData.cor
                                font.pointSize: 15 * janela.escala
                            }
                            PlasmaComponents.Label {
                                text: root.num(modelData.val)
                                color: modelData.cor
                                font.pointSize: 22 * janela.escala
                                font.weight: Font.DemiBold
                            }
                            PlasmaComponents.Label {
                                text: root.unid(modelData.val)
                                font.pointSize: janela.ptPeq
                                opacity: 0.7
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 4 * janela.escala
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }

                    // O ícone pequenino: liga/desliga a vista do período.
                    PlasmaComponents.ToolButton {
                        id: btnPeriodo
                        icon.name: "view-history"
                        checkable: true
                        flat: true
                        implicitWidth:  Kirigami.Units.iconSizes.small * 1.7 * janela.escala
                        implicitHeight: implicitWidth
                        opacity: checked ? 1 : 0.55
                        onToggled: Plasmoid.configuration.modoPeriodo = checked
                        PlasmaComponents.ToolTip.visible: hovered
                        PlasmaComponents.ToolTip.text: checked
                            ? i18nd(root.dom, "Last %1 — click for live", root.periodoTexto())
                            : i18nd(root.dom, "Live (60 s) — click for the last %1", root.periodoTexto())
                    }
                    // Mantém o botão sincronizado com a configuração mesmo depois
                    // de um clique (o clique quebraria um binding simples).
                    Binding { btnPeriodo.checked: root.modoPeriodo }
                }

                // ---- faixa 2: o gráfico, com grade rotulada e marcadores --
                Item {
                    id: area
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Kirigami.Units.gridUnit * 2

                    Canvas {
                        id: grafico
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const w = width, h = height, topo = root.topo;
                            // Grade: três linhas finas (¼, ½, ¾ da escala).
                            ctx.strokeStyle = root.rgba(root.corTexto, 0.10); ctx.lineWidth = 1;
                            for (let i = 1; i <= 3; i++) {
                                const y = Math.round(root.yDe(topo * i / 4, h, topo)) + 0.5;
                                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
                            }
                            const esp = Math.max(1.2, 2 * janela.escala);
                            if (root.modoPeriodo) {
                                // O período: média por balde com área, pico como
                                // contorno fino por cima, e a tracejada na MÉDIA
                                // do período inteiro.
                                const a = root.anel, n = root.nBaldes;
                                const ad = a.map(function (b) { return b.ad; }), md = a.map(function (b) { return b.md; });
                                const au = a.map(function (b) { return b.au; }), mu = a.map(function (b) { return b.mu; });
                                root.serie(ctx, w, h, md, topo, root.corBaixa, 1, 0, n);
                                root.serie(ctx, w, h, mu, topo, root.corSobe,  1, 0, n);
                                root.serie(ctx, w, h, ad, topo, root.corBaixa, esp, 0.30, n);
                                root.serie(ctx, w, h, au, topo, root.corSobe,  esp, 0.16, n);
                                if (a.length > 1) {
                                    root.marcador(ctx, w, h, root.estat.medD, topo, root.corBaixa);
                                    root.marcador(ctx, w, h, root.estat.medU, topo, root.corSobe);
                                }
                            } else {
                                root.serie(ctx, w, h, root.histDown, topo, root.corBaixa, esp, 0.30, root.nHist);
                                root.serie(ctx, w, h, root.histUp,   topo, root.corSobe,  esp, 0.16, root.nHist);
                                if (root.histDown.length > 1) root.marcador(ctx, w, h, root.down, topo, root.corBaixa);
                                if (root.histUp.length   > 1) root.marcador(ctx, w, h, root.up,   topo, root.corSobe);
                            }
                        }
                        Connections {
                            target: root
                            function onHistUpChanged() { grafico.requestPaint(); }
                            function onAnelChanged() { grafico.requestPaint(); }
                            function onModoPeriodoChanged() { grafico.requestPaint(); }
                            function onEmBitsChanged() { grafico.requestPaint(); }
                        }
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                    }

                    // Rótulos da grade, encostados à direita, em cima da linha.
                    // Somem quando o widget é pequeno demais para lê-los.
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            required property int index
                            readonly property real fracao: (index + 1) / 4
                            visible: janela.escala >= 0.6
                                     && (root.modoPeriodo ? root.anel.length > 1 : root.histDown.length > 1)
                            // Fundo da cor do cartão: a tracejada e as séries não
                            // atravessam o texto.
                            color: Qt.alpha(root.corFundo, 0.8)
                            radius: 3
                            width: rotGrade.implicitWidth + 6
                            height: rotGrade.implicitHeight + 2
                            anchors.right: parent.right
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            y: Math.round(root.yDe(root.topo * fracao, area.height, root.topo)) - height - 1
                            PlasmaComponents.Label {
                                id: rotGrade
                                anchors.centerIn: parent
                                text: root.num(root.topo * fracao) + " " + root.unid(root.topo * fracao)
                                font.pointSize: Math.max(6, janela.ptPeq * 0.9)
                                opacity: 0.55
                            }
                        }
                    }

                    // A etiqueta do período: média e total, no canto do gráfico.
                    Rectangle {
                        visible: root.modoPeriodo && janela.escala >= 0.6
                        color: Qt.alpha(root.corFundo, 0.8)
                        radius: 3
                        width: colEtiq.implicitWidth + 8
                        height: colEtiq.implicitHeight + 4
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: Kirigami.Units.smallSpacing
                        ColumnLayout {
                            id: colEtiq
                            anchors.centerIn: parent
                            spacing: 0
                            PlasmaComponents.Label {
                                text: i18nd(root.dom, "%1 · avg ↓ %2  ↑ %3", root.periodoTexto(),
                                            root.taxa(root.estat.medD), root.taxa(root.estat.medU))
                                font.pointSize: Math.max(6, janela.ptPeq * 0.9)
                                opacity: 0.75
                            }
                            PlasmaComponents.Label {
                                text: i18nd(root.dom, "total ↓ %1  ↑ %2",
                                            root.bytesTexto(root.estat.totD), root.bytesTexto(root.estat.totU))
                                font.pointSize: Math.max(6, janela.ptPeq * 0.9)
                                opacity: 0.55
                            }
                        }
                    }
                }

                // ---- faixa 3: quem é a rede ------------------------------
                RowLayout {
                    id: rodape
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * janela.escala

                    Kirigami.Icon {
                        source: root.tipo === "cabo" ? "network-wired-symbolic"
                              : root.tipo === "wifi" ? "network-wireless-symbolic"
                              : "network-disconnect-symbolic"
                        color: root.tipo === "none" ? root.corTexto : root.corBaixa
                        opacity: root.tipo === "none" ? 0.5 : 1
                        Layout.preferredWidth:  Kirigami.Units.iconSizes.small * janela.escala
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small * janela.escala
                    }
                    PlasmaComponents.Label {
                        text: root.textoInfo()
                        font.pointSize: janela.ptPeq
                        opacity: 0.65
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }
                    PlasmaComponents.Label {
                        visible: root.tipo === "wifi" && root.dbm.length > 0
                        text: i18nd(root.dom, "%1 dBm", root.dbm)
                        font.pointSize: janela.ptPeq
                        opacity: 0.65
                    }
                }
            }
        }
    }
}
