import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UmbrageKit 1.0
import UmbrageStyles 1.0

UButton {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 48

    backgroundColor: Styles.surfaceHigh
    foregroundColor: Styles.surfaceForeground
    contentAlignment: Qt.AlignLeft

    font.pixelSize: 14
}
