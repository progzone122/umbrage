import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import umbrage
import UmbrageStyles 1.0
import UmbrageUtils 1.0
import Components 1.0

Page {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    background: null

    // ""      -> welcome content
    // "read"   -> read partitions panel
    // "write"  -> write partitions panel
    property string currentOperation: ""

    // Partition table from `AppState.partitionsLoaded`. Each entry:
    // { name, size, checked, file? }
    property var partitions: []

    property int pendingFileIndex: -1
    property string outputDirectory: ""

    // { name, description, da, auth, preloader, default }
    property var versions: [
        {
            name: "Carbonara Exploit",
            description: "version description",
            da: "",
            auth: "",
            preloader: "",
            default: true
        }
    ]
    property var selectedVersion: ({})

    // Leaving the export flow collapses the drill-down stack back to the
    // template list so it starts fresh next time.
    onCurrentOperationChanged: {
        if (page.currentOperation !== "export_template" && exportStack.depth > 1)
            exportStack.pop(null);
    }

    // Fetch the real partition table when the page becomes visible with a
    // device connected.
    onVisibleChanged: {
        if (page.visible && AppState.connected)
            AppState.requestPartitions();
    }

    Connections {
        target: AppState
        function onPartitionsLoaded(json) {
            var list = JSON.parse(json);
            var entries = [];
            for (var i = 0; i < list.length; ++i) {
                entries.push({
                    name: list[i].name,
                    size: list[i].size,
                    checked: false
                });
            }
            page.partitions = entries;
        }
        // If the device goes away, the dialogs must not stay on screen.
        function onConnectedChanged() {
            if (!AppState.connected) {
                confirmDialog.close();
                operationDialog.close();
            }
        }
        // Scatter file parsed. Apply its mapping to the partition table.
        function onScatterFileLoaded(json) {
            page.applyScatterMapping(JSON.parse(json));
        }
        function onScatterFileFailed(message) {
            scatterErrorDialog.logText = message;
            scatterErrorDialog.open();
        }
    }

    function chooseFileForPartition(index) {
        page.pendingFileIndex = index;
        fileDialog.open();
    }

    function chooseScatterFile() {
        scatterFileDialog.open();
    }

    // Parses the picked scatter file and applies its entries to the partition
    // table. Matching partitions get checked and their file path set so they
    // can be written.
    function loadScatterFile(path) {
        AppState.loadScatterFile(path);
    }

    function openDirectoryDialog() {
        folderDialog.open();
    }

    function setPartitionFile(index, path) {
        page.partitions = Utils.updateAt(page.partitions, index, function (entry) {
            entry.file = path;
        });
    }

    function togglePartition(index) {
        page.partitions = Utils.updateAt(page.partitions, index, function (entry) {
            entry.checked = !entry.checked;
        });
    }

    // Applies a parsed scatter file's entries to the partition table. Entries
    // match by exact name. Downloadable matches get checked and their file path
    // set.
    function applyScatterMapping(entries) {
        var nameToEntry = {};
        for (var i = 0; i < entries.length; ++i)
            nameToEntry[entries[i].name] = entries[i];

        page.partitions = page.partitions.map(function (partition) {
            var copy = JSON.parse(JSON.stringify(partition));
            var scatter = nameToEntry[partition.name];
            if (scatter === undefined)
                return copy;
            copy.checked = scatter.download;
            if (scatter.file && scatter.file !== "")
                copy.file = scatter.file;
            else
                delete copy.file;
            return copy;
        });
    }

    // Uncheck everything, clear files, reset the output directory.
    function resetPartitions() {
        page.partitions = page.partitions.map(function (entry) {
            var copy = JSON.parse(JSON.stringify(entry));
            copy.checked = false;
            delete copy.file;
            return copy;
        });
        page.outputDirectory = "";
    }

    RowLayout {
        anchors.fill: parent

        MainMenu {
            actions: [
                {
                    key: "unlock",
                    section: "bootloader",
                    text: "Unlock bootloader"
                },
                {
                    key: "lock",
                    section: "bootloader",
                    text: "Lock bootloader"
                },
                {
                    key: "read",
                    section: "flashing",
                    text: "Read partitions"
                },
                {
                    key: "write",
                    section: "flashing",
                    text: "Write partitions"
                },
                {
                    key: "export_template",
                    section: "other",
                    text: "Export template"
                },
            ]

            onActionRequested: function (key) {
                if (key === "unlock" || key === "lock") {
                    confirmDialog.actionKey = key;
                    confirmDialog.title = key === "unlock" ? qsTr("Unlock the bootloader?") : qsTr("Lock the bootloader?");
                    confirmDialog.description = key === "unlock" ? qsTr("This will wipe all data on the device and void its warranty.") : qsTr("This will relock the bootloader.");
                    confirmDialog.confirmText = key === "unlock" ? qsTr("Unlock") : qsTr("Lock");
                    confirmDialog.logText = "Please confirm that you are aware of all the risks and that you really do wish to proceed.";
                    confirmDialog.open();
                } else {
                    page.resetPartitions();
                    page.currentOperation = key;
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Welcome content.
            ColumnLayout {
                visible: page.currentOperation === ""

                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 62
                        font.weight: 300
                        color: Styles.surfaceAlt
                        text: qsTr("＼(＾O＾)／")
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 22
                        font.weight: 400
                        color: Styles.surfaceAlt
                        text: qsTr("Hi! What are we working on today?")
                    }
                }
            }

            // Operation panel (read / write partitions).
            OperationPanel {
                id: operationPanel

                visible: page.currentOperation == "read" || page.currentOperation == "write"

                Layout.fillWidth: true
                Layout.fillHeight: true

                title: page.currentOperation === "read" ? qsTr("Read partitions") : qsTr("Write partitions")
                actionText: page.currentOperation === "read" ? qsTr("Read partitions") : qsTr("Write partitions")
                partitions: page.partitions
                showChooseFile: page.currentOperation === "write"
                directory: page.outputDirectory

                onBackRequested: page.currentOperation = ""
                onChooseScatterFileRequested: {
                    page.chooseScatterFile();
                }
                onChooseDirectoryRequested: {
                    page.openDirectoryDialog();
                }
                onChooseFileRequested: function (index) {
                    page.chooseFileForPartition(index);
                }
                onPartitionToggled: function (index) {
                    page.togglePartition(index);
                }
                onActionRequested: page.openOperationDialog()
            }

            StackView {
                id: exportStack

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: page.currentOperation == "export_template"
                clip: true

                initialItem: exportTemplateComponent

                Component {
                    id: exportTemplateComponent

                    ExportTemplatePanel {
                        versions: page.versions

                        onBackRequested: page.currentOperation = ""
                        onVersionSelected: function (index) {
                            page.selectedVersion = page.versions[index];
                            exportStack.push(exportVersionComponent);
                        }
                    }
                }

                Component {
                    id: exportVersionComponent

                    ExportTemplateVersionPanel {
                        version: page.selectedVersion

                        onBackRequested: exportStack.pop()
                    }
                }
            }
        }
    }

    function openOperationDialog() {
        var isRead = page.currentOperation === "read";
        operationDialog.title = isRead ? qsTr("Read partitions") : qsTr("Write partitions");
        operationDialog.confirmText = isRead ? qsTr("Read") : qsTr("Write");
        var log = (isRead ? qsTr("Reading ") : qsTr("Writing ")) + operationPanel.checkedCount + qsTr(" partitions…");
        if (isRead && page.outputDirectory !== "")
            log += "\n" + qsTr("To: ") + page.outputDirectory;
        operationDialog.logText = log;
        operationDialog.progress = -1;
        operationDialog.progressText = "";
        operationDialog.open();
    }

    // Shared confirmation dialog for unlock / lock bootloader.
    ModalDialog {
        id: confirmDialog

        property string actionKey: ""

        // No percentage is available for the seccfg write, so show a spinner.
        showSpinner: confirmDialog.busy

        // The seccfg write is one penumbra call with no interrupt, so hide Cancel
        // while it runs.
        showCancel: !confirmDialog.busy

        onConfirmed: {
            confirmDialog.busy = true;
            confirmDialog.logText += "\n" + (actionKey === "unlock" ? "Unlocking bootloader…" : "Locking bootloader…");
            if (actionKey === "unlock") {
                AppState.unlockBootloader();
            } else {
                AppState.lockBootloader();
            }
        }

        // Stream operation progress into the dialog's log panel.
        Connections {
            target: AppState
            function onBootloaderLockProgress(message) {
                confirmDialog.logText += "\n" + message;
            }
            function onBootloaderLockFinished(success, message) {
                confirmDialog.busy = false;
                if (success) {
                    confirmDialog.logText += "\n" + qsTr("Done. Reboot the device to apply changes.");
                } else {
                    confirmDialog.logText += "\n" + qsTr("Operation failed: ") + message;
                }
            }
        }
    }

    // Confirmation dialog for read / write.
    ModalDialog {
        id: operationDialog

        // The transfer can't be interrupted mid-flight, so Cancel is hidden
        // while it runs.
        showCancel: !operationDialog.busy

        onConfirmed: {
            var isRead = page.currentOperation === "read";
            operationDialog.logText += "\n" + (isRead ? "Reading " : "Writing ") + operationPanel.checkedCount + " partitions…";
            operationDialog.busy = true;
            operationDialog.progress = 0;
            operationDialog.progressText = "";

            // Build the JSON payload of checked partitions; writes carry the
            // file path, reads only the names.
            var selected = [];
            for (var i = 0; i < page.partitions.length; ++i) {
                var entry = page.partitions[i];
                if (!entry.checked)
                    continue;
                selected.push({
                    name: entry.name,
                    file: entry.file ? entry.file : ""
                });
            }

            if (isRead) {
                AppState.readPartitions(JSON.stringify(selected), page.outputDirectory);
            } else {
                AppState.writePartitions(JSON.stringify(selected));
            }
        }

        // Stream operation progress and completion into the dialog's log panel.
        Connections {
            target: AppState
            function onPartitionProgress(message, percent) {
                operationDialog.progress = percent / 100;
                operationDialog.progressText = message;
                operationDialog.logText += "\n" + message;
            }
            function onPartitionLog(message) {
                operationDialog.logText += "\n" + message;
            }
            function onPartitionFinished(success, message) {
                operationDialog.busy = false;
                operationDialog.progress = success ? 1 : -1;
                operationDialog.progressText = message;
                operationDialog.logText += "\n" + message;
            }
        }
    }

    // File picker for a partition row's "Choose file" button.
    FileDialog {
        id: fileDialog

        title: qsTr("Choose file")
        fileMode: FileDialog.OpenFile

        onAccepted: {
            if (page.pendingFileIndex >= 0 && page.pendingFileIndex < page.partitions.length) {
                page.setPartitionFile(page.pendingFileIndex, fileDialog.file.toString());
            }
            page.pendingFileIndex = -1;
        }
    }

    // File picker for the scatter file.
    FileDialog {
        id: scatterFileDialog

        title: qsTr("Choose scatter file")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Scatter files (*.txt *.xml)"), qsTr("All files (*)")]

        onAccepted: {
            page.loadScatterFile(scatterFileDialog.file.toString());
        }
    }

    // Error dialog for a scatter file that failed to parse.
    ModalDialog {
        id: scatterErrorDialog

        title: qsTr("Invalid scatter file")
        description: qsTr("The selected file could not be loaded.")
        showLog: true
        showSpinner: false
        showConfirm: true
        showCancel: false
        confirmText: qsTr("Close")
        logText: ""

        onConfirmed: scatterErrorDialog.close()
    }

    // Directory picker for the "Choose directory" button (read operation).
    FolderDialog {
        id: folderDialog

        title: qsTr("Choose directory")

        onAccepted: {
            page.outputDirectory = folderDialog.folder.toString();
        }
    }
}
