import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UmbrageStyles 1.0

// A clickable row styled like UInput: a text label on the left and a checkmark
// on the right. Mirrors UInput's background/padding tokens so it sits naturally
// next to other form fields.
Rectangle {
    id: root

    // Label text shown on the left.
    property string text: ""

    // Checked state, bound both ways.
    property bool checked: false

    // Text color, overridable per instance.
    property color textColor: Styles.textPrimary

    // Font size, overridable per instance.
    property int fontSize: 16

    // Padding, overridable per instance.
    property real uiLeftPadding: 12
    property real uiRightPadding: 12
    property real uiTopPadding: 10
    property real uiBottomPadding: 10

    // Background colors and corner radius, overridable per instance.
    property color backgroundColor: Styles.surfaceHigh
    property color hoveredBackgroundColor: Qt.lighter(Styles.surfaceHigh, 1.1)
    property color pressedBackgroundColor: Qt.darker(Styles.surfaceHigh, 1.4)
    property color focusedBackgroundColor: Qt.darker(Styles.surfaceHigh, 1.2)
    property int backgroundRadius: Styles.radiusMedium

    // Checkmark indicator colors, overridable per instance.
    property color checkColor: Styles.surfaceForeground
    property color checkedBackgroundColor: Styles.surfaceForeground

    implicitHeight: root.uiTopPadding + root.uiBottomPadding + root.fontSize

    Layout.fillWidth: true
    Layout.preferredHeight: 44

    focus: true
    activeFocusOnTab: true

    radius: root.backgroundRadius
    color: root.activeFocus ? root.focusedBackgroundColor : mouseArea.pressed ? root.pressedBackgroundColor : mouseArea.containsMouse ? root.hoveredBackgroundColor : root.backgroundColor

    // Click the row to toggle the check state.
    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.forceActiveFocus();
            root.checked = !root.checked;
        }
    }

    // Keyboard support via the implicit Control focus handling.
    Keys.onSpacePressed: root.checked = !root.checked
    Keys.onEnterPressed: root.checked = !root.checked
    Keys.onReturnPressed: root.checked = !root.checked

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.uiLeftPadding
        anchors.rightMargin: root.uiRightPadding
        anchors.topMargin: root.uiTopPadding
        anchors.bottomMargin: root.uiBottomPadding

        spacing: 12

        UText {
            Layout.fillWidth: true

            text: root.text
            color: root.textColor
            font.pixelSize: root.fontSize
        }

        Rectangle {
            id: checkBox

            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            Layout.alignment: Qt.AlignVCenter

            radius: 2
            color: root.checked ? root.checkedBackgroundColor : "transparent"
            border.width: 2
            border.color: root.checkColor

            Text {
                id: checkText

                anchors.centerIn: parent
                text: "✓"
                color: Styles.surface
                font.pixelSize: 12
                font.bold: true
                visible: root.checked
            }
        }
    }
}
