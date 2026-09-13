import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UmbrageStyles 1.0
import Components 1.0

// Warning banner with title, description, and acknowledgement action.
ColumnLayout {
    id: root

    property string title: ""
    property string description: ""
    property string actionText: ""

    signal acknowledged

    spacing: Styles.spacing / 2

    Rectangle {
        id: box

        Layout.fillWidth: true
        Layout.preferredHeight: inner.implicitHeight + Styles.spacing * 2

        color: Styles.surfaceAlt
        radius: Styles.radiusMedium
        border.width: 2
        border.color: Styles.error

        ColumnLayout {
            id: inner

            anchors.fill: parent
            anchors.margins: Styles.spacing

            spacing: Styles.spacing / 2

            Text {
                Layout.fillWidth: true

                text: root.title
                color: Styles.error
                font.pixelSize: 18
                font.weight: 600
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap

                text: root.description
                color: Styles.textPrimary
                font.pixelSize: 14
                font.weight: 600
            }

            RowLayout {
                UButton {
                    text: root.actionText
                    backgroundColor: Styles.surfaceHigh

                    onClicked: root.acknowledged()
                }
            }
        }
    }
}
