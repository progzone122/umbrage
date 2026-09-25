import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    /// Field label.
    property string title: "Undefined title"
    /// Hint shown when the field is empty.
    property string placeholder: "Undefined placeholder"
    /// Field text, bound both ways.
    property alias value: input.text

    UText {
        level: "title"
        text: root.title
    }

    UInput {
        id: input

        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.alignment: Qt.AlignTop

        activeFocusOnTab: true

        placeholderText: root.placeholder
    }
}
