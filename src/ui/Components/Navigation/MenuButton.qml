import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UmbrageStyles 1.0

Button {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 48

    background: Rectangle {
        radius: Styles.radiusMedium
        color: root.down ? Styles.surfaceAlt : root.hovered ? Qt.lighter(Styles.surfaceHigh, 1.1) : Styles.surfaceHigh
    }

    contentItem: Label {
        text: root.text

        color: root.hovered || root.down ? Qt.lighter(Styles.surfaceForeground, 1.2) : Styles.surfaceForeground
        font.pixelSize: 14
        font.bold: true

        verticalAlignment: Text.AlignVCenter
        leftPadding: Styles.spacing
        rightPadding: Styles.spacing
    }
}
