import QtQuick
import UmbrageStyles 1.0

// Reusable text with preset typographic scales, matching the design tokens in
// Styles.qml. Prefer `level` (which sets font size/weight) over hand-writing
// `font.pixelSize`/`font.weight` on every `Text`.
Text {
    id: root

    // "title"  -> 22px / bold   (page or section heading)
    // "body"   -> 18px / medium (supporting or hero text)
    // "label"  -> 16px / normal (paragraph / description)
    // "small"  -> 14px / normal (hints, captions)
    property string level: "body"

    // Convenience: center text horizontally. Keeps the inline `horizontalAlignment`
    // out of call sites.
    property bool centered: false

    horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
    verticalAlignment: Text.AlignVCenter
    wrapMode: Text.WordWrap

    color: Styles.textPrimary

    font.pixelSize: switch (root.level) {
    case "title":
        return 22;
    case "body":
        return 18;
    case "label":
        return 16;
    case "small":
        return 14;
    default:
        return 18;
    }

    font.weight: switch (root.level) {
    case "title":
        return 700;
    case "body":
        return 500;
    case "label":
        return 400;
    case "small":
        return 400;
    default:
        return 400;
    }
}
