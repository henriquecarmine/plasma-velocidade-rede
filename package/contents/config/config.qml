import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18nd("plasma_applet_com.henrique.velocidaderede", "General")
        icon: "preferences-system-network"
        source: "config/ConfigGeral.qml"
    }
}
