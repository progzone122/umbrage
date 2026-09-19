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

            UInputField {
                Layout.fillWidth: true
                title: "Version name"
                placeholder: "Carbonara Exploit / Unlocked BL / Official Signed Flashing"
                value: root.version.da ? root.version.da : ""
            }

            UInputField {
                Layout.fillWidth: true
                title: "Version description"
                placeholder: "Enter a few words about this files. Are there any restrictions?"
                value: root.version.auth ? root.version.auth : ""
            }

            RowLayout {
                UChooserField {
                    Layout.fillWidth: true
                    title: "DA"
                    icon: "qrc:/assets/da_icon.svg"
                    value: root.version.da ? root.version.da : "dsfdsfds"
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
