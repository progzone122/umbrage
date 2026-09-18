import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UmbrageStyles 1.0

TextField {
    id: root

    // Text and placeholder colors, overridable per instance.
    property color textColor: Styles.textPrimary
    property color placeholderColor: Qt.lighter(Styles.surfaceForeground, 0.7)

    // Font scale, overridable per instance.
    property int fontSize: 16

    // Padding, overridable per instance.
    property real uiLeftPadding: 12
    property real uiRightPadding: 12
    property real uiTopPadding: 10
    property real uiBottomPadding: 10

    // Background color and corner radius, overridable per instance.
    property color backgroundColor: Styles.surfaceHigh
    property int backgroundRadius: Styles.radiusMedium

    // If true, focus when the field becomes visible.
    property bool autofocusOnVisible: false

    implicitHeight: root.uiTopPadding + root.uiBottomPadding + font.pixelSize

    Layout.fillWidth: true

    onVisibleChanged: {
        if (visible && autofocusOnVisible)
            forceActiveFocus();
    }

    color: root.textColor
    placeholderTextColor: root.placeholderColor
    font.pixelSize: root.fontSize
    selectByMouse: true

    leftPadding: root.uiLeftPadding
    rightPadding: root.uiRightPadding
    topPadding: root.uiTopPadding
    bottomPadding: root.uiBottomPadding

    background: Rectangle {
        radius: root.backgroundRadius
        color: root.backgroundColor
    }
}
