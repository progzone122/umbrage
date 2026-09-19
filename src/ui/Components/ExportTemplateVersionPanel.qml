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
                value: root.version.name ? root.version.name : ""
                onValueChanged: root.version.name = value
            }

            UInputField {
                Layout.fillWidth: true
                title: "Version description"
                placeholder: "Enter a few words about this files. Are there any restrictions?"
                value: root.version.description ? root.version.description : ""
                onValueChanged: root.version.description = value
            }

            RowLayout {
                spacing: Styles.spacing

                UChooserField {
                    Layout.fillWidth: true
                    title: "DA"
                    icon: "qrc:/assets/da_icon.svg"
                    value: root.version.da ? root.version.da : ""
                    onValueChanged: root.version.da = value
                }
                UChooserField {
                    Layout.fillWidth: true
                    title: "Auth"
                    icon: "qrc:/assets/auth_icon.svg"
                    value: root.version.auth ? root.version.auth : ""
                    onValueChanged: root.version.auth = value
                }

                UChooserField {
                    Layout.fillWidth: true
                    title: "Preloader"
                    icon: "qrc:/assets/preloader_icon.svg"
                    value: root.version.preloader ? root.version.preloader : ""
                    onValueChanged: root.version.preloader = value
                }
            }

            UCheckRow {
                Layout.fillWidth: true
                text: "Recommend this as the default version"
                checked: root.version.default
                onCheckedChanged: root.version.default = checked
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
