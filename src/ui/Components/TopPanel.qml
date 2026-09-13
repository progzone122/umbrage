import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import umbrage
import UmbrageStyles 1.0
import Components 1.0

RowLayout {
    id: root

    property bool show_step_badges: true

    spacing: Styles.spacing

    Row {
        visible: root.show_step_badges
        spacing: Styles.spacing

        UButton {
            iconPath: "qrc:/assets/da_icon.svg"
            iconDisplay: Button.TextBesideIcon
            text: AppState.da_file.split('/').pop()
            onClicked: console.log(AppState.da_file + " IS CLICKED!")
        }

        UButton {
            iconPath: "qrc:/assets/auth_icon.svg"
            iconDisplay: Button.TextBesideIcon
            text: AppState.auth_file.split('/').pop()
            onClicked: console.log(AppState.auth_file + " IS CLICKED!")
        }

        UButton {
            iconPath: "qrc:/assets/preloader_icon.svg"
            iconDisplay: Button.TextBesideIcon
            text: AppState.preloader_file.split('/').pop()
            onClicked: console.log(AppState.preloader_file + " IS CLICKED!")
        }
    }

    Item {
        Layout.fillWidth: true
    }
}
