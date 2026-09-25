import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import umbrage
import UmbrageStyles 1.0
import UmbrageUtils 1.0
import Components 1.0
import UmbrageKit 1.0

Rectangle {
    id: root

    property string type: ""
    property string title: ""
    property string text: ""
    property var badges: []

    // Optional fields, enabled per selection step.
    property bool showText: false
    property bool showBadges: false

    signal clicked

    color: hoverHandler.hovered ? Styles.surface : "transparent"
    radius: 10

    implicitHeight: content.implicitHeight + 24
    implicitWidth: 300

    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        onTapped: root.clicked()
    }

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        spacing: 12

        Image {
            Layout.preferredWidth: 50
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignVCenter
            fillMode: Image.PreserveAspectFit
            source: Utils.iconFor(root.type)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Styles.textPrimary
                    font.weight: 600
                    font.pixelSize: 24
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.showText
                    text: root.text
                    color: Styles.textPrimary
                    font.weight: 400
                    font.pixelSize: 20
                    elide: Text.ElideRight
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                }
            }

            // Flow (not RowLayout) so badges wrap onto the next line.
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 2

                visible: root.showBadges
                spacing: 8

                Repeater {
                    model: root.badges

                    delegate: UBadge {
                        iconPath: modelData.iconPath
                        iconDisplay: Button.TextBesideIcon
                        text: modelData.text
                    }
                }
            }
        }
    }
}
