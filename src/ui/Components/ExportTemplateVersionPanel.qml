import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import umbrage
import UmbrageStyles 1.0
import UmbrageUtils 1.0
import Components 1.0

Item {
    id: root

    // { name, description, da, auth, preloader, default }
    property var version: ({})

    signal backRequested

    Layout.fillWidth: true
    Layout.fillHeight: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: Styles.spacing / 2

        color: Styles.surface
        radius: Styles.radiusMedium
        border.width: 4
        border.color: Styles.surface

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Styles.spacing
            spacing: Styles.spacing

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Styles.spacing

                UButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48

                    text: "◀ "
                    backgroundColor: Styles.surfaceHigh
                    radius: width / 2

                    onClicked: root.backRequested()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                UText {
                    Layout.fillWidth: true
                    level: "title"
                    text: root.version.name ? root.version.name : ""
                }

                UText {
                    Layout.fillWidth: true
                    level: "body"
                    color: Styles.surfaceForeground
                    text: root.version.description ? root.version.description : ""
                }
            }

            UInputField {
                Layout.fillWidth: true
                title: "Download Agent (DA)"
                placeholder: "/path/to/da.bin"
                value: root.version.da ? root.version.da : ""
            }

            UInputField {
                Layout.fillWidth: true
                title: "Auth file"
                placeholder: "/path/to/auth.bin"
                value: root.version.auth ? root.version.auth : ""
            }

            UInputField {
                Layout.fillWidth: true
                title: "Preloader"
                placeholder: "/path/to/preloader.bin"
                value: root.version.preloader ? root.version.preloader : ""
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
