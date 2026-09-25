import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import umbrage
import UmbrageStyles 1.0
import Components 1.0
import UmbrageKit 1.0

Page {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    background: null

    signal continueRequested

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width - 48, 660)
        spacing: Styles.spacing

        UText {
            Layout.fillWidth: true
            level: "title"
            centered: true
            text: qsTr("System setup")
        }

        UText {
            Layout.fillWidth: true
            level: "body"
            centered: true
            text: AppState.need_setup ? qsTr("Penumbra needs the following components to access the device:") : qsTr("Everything is ready.")
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: missingText.implicitHeight + 2 * Styles.spacing
            visible: AppState.need_setup
            color: Styles.surfaceVariant
            radius: Styles.radiusMedium

            Text {
                id: missingText
                anchors.fill: parent
                anchors.margins: Styles.spacing
                wrapMode: Text.WordWrap
                font.pixelSize: 16
                color: Styles.textPrimary
                text: AppState.missing_setup
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: instructionColumn.implicitHeight + 2 * Styles.spacing
            visible: AppState.need_setup && AppState.setup_hint !== ""
            color: Styles.surfaceVariant
            radius: Styles.radiusMedium

            ColumnLayout {
                id: instructionColumn
                anchors.fill: parent
                anchors.margins: Styles.spacing
                spacing: 6

                UText {
                    Layout.fillWidth: true
                    level: "label"
                    text: AppState.setup_hint
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: AppState.setup_command !== ""
                    spacing: 8

                    TextEdit {
                        id: commandEdit
                        Layout.fillWidth: true
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        font.pixelSize: 14
                        color: Styles.textPrimary
                        text: AppState.setup_command
                    }

                    UButton {
                        Layout.alignment: Qt.AlignTop
                        text: qsTr("Copy")
                        onClicked: {
                            commandEdit.selectAll();
                            commandEdit.copy();
                        }
                    }
                }
            }
        }

        UText {
            Layout.fillWidth: true
            level: "label"
            centered: true
            color: Styles.error
            visible: AppState.setup_error !== ""
            text: AppState.setup_error
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            BusyIndicator {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                running: AppState.setup_installing
                visible: AppState.setup_installing
            }

            UButton {
                visible: AppState.need_setup && AppState.setupCanAutoInstall()
                disabled: AppState.setup_installing
                text: qsTr("Install")
                onClicked: AppState.installMissing()
            }

            UButton {
                text: qsTr("Re-check")
                disabled: AppState.setup_installing
                onClicked: AppState.refreshSetup()
            }

            UButton {
                text: qsTr("Continue")
                disabled: AppState.setup_installing
                onClicked: page.continueRequested()
            }
        }
    }
}
