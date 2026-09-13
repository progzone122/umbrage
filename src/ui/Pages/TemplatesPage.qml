import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import umbrage
import UmbrageUtils 1.0
import Components 1.0

Page {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    background: null

    signal finished
    signal cancelled

    property int currentStep: 0

    property bool filesPending: false

    // Overall download progress in 0..1 and its caption. Negative means the
    // size is unknown, so the dialog shows a spinner.
    property real downloadProgress: -1
    property string downloadText: ""

    property string errorTitle: ""

    property string errorMessage: ""

    property bool loading: true

    property real startTime: 0

    onVisibleChanged: {
        if (page.visible) {
            page.reset();
        } else {
            page.syncDialogs();
        }
    }

    // Popups are opened/closed imperatively: binding `visible` breaks as soon
    // as a popup gets closed, so state drives open()/close() here.
    onLoadingChanged: page.syncDialogs()
    onFilesPendingChanged: page.syncDialogs()
    onErrorTitleChanged: page.syncDialogs()
    onErrorMessageChanged: page.syncDialogs()

    function reset() {
        page.loading = true;
        page.filesPending = false;
        page.errorTitle = "";
        page.errorMessage = "";
        page.repoLoaded = false;
        page.selectedVendor = "";
        page.selectedDevice = "";
        page.startTime = Date.now();
        AppState.device_name = "";
        page.syncDialogs();
        AppState.requestGetTemplates();
    }

    // Stop any in-flight fetch/download and leave the templates flow.
    function abort() {
        AppState.cancelTemplatesLoading();
        page.loading = false;
        page.filesPending = false;
        page.errorTitle = "";
        page.errorMessage = "";
        page.cancelled();
    }

    // Keeps the dialogs in sync with the page state.
    function syncDialogs() {
        if (page.visible && page.loading)
            loadingDialog.open();
        else
            loadingDialog.close();

        if (page.visible && page.filesPending)
            downloadDialog.open();
        else
            downloadDialog.close();

        if (page.visible && page.errorTitle !== "")
            errorDialog.open();
        else
            errorDialog.close();
    }

    function onRepoReady() {
        if (page.loading === false)
            return;
        page.repo = JSON.parse(AppState.repo);
        page.repoLoaded = true;
        finishLoading();
    }

    function finishLoading() {
        var elapsed = Date.now() - startTime;
        var remaining = Math.max(0, 2000 - elapsed);
        loadingTimer.interval = remaining;
        loadingTimer.start();
    }

    Timer {
        id: loadingTimer
        running: false
        repeat: false
        interval: 0
        onTriggered: {
            page.loading = false;
            stepStack.clear();
            stepStack.pushStep(0);
        }
    }

    property var repo: ({})

    // True once meta.json was parsed. Decides what Retry restarts.
    property bool repoLoaded: false

    property string selectedVendor: ""
    property string selectedDevice: ""

    property var steps: [
        {
            title: "Templates",
            text: "Choose the device manufacturer"
        },
        {
            title: "Device",
            text: "Choose the device"
        },
        {
            title: "Version",
            text: "Choose the template version"
        }
    ]

    // File names can be long; badges show at most 20 characters.
    function shortFileName(name) {
        return Utils.elideRight(name, 20);
    }

    function fileBadges(files) {
        var badges = [];
        var order = ["da", "auth", "preloader"];
        for (var i = 0; i < order.length; i++) {
            var key = order[i];
            if (files && files[key]) {
                badges.push({
                    iconPath: Utils.iconFor(key),
                    text: page.shortFileName(files[key].name)
                });
            }
        }
        return badges;
    }

    function versionBadges(version) {
        var badges = [];
        if (version.default) {
            badges.push({
                iconPath: "qrc:/assets/ok-icon.svg",
                text: "Recommended by default"
            });
        }
        var files = page.fileBadges(version.files);
        for (var i = 0; i < files.length; i++) {
            badges.push(files[i]);
        }
        return badges;
    }

    function buildStepItems(step) {
        var items = [];

        switch (step) {
        case 0:
            Object.keys(page.repo.vendors).forEach(function (vendor) {
                items.push({
                    type: "vendor",
                    title: vendor,
                    text: "",
                    badges: []
                });
            });
            break;
        case 1:
            page.repo.vendors[page.selectedVendor].forEach(function (code) {
                var device = page.repo.devices[code];
                items.push({
                    type: "device",
                    code: code,
                    title: device.name,
                    text: device.vendor + " · " + device.model,
                    badges: []
                });
            });
            break;
        case 2:
            page.repo.devices[page.selectedDevice].versions.forEach(function (version) {
                items.push({
                    type: "template",
                    title: version.name,
                    text: version.description,
                    badges: page.versionBadges(version),
                    files: version.files
                });
            });
            break;
        }

        return items;
    }

    function applyFiles(files) {
        if (!files)
            return;
        // Hand the selected template's files (paths + checksums) to Rust,
        // which downloads them and fills da/auth/preloader with local paths.
        page.filesPending = true;
        page.downloadProgress = -1;
        page.downloadText = "";
        AppState.downloadTemplateFiles(JSON.stringify(files));
    }

    function onItemSelected(item, step) {
        if (step === 0) {
            page.selectedVendor = item.title;
            stepStack.pushStep(1);
        } else if (step === 1) {
            page.selectedDevice = item.code;
            AppState.device_name = item.title;
            stepStack.pushStep(2);
        } else {
            page.applyFiles(item.files);
        }
    }

    Connections {
        target: AppState
        function onRepoChanged() {
            page.onRepoReady();
        }
        function onTemplateFilesReady() {
            if (page.filesPending) {
                page.filesPending = false;
                page.downloadProgress = -1;
                page.downloadText = "";
                page.errorTitle = "";
                page.errorMessage = "";
                page.finished();
            }
        }
        function onTemplateFilesFailed() {
            page.filesPending = false;
            page.downloadProgress = -1;
            page.downloadText = "";
            page.errorTitle = qsTr("Could not download template files");
            page.errorMessage = qsTr("Please try again.");
        }
        function onTemplatesFailed(message) {
            page.loading = false;
            page.repoLoaded = false;
            page.errorTitle = qsTr("Could not load templates");
            page.errorMessage = message;
        }
        function onTemplatesLoadCancelled() {
            page.loading = false;
        }
        function onTemplateFilesCancelled() {
            page.filesPending = false;
            page.downloadProgress = -1;
            page.downloadText = "";
        }
        function onTemplateProgress(message, percent) {
            page.downloadProgress = percent / 100;
            page.downloadText = message;
        }
    }

    StackView {
        id: stepStack
        anchors.fill: parent

        function pushStep(step) {
            page.currentStep = step;

            var stepPage = templateStepComponent.createObject(stepStack, {
                step: step,
                stepTitle: page.steps[step].title,
                stepText: page.steps[step].text,
                stepItems: page.buildStepItems(step)
            });

            stepPage.itemSelected.connect(function (item, step) {
                page.onItemSelected(item, step);
            });
            stepPage.backRequested.connect(function (step) {
                if (step == 0) {
                    AppState.page = 0;
                    return;
                }

                stepStack.pop();
            });

            push(stepPage);
        }
    }

    // Busy state while meta.json is being fetched.
    ModalDialog {
        id: loadingDialog

        title: qsTr("Loading templates…")
        showLog: false
        showConfirm: false
        showSpinner: true

        onCancelled: page.abort()
    }

    // Downloads run on a Rust worker thread.
    ModalDialog {
        id: downloadDialog

        title: qsTr("Downloading template files…")
        showLog: false
        showConfirm: false
        showSpinner: page.downloadProgress < 0
        progress: page.downloadProgress
        progressText: page.downloadText

        onCancelled: page.abort()
    }

    // Load or download failure: Retry restarts the failed step, Cancel leaves
    // the templates flow.
    ModalDialog {
        id: errorDialog

        title: page.errorTitle
        description: page.errorMessage
        confirmText: qsTr("Retry")
        showLog: false

        onConfirmed: {
            if (page.repoLoaded) {
                page.errorTitle = "";
                page.errorMessage = "";
                stepStack.clear();
                stepStack.pushStep(2);
            } else {
                page.reset();
            }
        }
        onCancelled: page.abort()
    }

    Component {
        id: templateStepComponent
        TemplateStepPage {}
    }
}
