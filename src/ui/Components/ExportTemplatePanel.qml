import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import umbrage
import UmbrageStyles 1.0
import UmbrageUtils 1.0
import Components 1.0

Item {
    id: root

    signal backRequested

    Rectangle {
        anchors.fill: parent
        anchors.margins: Styles.spacing / 2

        color: Styles.surface
        radius: Styles.radiusMedium
        border.width: 4
        border.color: Styles.surface

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Styles.spacing
            spacing: Styles.spacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Styles.spacing

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Styles.spacing

                    UButton {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48

                        text: "◀ "
                        backgroundColor: Styles.surfaceHigh
                        radius: width / 2

                        onClicked: root.backRequested()
                    }
                }

                ColumnLayout {
                    UText {
                        level: "title"
                        text: qsTr("Codename")
                    }

                    UInput {
                        id: searchField

                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        Layout.alignment: Qt.AlignTop

                        visible: page.searching
                        activeFocusOnTab: true

                        placeholderText: qsTr("Search…")

                        onTextChanged: page.searchQuery = text
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
