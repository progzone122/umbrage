import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import umbrage
import UmbrageStyles 1.0
import UmbrageUtils 1.0
import Components 1.0
import UmbrageKit 1.0

Item {
    id: root

    // { name, description, da, auth, preloader, default }.
    // da/auth/preloader are file slots: { path, name, sha256 }.
    property var versions: []

    property string codename: ""
    property string vendor: ""
    property string model: ""

    // Export requires a codename, vendor, model, and at least one version.
    readonly property bool canExport: root.codename.trim() !== "" && root.vendor.trim() !== "" && root.model.trim() !== "" && root.versions.length > 0

    signal backRequested
    signal versionSelected(int index)
    signal addVersionRequested
    signal removeVersionRequested(int index)

    Layout.fillWidth: true
    Layout.fillHeight: true

    // The save dialog suggests this file name, built from the codename.
    function exportFileName() {
        var name = root.codename.trim();
        if (name === "")
            name = "template";
        return name + ".meta.yml";
    }

    function openExportDialog() {
        var dir = StandardPaths.writableLocation(StandardPaths.DocumentsLocation);
        if (dir === "")
            dir = StandardPaths.writableLocation(StandardPaths.HomeLocation);
        exportDialog.folder = dir;
        exportDialog.currentFile = dir + "/" + root.exportFileName();
        exportDialog.open();
    }

    // Shapes the panel data into the JSON payload Rust expects for export.
    function buildExportPayload() {
        var list = [];
        for (var i = 0; i < root.versions.length; i++) {
            var v = root.versions[i];
            list.push({
                name: v.name ? v.name : "",
                description: v.description ? v.description : "",
                default: v.default === true,
                files: {
                    da: root.filePayload(v.da),
                    auth: root.filePayload(v.auth),
                    preloader: root.filePayload(v.preloader)
                }
            });
        }
        return JSON.stringify({
            vendor: root.vendor ? root.vendor : "",
            model: root.model ? root.model : "",
            codename: root.codename ? root.codename : "",
            versions: list
        });
    }

    // A local path is sent as-is; a repo entry is sent as { name, sha256 } so
    // Rust reuses the checksum without reading the file.
    function filePayload(entry) {
        if (!entry)
            return "";
        if (entry.path)
            return entry.path;
        if (entry.sha256)
            return {
                name: entry.name,
                sha256: entry.sha256
            };
        return "";
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
                Layout.fillHeight: true
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

                UInputField {
                    Layout.fillWidth: true
                    title: "Codename"
                    placeholder: "penangf"
                    value: root.codename
                    onValueChanged: root.codename = value
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Styles.spacing

                    UInputField {
                        Layout.fillWidth: true
                        title: "Vendor"
                        placeholder: "Motorola"
                        value: root.vendor
                        onValueChanged: root.vendor = value
                    }

                    UInputField {
                        Layout.fillWidth: true
                        title: "Model"
                        placeholder: "G13/G23"
                        value: root.model
                        onValueChanged: root.model = value
                    }
                }

                ColumnLayout {
                    spacing: Styles.spacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Styles.spacing

                        UText {
                            Layout.fillWidth: true
                            level: "title"
                            text: "Template versions"
                        }

                        UButton {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40

                            text: "+"
                            backgroundColor: Styles.surfaceHigh
                            radius: width / 2

                            onClicked: root.addVersionRequested()
                        }
                    }

                    TemplateVersionList {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        versions: root.versions

                        onVersionToggled: function (index) {
                            root.versionSelected(index);
                        }

                        onRemoveVersionRequested: function (index) {
                            root.removeVersionRequested(index);
                        }
                    }
                }

                UButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    text: qsTr("Export template")
                    backgroundColor: Styles.surfaceHigh
                    disabled: !root.canExport

                    onClicked: root.openExportDialog()
                }
            }
        }
    }

    FileDialog {
        id: exportDialog

        title: qsTr("Export template")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("YAML template (*.yml)")]
        defaultSuffix: "yml"

        onAccepted: {
            AppState.exportTemplate(root.buildExportPayload(), exportDialog.file.toString());
        }
    }

    Connections {
        target: AppState
        function onExportFinished(success, message) {
            if (success) {
                exportResultDialog.title = qsTr("Template exported");
                exportResultDialog.description = message;
            } else {
                exportResultDialog.title = qsTr("Export failed");
                exportResultDialog.description = message;
            }
            exportResultDialog.open();
        }
    }

    ModalDialog {
        id: exportResultDialog

        showLog: false
        showSpinner: false
        showCancel: false
        showConfirm: true
        confirmText: qsTr("Close")

        onConfirmed: exportResultDialog.close()
    }
}
