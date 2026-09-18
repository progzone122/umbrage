import QtQuick
import QtQuick.Controls
import UmbrageStyles 1.0

TextField {
    id: root

    // Text and placeholder colors, overridable per instance.
    property color textColor: Styles.textPrimary
    property color placeholderColor: Styles.surfaceAlt

    // Font scale, overridable per instance.
    property int fontSize: 16

    // Padding, overridable per instance.
    property real leftInset: 12
    property real rightInset: 12
    property real topInset: 10
    property real bottomInset: 10

    // Background color and corner radius, overridable per instance.
    property color backgroundColor: Styles.surface
    property int backgroundRadius: Styles.radiusMedium

    implicitHeight: root.topInset + root.bottomInset + font.pixelSize

    Layout.fillWidth: true

    color: root.textColor
    placeholderTextColor: root.placeholderColor
    font.pixelSize: root.fontSize
    selectByMouse: true

    leftPadding: root.leftInset
    rightPadding: root.rightInset
    topPadding: root.topInset
    bottomPadding: root.bottomInset

    background: Rectangle {
        radius: root.backgroundRadius
        color: root.backgroundColor
    }
}
