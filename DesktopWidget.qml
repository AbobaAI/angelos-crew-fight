pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Desktop widget. The host draws the outer frame. Collapsed it is a boxing-glove
// button; a click grows a small arena with two drop cells.
Item {
    id: root

    property var plugin
    property string screenName
    property var widget

    readonly property bool hellish: Theme.hell
    readonly property color ink: hellish ? Theme.hellText : "#f4e4c4"
    readonly property color inkDim: hellish ? Theme.hellTextDim : "#c4b08a"
    readonly property color hall: hellish ? Theme.hellFace : "#140c18"
    readonly property color wood: hellish ? Theme.hellEdge : "#5a3828"
    readonly property color beam: hellish ? Theme.hellBlood : "#8b3030"
    readonly property color gold: hellish ? Theme.hellAccent : "#ffd34d"
    readonly property color well: hellish ? Theme.hellSunken : "#1c1424"
    readonly property real gap: Skin.px(4)
    readonly property real cell: Skin.px(64)
    readonly property real cellH: Skin.px(72)
    readonly property real post: Theme.u * 2
    readonly property real pad: Skin.px(10)
    property real open: Desk.expanded ? 1 : 0
    property real ready: Desk.a && Desk.b ? 1 : 0
    readonly property real cellsW: cell * 2 + gap
    readonly property real actionH: Math.max(botBtn.implicitHeight, fightBtn.implicitHeight)
    readonly property real stageH: Theme.u * 6 + cellH + gap + actionH + Theme.u * 2
    readonly property real openW: Math.max(knob.implicitWidth, cellsW + post * 2 + gap * 2, botBtn.implicitWidth + post * 2, fightBtn.implicitWidth + post * 2)
    readonly property real openH: knob.implicitHeight + gap + stageH

    implicitWidth: knob.implicitWidth + (openW - knob.implicitWidth) * open
    implicitHeight: knob.implicitHeight + (openH - knob.implicitHeight) * open
    clip: true

    Behavior on open {
        NumberAnimation {
            duration: Skin.ms(240)
            easing.type: Easing.OutCubic
        }
    }
    Behavior on ready {
        NumberAnimation {
            duration: Skin.ms(180)
            easing.type: Easing.OutCubic
        }
    }

    function covers(item, x, y) {
        var win = Window.window, a, b, x0, y0, x1, y1;
        if (!win || !win.contentItem || !item)
            return false;
        a = item.mapToItem(win.contentItem, -pad, -pad);
        b = item.mapToItem(win.contentItem, item.width + pad, item.height + pad);
        x0 = Math.min(a.x, b.x);
        y0 = Math.min(a.y, b.y);
        x1 = Math.max(a.x, b.x);
        y1 = Math.max(a.y, b.y);
        return x >= x0 && y >= y0 && x < x1 && y < y1;
    }
    function take(x, y, id, name, avatar) {
        var who;
        if (!screenName || open < 0.75)
            return;
        who = {
            "id": id,
            "name": name,
            "avatar": avatar
        };
        if (covers(cellA, x, y))
            Desk.put(0, who);
        else if (covers(cellB, x, y))
            Desk.put(1, who);
    }
    function gone(who, slot) {
        var i, users;
        if (!who || !/^\d+$/.test(String(who.id)) || DiscordVoice.state !== "call")
            return;
        users = DiscordVoice.users || [];
        for (i = 0; i < users.length; i++)
            if (users[i].id === who.id)
                return;
        Desk.clear(slot);
    }
    function initial(who) {
        return String(who && who.name ? who.name : "?").charAt(0).toUpperCase();
    }

    Connections {
        target: DesktopWidgets
        function onCrewDropped(screen, x, y, id, name, avatar) {
            if (screen !== root.screenName)
                return;
            root.take(x, y, id, name, avatar);
        }
    }
    Connections {
        target: DiscordVoice
        function onUsersChanged() {
            root.gone(Desk.a, 0);
            root.gone(Desk.b, 1);
        }
        function onStateChanged() {
            root.gone(Desk.a, 0);
            root.gone(Desk.b, 1);
        }
    }

    Column {
        width: root.openW
        spacing: root.gap

        Item {
            id: knob
            implicitWidth: Skin.px(26)
            implicitHeight: Skin.px(26)

            PxIcon {
                anchors.centerIn: parent
                visible: !Skin.macWidgets
                pixel: Theme.u
                ink: "#f4e4c4"
                fill: "#e85a4a"
                bitmap: ["..####...", ".#oooo#..", "#oooooo#.", "#o#oo#o#.", "#oooooo#.", ".#oooo#..", "..####...", ".##ww##.."]
            }
            MacIcon {
                anchors.centerIn: parent
                visible: Skin.macWidgets
                name: "shield"
                size: Skin.px(16)
                color: Skin.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Desk.expanded = !Desk.expanded
            }
        }

        Item {
            id: stage
            width: root.openW
            height: root.stageH
            opacity: root.open
            visible: root.open > 0.04

            Rectangle {
                anchors.fill: parent
                color: root.hall
                border.width: Math.max(1, Theme.u)
                border.color: root.wood
            }
            Rectangle {
                width: root.post
                height: parent.height
                color: root.wood
            }
            Rectangle {
                anchors.right: parent.right
                width: root.post
                height: parent.height
                color: root.wood
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.u * 3
                color: root.beam
            }
            Rectangle {
                y: Theme.u * 3
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.u
                color: root.gold
            }
            Rectangle {
                x: root.post + Theme.u
                y: Theme.u * 5
                width: Theme.u * 2
                height: Theme.u * 2
                color: root.gold
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: root.post + Theme.u
                y: Theme.u * 5
                width: Theme.u * 2
                height: Theme.u * 2
                color: root.gold
            }

            Row {
                id: cellRow
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.u * 6
                spacing: root.gap

                Rectangle {
                    id: cellA
                    width: root.cell
                    height: root.cellH
                    color: root.well
                    border.width: Math.max(1, Theme.u)
                    border.color: Desk.a ? root.gold : root.wood

                    PxText {
                        anchors.fill: parent
                        anchors.margins: Theme.u
                        visible: !Desk.a
                        text: I18n.t("Перетащи человечка в ячейку", "Drop a fighter here")
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        kind: "tiny"
                        color: root.inkDim
                    }
                    Image {
                        id: faceA
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.u
                        visible: !!Desk.a
                        width: parent.width - Theme.u * 4
                        height: width
                        source: Desk.a && Desk.a.avatar ? "file://" + Desk.a.avatar : ""
                        sourceSize.width: 48
                        sourceSize.height: 48
                        fillMode: Image.PreserveAspectCrop
                        smooth: false
                        asynchronous: true
                    }
                    PxText {
                        anchors.centerIn: faceA
                        visible: !!Desk.a && faceA.status !== Image.Ready
                        text: root.initial(Desk.a)
                        kind: "title"
                        color: root.ink
                    }
                    PxText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.u
                        visible: !!Desk.a
                        text: Desk.a ? String(Desk.a.name || "") : ""
                        kind: "tiny"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        color: root.ink
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !!Desk.a && root.open > 0.8
                        onClicked: Desk.clear(0)
                    }
                }

                Rectangle {
                    id: cellB
                    width: root.cell
                    height: root.cellH
                    color: root.well
                    border.width: Math.max(1, Theme.u)
                    border.color: Desk.b ? root.gold : root.wood

                    PxText {
                        anchors.fill: parent
                        anchors.margins: Theme.u
                        visible: !Desk.b
                        text: I18n.t("Перетащи человечка в ячейку", "Drop a fighter here")
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        kind: "tiny"
                        color: root.inkDim
                    }
                    Image {
                        id: faceB
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.u
                        visible: !!Desk.b
                        width: parent.width - Theme.u * 4
                        height: width
                        source: Desk.b && Desk.b.avatar ? "file://" + Desk.b.avatar : ""
                        sourceSize.width: 48
                        sourceSize.height: 48
                        fillMode: Image.PreserveAspectCrop
                        smooth: false
                        asynchronous: true
                    }
                    PxText {
                        anchors.centerIn: faceB
                        visible: !!Desk.b && faceB.status !== Image.Ready
                        text: root.initial(Desk.b)
                        kind: "title"
                        color: root.ink
                    }
                    PxText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.u
                        visible: !!Desk.b
                        text: Desk.b ? String(Desk.b.name || "") : ""
                        kind: "tiny"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        color: root.ink
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !!Desk.b && root.open > 0.8
                        onClicked: Desk.clear(1)
                    }
                }
            }

            PxButton {
                id: botBtn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: cellRow.bottom
                anchors.topMargin: root.gap
                opacity: 1 - root.ready
                enabled: root.ready < 0.5
                compact: true
                hell: root.hellish
                text: I18n.t("Добавить бота", "Add a bot")
                onClicked: Desk.askBot()
            }
            PxButton {
                id: fightBtn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: cellRow.bottom
                anchors.topMargin: root.gap
                opacity: root.ready
                enabled: root.ready > 0.5
                accent: true
                compact: true
                hell: root.hellish
                text: I18n.t("В бой!", "Fight!")
                onClicked: Desk.ask()
            }
        }
    }
}
