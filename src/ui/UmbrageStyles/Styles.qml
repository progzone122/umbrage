pragma Singleton
import QtQuick

QtObject {
    readonly property int spacing: 12
    readonly property int radiusMedium: 8

    readonly property color background: "#131313"

    readonly property color surface: "#404040"
    readonly property color surfaceVariant: "#343434"
    readonly property color surfaceHigh: "#676565"

    readonly property color surfaceForeground: "#FFFFFF"
    readonly property color surfaceDisabled: "#303030"

    readonly property color surfaceAlt: "#565656"

    // Outline (bordered) button states.
    readonly property color outline: "#4F4D4D"
    readonly property color outlineHover: "#807D7D"
    readonly property color outlinePressed: "#4F4D4D"
    readonly property color outlineFillHover: "#66676565"
    readonly property color outlineFillPressed: "#33676565"
    readonly property int outlineBorderWidth: 2

    readonly property color error: "#E57373"

    readonly property color textPrimary: "#FFFFFF"
}
