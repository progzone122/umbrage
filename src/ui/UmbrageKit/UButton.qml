import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import UmbrageStyles 1.0

Button {
    id: root

    property color backgroundColor: Styles.surface
    property color foregroundColor: Styles.surfaceForeground

    property string iconPath: ""

    // Button.TextOnly, Button.IconOnly, Button.TextBesideIcon, etc.
    property int iconDisplay: Button.TextOnly

    property bool disabled: false

    property bool outline: false

    // Background radius. Set to half the size for a round button.
    property int radius: Styles.radiusMedium

    // Horizontal alignment of the icon/text content:
    // Qt.AlignLeft, Qt.AlignHCenter (default), or Qt.AlignRight.
    property int contentAlignment: Qt.AlignHCenter

    enabled: !root.disabled

    padding: 10
    spacing: 8

    font.bold: true

    // Text and icon are colored from this; `surfaceAlt` when disabled.
    readonly property color effectiveForeground: root.disabled ? Styles.surfaceAlt : root.outline && (root.hovered || root.down) ? "white" : foregroundColor

    readonly property color effectiveBackground: root.outline ? (root.down ? Styles.outlineFillPressed : root.hovered ? Styles.outline : "transparent") : (root.disabled ? Styles.surfaceDisabled : root.down ? Qt.darker(root.backgroundColor, 1.15) : root.hovered ? Qt.lighter(root.backgroundColor, 1.1) : root.backgroundColor)

    palette.buttonText: effectiveForeground
    palette.disabled.buttonText: effectiveForeground

    display: iconDisplay

    icon.source: iconPath !== "" ? iconPath : ""
    icon.color: effectiveForeground
    icon.width: 16
    icon.height: 16

    contentItem: IconLabel {
        spacing: root.spacing
        mirrored: root.mirrored
        display: root.iconDisplay

        icon: root.icon
        text: root.text
        font: root.font
        color: root.palette.buttonText

        alignment: root.contentAlignment | Qt.AlignVCenter
    }

    background: Rectangle {
        radius: root.radius

        border.width: root.outline ? Styles.outlineBorderWidth : 0

        border.color: root.outline ? (root.down ? Styles.outlineFillPressed : Styles.outline) : "transparent"

        color: root.effectiveBackground
    }
}
