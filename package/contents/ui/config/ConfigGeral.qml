/*
 * Página de configuração: a unidade (bytes ou bits) e se o IP aparece.
 * As propriedades `cfg_*` são o contrato do Plasma com o main.xml.
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

        QQC2.CheckBox {
            id: chkIp
            Kirigami.FormData.label: i18nd(pagina.dom, "Details:")
            text: i18nd(pagina.dom, "Show the IP address")
        }
    }
}
