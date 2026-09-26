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
import UmbrageKit 1.0

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

    ColumnLayout {
        anchors.fill: parent

        Connections {
            target: AppState
            function onPageChanged() {
                if (AppState.page === root.pageSteps) {
                    stack.clear();
                    stack.push(stepsPageComponent);
                } else if (AppState.page === root.pageWaitConn && AppState.skip_conn_page) {
                    root.setPage(root.pageMain);
                }
            }
        }

        TopPanel {
            Layout.fillWidth: true
            show_step_badges: AppState.page == root.pageSteps
        }

        StackLayout {
            id: pageStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: AppState.page

            StackView {
                id: stack
                Layout.fillWidth: true
                Layout.fillHeight: true
                Component.onCompleted: stack.push(stepsPageComponent)
            }

            WaitConnectionPage {}

            MainPage {}

            TemplatesPage {
                onFinished: root.continueToDevice()
                onCancelled: root.setPage(root.pageSteps)
            }

            SetupPage {
                onContinueRequested: root.setPage(root.pageWaitConn)
            }
        }
    }

    Component {
        id: stepsPageComponent
        StepsPage {
            onFinished: root.continueToDevice()
            onGoTemplates: root.setPage(root.pageTemplates)
        }
    }
}
