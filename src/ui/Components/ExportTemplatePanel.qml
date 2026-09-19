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
    property var versions: []

    property string codename: ""
    property string vendor: ""
    property string model: ""

    signal backRequested
    signal versionSelected(int index)
    signal addVersionRequested
    signal removeVersionRequested(int index)

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

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
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
                    title: "Codename"
                    placeholder: "penangf"
                    value: root.codename
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Styles.spacing

                    UInputField {
                        Layout.fillWidth: true
                        title: "Vendor"
                        placeholder: "Motorola"
                        value: root.vendor
                    }

                    UInputField {
                        Layout.fillWidth: true
                        title: "Model"
                        placeholder: "G13/G23"
                        value: root.model
                    }
                }

                ColumnLayout {
                    spacing: Styles.spacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Styles.spacing

                        UText {
                            Layout.fillWidth: true
                            level: "title"
                            text: "Template versions"
                        }

                        UButton {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40

                            text: "+"
                            backgroundColor: Styles.surfaceHigh
                            radius: width / 2

                            onClicked: root.addVersionRequested()
                        }
                    }

                    TemplateVersionList {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        versions: root.versions

                        onVersionToggled: function (index) {
                            root.versionSelected(index);
                        }

                        onRemoveVersionRequested: function (index) {
                            root.removeVersionRequested(index);
                        }
                    }
                }
            }
        }
    }
}
