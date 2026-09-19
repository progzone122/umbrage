import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UmbrageStyles 1.0

// Scrollable, selectable list of versions.
// The caller supplies `versions` as an array of { name, description, da, auth, preloader, default }
// and always re-assigns a fresh array so bindings re-evaluate.
Rectangle {
    id: root

    property var versions: []

    // The owner updates the underlying data; this list is read-only over it.
    signal versionToggled(int index)

    signal removeVersionRequested(int index)

    color: Styles.surfaceVariant
    radius: Styles.radiusMedium
    border.width: 4
    border.color: Styles.surface

    implicitHeight: 120

    Flickable {
        id: flickable

        anchors.fill: parent
        anchors.margins: Styles.spacing

        contentWidth: width
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: listColumn

            width: parent.width
            spacing: Styles.spacing / 2

            Repeater {
                model: root.versions

                delegate: Rectangle {
                    id: row

                    Layout.fillWidth: true
                    Layout.preferredHeight: contentColumn.implicitHeight + Styles.spacing
                    Layout.minimumHeight: 40

                    color: modelData.checked ? Styles.surfaceHigh : Styles.surface

                    radius: Styles.radiusMedium

                    // Full-row toggle sits behind the interactive children so
                    // the checkbox/button still get the click.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.versionToggled(index)
                    }

                    RowLayout {
                        id: contentColumn

                        anchors.fill: parent
                        anchors.leftMargin: Styles.spacing
                        anchors.rightMargin: Styles.spacing / 2
                        spacing: Styles.spacing / 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Styles.surfaceForeground
                                font.pixelSize: 15
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // Remove button
                        UButton {
                            iconDisplay: Button.IconOnly
                            iconPath: "qrc:/assets/trash-icon.svg"
                        }
                    }
                }
            }
        }
    }
}
