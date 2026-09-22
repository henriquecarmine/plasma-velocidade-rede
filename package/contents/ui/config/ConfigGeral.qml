/*
 * Página de configuração: a unidade (bytes ou bits), o período do histórico
 * e se o IP aparece. As propriedades `cfg_*` são o contrato com o main.xml.
 */
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: pagina
    readonly property string dom: "plasma_applet_com.henrique.velocidaderede"

    property alias cfg_unidadeBits: rbBits.checked
    property alias cfg_mostrarIp:   chkIp.checked
    property int   cfg_periodoMin

    readonly property var periodos: [
        { texto: i18nd(pagina.dom, "%1 min", 30), valor: 30 },
        { texto: i18nd(pagina.dom, "%1 h", 1),    valor: 60 },
        { texto: i18nd(pagina.dom, "%1 h", 2),    valor: 120 },
        { texto: i18nd(pagina.dom, "%1 h", 4),    valor: 240 },
        { texto: i18nd(pagina.dom, "%1 h", 6),    valor: 360 },
        { texto: i18nd(pagina.dom, "%1 h", 12),   valor: 720 },
        { texto: i18nd(pagina.dom, "%1 h", 24),   valor: 1440 }
    ]

    Kirigami.FormLayout {
        QQC2.ButtonGroup { id: grupoUnidade }

        QQC2.RadioButton {
            id: rbBytes
            Kirigami.FormData.label: i18nd(pagina.dom, "Unit:")
            text: i18nd(pagina.dom, "MB/s — megabytes per second")
            QQC2.ButtonGroup.group: grupoUnidade
            checked: !rbBits.checked
        }
        QQC2.RadioButton {
            id: rbBits
            text: i18nd(pagina.dom, "Mb/s — megabits per second")
            QQC2.ButtonGroup.group: grupoUnidade
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: cbPeriodo
            Kirigami.FormData.label: i18nd(pagina.dom, "History:")
            model: pagina.periodos
            textRole: "texto"
            currentIndex: {
                for (let i = 0; i < pagina.periodos.length; i++)
                    if (pagina.periodos[i].valor === pagina.cfg_periodoMin) return i;
                return 1;
            }
            onActivated: pagina.cfg_periodoMin = pagina.periodos[currentIndex].valor
        }
        QQC2.Label {
            text: i18nd(pagina.dom, "The clock icon on the widget shows this period. Changing it clears the history.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: chkIp
            Kirigami.FormData.label: i18nd(pagina.dom, "Details:")
            text: i18nd(pagina.dom, "Show the IP address")
        }
    }
}
