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
    property var versions: [
        {
            name: "Carbonara Exploit",
            description: "version description",
            da: "",
            auth: "",
            preloader: "",
            default: true
        }
    ]

    property string codename: "codename"
    property string vendor: "vendor"
    property string model: "model"

    signal backRequested

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

            ColumnLayout {
                Layout.fillWidth: true
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
                    Layout.margins: Styles.spacing
                    spacing: Styles.spacing

                    UInputField {
                        title: "Codename"
                        placeholder: "penangf"
                        value: root.codename
                    }

                    RowLayout {
                        spacing: Styles.spacing

                        UInputField {
                            title: "Vendor"
                            placeholder: "Motorola"
                            value: root.vendor
                        }

                        UInputField {
                            title: "Model"
                            placeholder: "G13/G23"
                            value: root.model
                        }
                    }

                    ColumnLayout {
                        UText {
                            level: "title"
                            text: "Template versions"
                        }

                        TemplateList {
                            versions: root.versions
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
