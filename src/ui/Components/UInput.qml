import QtQuick
import QtQuick.Controls
import UmbrageStyles 1.0

// Reusable styled text input, matching the design tokens in Styles.qml.
TextField {
    id: root

    color: Styles.textPrimary
    placeholderTextColor: Styles.surfaceAlt
    font.pixelSize: 16
    selectByMouse: true

    leftPadding: 12
    rightPadding: 12
    topPadding: 10
    bottomPadding: 10

    background: Rectangle {
        radius: Styles.radiusMedium
        color: Styles.surface
    }
}
