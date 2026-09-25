import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UmbrageStyles 1.0
import UmbrageKit 1.0

// Scrollable, selectable list of partitions.
// The caller supplies `partitions` as an array of { name, size, checked, file }
// and always re-assigns a fresh array so bindings re-evaluate.
Rectangle {
    id: root

    property var partitions: []

    property bool showChooseFileButton: false

    signal checkedChanged

    // The owner updates the underlying data; this list is read-only over it.
    signal partitionToggled(int index)

    signal chooseFileRequested(int index)

    // Number of checked partitions.
    readonly property int checkedCount: {
        var count = 0;
        for (var i = 0; i < root.partitions.length; ++i) {
            if (root.partitions[i].checked)
                count++;
        }
        return count;
    }

    // True when every checked partition has a file.
    readonly property bool canProceed: {
        if (root.partitions.length === 0)
            return false;

        if (root.checkedCount === 0)
            return false;

        for (var i = 0; i < root.partitions.length; ++i) {
            var partition = root.partitions[i];

            if (!partition.checked)
                continue;

            if (!partition.file || partition.file === "")
                return false;
        }

        return true;
    }
    readonly property var checkedNames: {
        var names = [];
        for (var i = 0; i < root.partitions.length; ++i) {
            if (root.partitions[i].checked)
                names.push(root.partitions[i].name);
        }
        return names;
    }

    color: Styles.surfaceVariant
    radius: Styles.radiusMedium
    border.width: 4
    border.color: Styles.surface

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
                model: root.partitions

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
                        onClicked: root.partitionToggled(index)
                    }

                    RowLayout {
                        id: contentColumn

                        anchors.fill: parent
                        anchors.leftMargin: Styles.spacing
                        anchors.rightMargin: Styles.spacing / 2
                        spacing: Styles.spacing / 2

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                Layout.fillWidth: true
                                text: modelData.name + " (" + modelData.size + ")"
                                color: Styles.surfaceForeground
                                font.pixelSize: 15
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: modelData.file !== undefined && modelData.file !== ""
                                text: modelData.file !== undefined ? modelData.file : ""
                                color: Styles.surfaceAlt
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // "Choose file" button.
                        Rectangle {
                            id: chooseButton

                            visible: root.showChooseFileButton

                            Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter

                            implicitWidth: chooseLabel.implicitWidth + Styles.spacing * 2

                            radius: Styles.radiusMedium
                            color: hoverHandler.hovered ? Styles.surfaceAlt : "transparent"

                            HoverHandler {
                                id: hoverHandler
                            }

                            Label {
                                id: chooseLabel
                                anchors.centerIn: parent
                                text: qsTr("Choose file")
                                color: Styles.surfaceForeground
                                font.pixelSize: 13
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.chooseFileRequested(index)
                            }
                        }

                        CheckBox {
                            id: checkBox

                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22

                            checked: modelData.checked
                            onClicked: root.partitionToggled(index)

                            indicator: Rectangle {
                                implicitWidth: 14
                                implicitHeight: 14

                                x: checkBox.leftPadding
                                y: parent.height / 2 - height / 2

                                radius: 2
                                color: checkBox.checked ? Styles.surfaceForeground : "transparent"
                                border.width: 2
                                border.color: Styles.surfaceForeground

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    visible: checkBox.checked
                                    color: Styles.surface
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
