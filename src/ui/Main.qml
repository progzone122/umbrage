// Copyright (C) 2026 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import umbrage
import Pages 1.0
import UmbrageStyles 1.0
import Components 1.0

ApplicationWindow {
    id: root
    visible: true
    title: qsTr("umbrage")

    width: 900
    height: 500

    topPadding: Styles.spacing
    bottomPadding: Styles.spacing
    leftPadding: Styles.spacing
    rightPadding: Styles.spacing

    background: Rectangle {
        color: Styles.background
    }

    readonly property int pageSteps: 0
    readonly property int pageWaitConn: 1
    readonly property int pageMain: 2
    readonly property int pageTemplates: 3
    readonly property int pageSetup: 4

    Component.onCompleted: AppState.refreshSetup()

    function setPage(page) {
        AppState.page = page;
    }

    // Re-check prerequisites and route through the setup page if needed.
    function continueToDevice() {
        AppState.refreshSetup();
        root.setPage(AppState.need_setup ? root.pageSetup : root.pageWaitConn);
    }

    property var steps: [
        {
            title: "Hi! It`s Umbrage!",
            text: "Before we begin, would you like to use a user repository to retrieve the templates, or would you prefer to specify your own files?",
            image: "qrc:/assets/umbrage-icon2.svg",
            buttons: [
                {
                    text: "Use Templates",
                    outline: false,
                    onClicked: function () {
                        root.setPage(root.pageTemplates);
                    }
                },
                {
                    text: "Choose Manually",
                    outline: true,
                    onClicked: function (page) {
                        page.goNext();
                    }
                }
            ]
        },
        {
            title: "Download Agent",
            text: "Select the DA file to be used during interactions with the device.",
            image: "qrc:/assets/da_icon.svg",
            buttons: [
                {
                    text: "Choose file",
                    outline: false,
                    onClicked: function (page) {
                        page.chooseFile();
                    }
                }
            ]
        },
        {
            title: "Auth File",
            text: "Select the auth file if DAA is enabled in device.",
            image: "qrc:/assets/auth_icon.svg",
            buttons: [
                {
                    text: "Choose file",
                    outline: false,
                    onClicked: function (page) {
                        page.chooseFile();
                    }
                },
                {
                    text: "Skip",
                    outline: true,
                    onClicked: function (page) {
                        page.skip();
                    }
                }
            ]
        },
        {
            title: "Preloader File",
            text: "Do you have a preloader dump from your device?\nIt can be used for certain exploits.",
            image: "qrc:/assets/preloader_icon.svg",
            buttons: [
                {
                    text: "Choose file",
                    outline: false,
                    onClicked: function (page) {
                        page.chooseFile();
                    }
                },
                {
                    text: "Skip",
                    outline: true,
                    onClicked: function (page) {
                        page.skip();
                    }
                }
            ]
        },
    ]

    ColumnLayout {
        anchors.fill: parent

        Connections {
            target: AppState
            function onPageChanged() {
                if (AppState.page === root.pageSteps) {
                    stack.clear();
                    stack.push(setupComponent);
                }
            }
        }

        TopPanel {
            Layout.fillWidth: true
            show_step_badges: AppState.page == root.pageSteps
        }

        StackView {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: AppState.page === root.pageSteps

            Component.onCompleted: stack.push(setupComponent)
        }

        SetupPage {
            visible: AppState.page === root.pageSetup
            onContinueRequested: root.setPage(root.pageWaitConn)
        }

        WaitConnectionPage {
            visible: AppState.page === root.pageWaitConn
        }

        TemplatesPage {
            visible: AppState.page === root.pageTemplates
            onFinished: root.continueToDevice()
            onCancelled: root.setPage(root.pageSteps)
        }

        MainPage {
            visible: AppState.page === root.pageMain
        }
    }

    Component {
        id: setupComponent

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StackView {
                id: stepStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                Component.onCompleted: pushStep(0)

                function pushStep(step) {
                    var page = stepPageComponent.createObject(stepStack, {
                        step: step,
                        stepTitle: root.steps[step].title,
                        stepText: root.steps[step].text,
                        stepImage: root.steps[step].image,
                        isLastStep: step === root.steps.length - 1
                    });

                    page.buttons = root.steps[step].buttons;
                    page.nextRequested.connect(function (nextStep) {
                        stepStack.pushStep(nextStep);
                    });
                    page.backRequested.connect(stepStack.pop);
                    page.finishedRequested.connect(function () {
                        root.continueToDevice();
                    });

                    push(page);
                }
            }
        }
    }

    Component {
        id: stepPageComponent
        StepPage {}
    }
}
