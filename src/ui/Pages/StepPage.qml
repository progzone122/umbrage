import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import umbrage
import Components 1.0

Page {
    id: page

    background: null

    property int step: 0
    property string stepTitle: ""
    property string stepText: ""
    property url stepImage: ""

    // On the last step goNext() emits finishedRequested() instead.
    property bool isLastStep: false

    // Buttons supplied by the caller (Main.qml), as { text, onClicked }.
    property var buttons: []

    signal nextRequested(int nextStep)
    signal finishedRequested
    signal backRequested

    function goNext() {
        if (page.isLastStep) {
            page.finishedRequested();
        } else {
            page.nextRequested(page.step + 1);
        }
    }

    function setCurrentFile(path) {
        switch (page.step) {
        case 1:
            AppState.da_file = path;
            break;
        case 2:
            AppState.auth_file = path;
            break;
        case 3:
            AppState.preloader_file = path;
            break;
        }
    }

    function chooseFile() {
        fileDialog.step = page.step;
        fileDialog.open();
    }

    function skip() {
        page.setCurrentFile("");
        page.goNext();
    }

    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width - 48, 660)
        spacing: 20

        Image {
            Layout.preferredWidth: 230
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: -60
            fillMode: Image.PreserveAspectFit
            source: page.stepImage
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            spacing: 8

            UText {
                Layout.fillWidth: true
                level: "title"
                text: page.stepTitle
            }

            UText {
                Layout.fillWidth: true
                level: "body"
                text: page.stepText
            }

            RowLayout {
                spacing: 10

                Repeater {
                    model: page.buttons

                    delegate: UButton {
                        text: modelData.text
                        outline: modelData.outline
                        onClicked: modelData.onClicked(page)
                    }
                }
            }
        }
    }

    FileDialog {
        id: fileDialog
        property int step: 0
        title: "Choose file"
        fileMode: FileDialog.OpenFile

        onAccepted: {
            page.setCurrentFile(fileDialog.file.toString());
            console.log("index: " + fileDialog.step);
            console.log("File selected: " + fileDialog.file.toString());
            page.goNext();
        }
    }
}
