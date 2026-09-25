import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UmbrageStyles 1.0

// A popup menu built on the app's surface tokens. It replaces
// QtQuick.Controls `Menu` so the highlight color and default chrome match the
// rest of the UI.
//
// Set `model` to an array of { text, action } and handle `actionTriggered`.
Popup {
    id: root

    // Entries are { text, action }. Clicking an item emits `actionTriggered`
    // with its `action`.
    property var model: []

    property int itemHeight: 42

    signal actionTriggered(string action)

    padding: Styles.spacing / 2

    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color: Styles.surface
        radius: Styles.radiusMedium
        border.width: 2
        border.color: Styles.surfaceAlt
    }

    contentItem: ColumnLayout {
        spacing: 2

        Repeater {
            model: root.model

            delegate: Rectangle {
                id: item

                Layout.fillWidth: true
                Layout.preferredHeight: root.itemHeight

                radius: Styles.radiusMedium
                color: itemArea.containsPress ? Styles.surfaceHigh : itemArea.containsMouse ? Qt.lighter(Styles.surface, 1.1) : "transparent"

                Label {
                    anchors.fill: parent
                    anchors.leftMargin: Styles.spacing
                    anchors.rightMargin: Styles.spacing
                    text: modelData.text
                    color: Styles.surfaceForeground
                    font.pixelSize: 15
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideMiddle
                }

                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.close();
                        root.actionTriggered(modelData.action);
                    }
                }
            }
        }
    }
}
