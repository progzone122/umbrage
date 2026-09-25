import QtQuick
import QtQuick.Controls
import UmbrageStyles 1.0

Button {
    id: root

    property color backgroundColor: Styles.surfaceAlt
    property color foregroundColor: Styles.surfaceForeground

    property string iconPath: ""

    // Button.TextOnly, Button.IconOnly, Button.TextBesideIcon, etc.
    property int iconDisplay: Button.TextOnly

    enabled: false

    padding: 10
    spacing: 8

    font.bold: true

    // Text color comes from the palette `buttonText` role, so the default
    // contentItem keeps the icon rendering.
    palette.buttonText: foregroundColor
    palette.disabled.buttonText: foregroundColor

    display: iconDisplay

    icon.source: iconPath !== "" ? iconPath : ""

    icon.color: foregroundColor
    icon.width: 16
    icon.height: 16

    background: Rectangle {
        color: root.backgroundColor
        radius: Styles.radiusMedium
    }
}
