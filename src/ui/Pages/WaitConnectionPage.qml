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

    // Start device discovery when this page becomes visible, if not already
    // connecting or connected.
    onVisibleChanged: {
        if (page.visible && !AppState.connecting && !AppState.connected) {
            AppState.connectDevice();
        }
    }

    // Short, actionable hint for common connection errors; empty when no
    // specific hint applies.
    function errorHint() {
        var error = AppState.connection_error;
        if (error === "") {
            return "";
        }

        // DAA / auth-file errors (BROM security handshake).
        if (error.includes("DAA") || error.includes("signature verification") || error.includes("auth file") || error.includes("ToolAuthIsNull") || error.includes("SecAuthFile")) {
            return qsTr("This usually means the selected auth file does not match the device, or is missing. Try again with the correct auth file for this device.");
        }

        // DA-file errors raised while uploading the download agent.
        if (error.includes("No compatible DA") || error.includes("DA file") || error.includes("MTK_DOWNLOAD_AGENT") || error.includes("DA protocol")) {
            return qsTr("The download agent (DA) file does not match this device, or is corrupted. Select the correct DA file for this chip model and try again.");
        }

        // Preloader errors raised when connecting in BROM mode.
        if (error.includes("preloader")) {
            return qsTr("A matching preloader is required for this device in BROM mode. Select the correct preloader file and try again.");
        }

        // Timeouts and USB/transport errors.
        if (error.includes("Timeout") || error.includes("I/O Error") || error.includes("Connection Error") || error.includes("not connected")) {
            return qsTr("The connection to the device timed out or was lost. Reconnect the device, make sure it is in Preloader or BROM mode, and try again.");
        }

        return "";
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width - 48, 660)
        spacing: Styles.spacing

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64

            BusyIndicator {
                anchors.centerIn: parent
                running: AppState.connecting
            }
        }

        UText {
            Layout.alignment: Qt.AlignHCenter
            level: "title"
            centered: true
            text: AppState.connected ? qsTr("Device connected!") : (AppState.connection_error !== "" ? qsTr("Connection failed") : qsTr("Waiting for the device..."))
        }

        UText {
            Layout.alignment: Qt.AlignHCenter
            level: "body"
            centered: true
            visible: AppState.connection_error === ""
            text: qsTr("Please, connect the device to your PC in Preloader or BROM mode.")
        }

        Rectangle {
            id: errorBlock
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 120
            visible: AppState.connection_error !== ""
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
                    readOnly: true
                    text: AppState.connection_error
                    color: Styles.textPrimary
                    wrapMode: TextArea.Wrap
                    background: null
                    padding: 0
                    font.pixelSize: 12
                }
            }
        }

        UText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            level: "small"
            centered: true
            visible: AppState.connection_error !== ""
            text: page.errorHint() !== "" ? page.errorHint() : qsTr("Please check the connection and try again.")
        }

        RowLayout {
            spacing: Styles.spacing
            Layout.alignment: Qt.AlignHCenter

            UButton {
                visible: AppState.connection_error !== ""
                text: qsTr("Retry")
                onClicked: {
                    AppState.connectDevice();
                }
            }

            UButton {
                text: qsTr("Cancel")
                outline: true
                onClicked: AppState.disconnectDevice()
            }
        }
    }
}
