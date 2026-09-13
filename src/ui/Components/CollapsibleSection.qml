import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UmbrageStyles 1.0

Rectangle {
    id: root

    property string title: ""

    // Visual header only; does not toggle content.
    property bool staticHeader: false

    // Owned by the caller, which flips it on `toggleRequested`.
    property bool expanded: !staticHeader

    signal toggleRequested

    default property alias content: contentLayout.data

    Layout.fillWidth: true
    Layout.preferredHeight: contentColumn.height

    radius: Styles.radiusMedium
    color: Styles.surfaceVariant

    ColumnLayout {
        id: contentColumn

        width: parent.width
        spacing: Styles.spacing

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            Label {
                anchors.left: parent.left
                anchors.leftMargin: Styles.spacing
                anchors.verticalCenter: parent.verticalCenter

                text: root.title

                color: Styles.surfaceForeground
                font.pixelSize: 15
                font.bold: true
            }

            Label {
                anchors.right: parent.right
                anchors.rightMargin: Styles.spacing
                anchors.verticalCenter: parent.verticalCenter

                text: root.staticHeader ? "" : (root.expanded ? "▴" : "▾")

                color: Styles.surfaceForeground
                font.pixelSize: 16
            }

            MouseArea {
                anchors.fill: parent

                onClicked: {
                    if (!root.staticHeader) {
                        root.toggleRequested();
                    }
                }
            }
        }

        ColumnLayout {
            id: contentLayout

            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.bottomMargin: 20

            visible: root.expanded

            spacing: Styles.spacing
        }
    }
}
