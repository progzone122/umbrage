import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import umbrage
import UmbrageStyles 1.0
import UmbrageUtils 1.0
import Components 1.0

// Right-hand panel for read/write partition operations. Styled to match
// MainMenu, only Styles.* tokens.
Item {
    id: root

    property string title: ""
    property string actionText: ""
    property var partitions: []

    // Show a "Choose file" button per row (write only).
    property bool showChooseFile: false

    // Output directory for reads.
    property string directory: ""

    signal backRequested
    signal chooseScatterFileRequested
    signal chooseDirectoryRequested
    signal chooseFileRequested(int index)
    signal partitionToggled(int index)
    signal actionRequested

    readonly property int checkedCount: partitionList.checkedCount
    readonly property bool canProceed: partitionList.canProceed

    // A risky partition is checked AND this is a write (read never warns).
    readonly property bool warningHardBrick: {
        if (!root.showChooseFile)
            return false;
        var risky = ["preloader_a", "preloader_b", "preloader", "pgpt"];
        var names = partitionList.checkedNames;
        for (var i = 0; i < names.length; ++i) {
            if (risky.indexOf(names[i]) !== -1)
                return true;
        }
        return false;
    }

    property bool warningHardBrickAcknowledged: false

    // Cleared only when a risky partition gets checked, so re-toggling safe
    // ones never re-shows the warning after a confirmation.
    function onToggle(index) {
        var risky = ["preloader_a", "preloader_b", "preloader", "SGPT", "PGPT"];
        var entry = root.partitions[index];
        if (!entry)
            return;

        // Only act on a risky partition that's currently unchecked.
        if (risky.indexOf(entry.name) === -1)
            return;
        if (entry.checked)
            return;

        root.warningHardBrickAcknowledged = false;
    }

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

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                    }

                    UButton {
                        id: menuButton

                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignRight

                        iconDisplay: Button.IconOnly
                        iconPath: "qrc:/assets/more-icon.svg"
                        backgroundColor: Styles.surfaceHigh
                        radius: width / 2

                        onClicked: menu.open()

                        UPopupMenu {
                            id: menu

                            x: menuButton.width - width
                            y: menuButton.height + Styles.spacing / 2

                            width: 260

                            model: [
                                {
                                    text: qsTr("Load scatter file"),
                                    action: "scatter"
                                }
                            ]

                            onActionTriggered: function (action) {
                                if (action === "scatter")
                                    root.chooseScatterFileRequested();
                            }
                        }
                    }
                }

                WarningBlock {
                    Layout.fillWidth: true
                    visible: root.warningHardBrick && !root.warningHardBrickAcknowledged

                    title: qsTr("High level of risk")
                    description: qsTr("Selecting these partitions for flashing may cause your device to become HARD BRICKED, with no possibility of recovery.")
                    actionText: qsTr("I am sure of what I am doing")

                    onAcknowledged: root.warningHardBrickAcknowledged = true
                }

                PartitionList {
                    id: partitionList

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    partitions: root.partitions
                    showChooseFileButton: root.showChooseFile

                    onChooseFileRequested: function (index) {
                        root.chooseFileRequested(index);
                    }

                    onPartitionToggled: function (index) {
                        root.onToggle(index);
                        root.partitionToggled(index);
                    }
                }

                UButton {
                    visible: !root.showChooseFile
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    iconDisplay: Button.TextBesideIcon
                    iconPath: "qrc:/assets/choose-dir-icon.svg"
                    text: root.directory !== "" ? Utils.elideMiddle(root.directory, 40) : qsTr("Choose directory")
                    backgroundColor: Styles.surfaceHigh

                    onClicked: root.chooseDirectoryRequested()
                }

                UButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    iconDisplay: Button.TextBesideIcon
                    iconPath: "qrc:/assets/flash-icon.svg"
                    text: root.actionText
                    backgroundColor: Styles.surfaceHigh

                    // Write needs a file per checked partition; read needs at
                    // least one checked partition. Risky ones also require the
                    // warning to be acknowledged.
                    disabled: (root.showChooseFile ? !root.canProceed : root.checkedCount === 0) || (root.warningHardBrick && !root.warningHardBrickAcknowledged)

                    onClicked: root.actionRequested()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
