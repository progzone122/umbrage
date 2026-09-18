import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import umbrage
import UmbrageStyles 1.0
import Components 1.0

Page {
    id: page

    background: null

    property int step: 0

    property string stepTitle: ""
    property string stepText: ""
    property var stepItems: []

    // Layout fills up to maxContentWidth, then centers.
    readonly property int maxContentWidth: 600
    readonly property int contentMargin: 24

    signal itemSelected(var item, int step)
    signal backRequested(int step)

    property string searchQuery: ""
    property bool searching: false

    function matchesSearch(item) {
        if (page.searchQuery === "")
            return true;

        var query = page.searchQuery.toLowerCase();

        if (item.title && item.title.toLowerCase().indexOf(query) !== -1)
            return true;
        if (item.text && item.text.toLowerCase().indexOf(query) !== -1)
            return true;

        if (item.badges) {
            for (var i = 0; i < item.badges.length; i++) {
                if (item.badges[i].text && item.badges[i].text.toLowerCase().indexOf(query) !== -1)
                    return true;
            }
        }

        return false;
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - page.contentMargin * 2, page.maxContentWidth)
        height: Math.min(implicitHeight, parent.height - page.contentMargin * 2)
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: Styles.spacing

            ColumnLayout {
                id: headerTexts

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 4

                visible: !page.searching

                UText {
                    Layout.fillWidth: true
                    level: "title"
                    text: qsTr(page.stepTitle)
                }

                UText {
                    Layout.fillWidth: true
                    level: "body"
                    text: qsTr(page.stepText)
                }
            }

            UInput {
                id: searchField

                Layout.preferredHeight: 44
                Layout.alignment: Qt.AlignTop

                backgroundColor: Styles.surface
                visible: page.searching
                autofocusOnVisible: true
                activeFocusOnTab: true

                placeholderText: qsTr("Search…")

                onTextChanged: page.searchQuery = text
            }

            Button {
                id: searchButton

                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                Layout.alignment: Qt.AlignTop

                display: Button.IconOnly
                icon.source: page.searching ? "qrc:/assets/collapse-icon.svg" : "qrc:/assets/search-icon.svg"
                icon.color: Styles.surfaceForeground
                icon.width: 18
                icon.height: 18

                background: Rectangle {
                    radius: width / 2
                    color: searchButton.down ? Qt.darker(Styles.surface, 1.15) : searchButton.hovered ? Qt.lighter(Styles.surface, 1.1) : Styles.surface
                }

                onClicked: {
                    page.searching = !page.searching;
                    page.searchQuery = "";
                    searchField.text = "";
                }
            }
        }

        Flickable {
            id: listFlickable

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: listColumn.implicitHeight
            contentWidth: width
            contentHeight: listColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: listColumn

                width: parent.width
                spacing: Styles.spacing

                Repeater {
                    model: page.stepItems

                    delegate: TemplateItem {
                        Layout.fillWidth: true
                        visible: page.matchesSearch(modelData)
                        type: modelData.type
                        title: modelData.title
                        text: modelData.text
                        badges: modelData.badges
                        showText: modelData.text !== ""
                        showBadges: modelData.badges.length > 0
                        onClicked: page.itemSelected(modelData, page.step)
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10

            UButton {
                id: backButton

                text: qsTr("Back")

                onClicked: page.backRequested(page.step)
            }
        }
    }
}
