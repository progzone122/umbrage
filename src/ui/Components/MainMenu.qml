import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import umbrage
import UmbrageStyles 1.0
import Components 1.0

Item {
    id: root

    Layout.fillHeight: true
    Layout.preferredWidth: 280

    property bool bootloaderExpanded: false
    property bool flashingExpanded: false

    // `key` matches an entry in the caller-provided `actions`.
    signal actionRequested(string key)

    // Each entry: { key, section: "bootloader"|"flashing", text }
    property var actions: []

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Styles.spacing / 2
        spacing: Styles.spacing

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true

            color: Styles.surface

            radius: Styles.radiusMedium

            border.width: 4
            border.color: Styles.surface

            ScrollView {
                id: scroll

                anchors.fill: parent
                anchors.margins: Styles.spacing
                anchors.topMargin: Styles.spacing * 2
                anchors.leftMargin: Styles.spacing * 1.2 + 8

                clip: true

                // Gutter so the scrollbar sits beside the content.
                rightPadding: Styles.spacing

                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: scroll.availableWidth
                    spacing: Styles.spacing

                    CollapsibleSection {
                        Layout.fillWidth: true

                        title: "Bootloader operations"
                        expanded: root.bootloaderExpanded
                        onToggleRequested: root.bootloaderExpanded = !root.bootloaderExpanded

                        Repeater {
                            model: root.actionsForSection("bootloader")

                            delegate: MenuButton {
                                text: modelData.text
                                onClicked: root.actionRequested(modelData.key)
                            }
                        }
                    }

                    CollapsibleSection {
                        Layout.fillWidth: true

                        title: "Flashing operations"
                        expanded: root.flashingExpanded
                        onToggleRequested: root.flashingExpanded = !root.flashingExpanded

                        Repeater {
                            model: root.actionsForSection("flashing")

                            delegate: MenuButton {
                                text: modelData.text
                                onClicked: root.actionRequested(modelData.key)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72

            radius: Styles.radiusMedium
            color: Styles.surface

            RowLayout {
                anchors.fill: parent
                anchors.margins: Styles.spacing

                spacing: Styles.spacing

                Label {
                    text: "●"

                    color: "#39ff14"
                    font.pixelSize: 18

                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        text: "Connected"

                        color: Styles.surfaceForeground
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Label {
                        text: AppState.device_name !== "" ? AppState.device_name : AppState.chip_name

                        color: Styles.surfaceForeground
                        font.pixelSize: 14

                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 48

                    display: Button.IconOnly

                    icon.source: "qrc:/assets/disconnect-icon.svg"
                    icon.color: Styles.surfaceForeground
                    icon.width: 20
                    icon.height: 20

                    background: Rectangle {
                        radius: Styles.radiusMedium
                        color: Styles.surfaceHigh
                    }

                    onClicked: {
                        AppState.disconnectDevice();
                    }
                }
            }
        }
    }

    // Subset of `actions` whose `section` matches.
    function actionsForSection(section) {
        var result = [];
        for (var i = 0; i < root.actions.length; ++i) {
            if (root.actions[i].section === section) {
                result.push(root.actions[i]);
            }
        }
        return result;
    }
}
