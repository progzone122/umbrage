import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UmbrageStyles 1.0
import UmbrageKit 1.0

// A modal overlay dialog for confirmation, message, busy, and progress
// (with optional log panel) shapes.
Popup {
    id: root

    property string confirmText: "Confirm"
    property string cancelText: qsTr("Cancel")

    property string title: ""
    property string description: ""

    signal confirmed
    signal cancelled

    property string logText: ""
    property bool busy: false

    // Dialogs that only show a spinner or message can hide the log panel and
    // confirm button, leaving Cancel as the only way out.
    property bool showLog: true
    property int logHeight: 180
    property bool showSpinner: false
    property bool showCancel: true
    property bool showConfirm: true

    // Progress in 0..1 range. Negative hides the bar.
    property real progress: -1
    property string progressText: ""

    // Turn off when the caller handles cancellation itself.
    property bool closeOnCancel: true

    default property alias contentArea: contentContainer.data

    anchors.centerIn: parent

    modal: true
    dim: true
    closePolicy: Popup.NoAutoClose

    Overlay.modal: Rectangle {
        color: "#99000000"
    }

    focus: true

    background: Rectangle {
        color: Styles.surface
        radius: Styles.radiusMedium
    }

    contentWidth: 520
    contentHeight: contentColumn.implicitHeight

    padding: Styles.spacing * 1.5

    ColumnLayout {
        id: contentColumn

        anchors.fill: parent
        spacing: Styles.spacing

        Label {
            Layout.fillWidth: true
            visible: root.title !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Styles.textPrimary
            font.pixelSize: 18
            font.weight: Font.ExtraBold
            text: root.title
        }

        Label {
            Layout.fillWidth: true
            visible: root.description !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Styles.textPrimary
            font.pixelSize: 13
            text: root.description
        }

        // Determinate progress bar, hidden while `progress` is negative.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.progress >= 0

            ProgressBar {
                id: progressBar

                Layout.fillWidth: true

                from: 0
                to: 1
                value: Math.max(0, Math.min(1, root.progress))

                background: Rectangle {
                    implicitHeight: 8
                    radius: 4
                    color: Styles.surfaceHigh
                }

                contentItem: Item {
                    implicitHeight: 8

                    Rectangle {
                        width: progressBar.visualPosition * parent.width
                        height: parent.height
                        radius: 4
                        color: Styles.surfaceForeground
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.progressText !== ""
                text: root.progressText
                color: Styles.textPrimary
                font.pixelSize: 13
            }
        }

        // Caller-provided confirmation area; spinner sits above it.
        ColumnLayout {
            id: contentContainer

            Layout.fillWidth: true
            spacing: Styles.spacing

            Layout.alignment: Qt.AlignHCenter

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                visible: root.showSpinner
                running: root.showSpinner
            }
        }

        // Log panel.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.logHeight
            visible: root.showLog

            color: "black"
            radius: Styles.radiusMedium
            border.width: 2
            border.color: Styles.surfaceHigh

            ScrollView {
                anchors.fill: parent
                anchors.margins: Styles.spacing
                clip: true

                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextArea {
                    id: logArea

                    readOnly: true
                    text: root.logText
                    color: Styles.textPrimary
                    wrapMode: TextArea.Wrap
                    background: null
                    padding: 0
                    font.pixelSize: 12
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Styles.spacing

            Item {
                Layout.fillWidth: true
            }

            UButton {
                visible: root.showCancel
                text: root.cancelText
                backgroundColor: Styles.surfaceAlt

                onClicked: {
                    root.cancelled();
                    if (root.closeOnCancel)
                        root.close();
                }
            }

            UButton {
                visible: root.showConfirm
                text: root.confirmText
                disabled: root.busy

                onClicked: root.confirmed()
            }
        }
    }
}
