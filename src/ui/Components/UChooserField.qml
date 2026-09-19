import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import UmbrageStyles 1.0
import UmbrageUtils 1.0

ColumnLayout {
    id: root

    /// Field label.
    property string title: "Undefined title"
    /// Hint shown when the field is empty.
    property string placeholder: "Undefined placeholder"
    /// Chooser path, bound both ways.
    property string value: ""
    /// Chooser button icon
    property string icon: "qrc:/assets/da_icon.svg"

    UText {
        level: "title"
        text: root.title
    }

    UButton {
        id: input

        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.alignment: Qt.AlignTop

        backgroundColor: Styles.surfaceHigh
        radius: Styles.radiusMedium

        iconDisplay: Button.TextBesideIcon
        iconPath: root.icon
        text: root.value ? Utils.baseName(root.value) : "Choose file"

        contentAlignment: Qt.AlignLeft

        font.pixelSize: 16
        font.weight: 600

        padding: 12

        activeFocusOnTab: true

        onClicked: {
            fileDialog.open();
        }
    }

    FileDialog {
        id: fileDialog

        title: qsTr("Choose file")
        fileMode: FileDialog.OpenFile

        onAccepted: {
            root.value = fileDialog.file.toString();
        }
    }
}
