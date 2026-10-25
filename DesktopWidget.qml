pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Desktop widget. The host draws the frame. Collapsed it is a small button; a click
// grows it into two cells. Walking call people can be dropped into a cell.
Item {
    id: root

    property var plugin
    property string screenName
    property var widget

    readonly property bool hellish: Theme.hell
    readonly property color ink: hellish ? Theme.hellText : Skin.text
    readonly property color inkDim: hellish ? Theme.hellTextDim : Skin.textDim
    readonly property real gap: Skin.px(4)
    readonly property real cell: Skin.px(56)
    readonly property real pad: Skin.px(10)
    property real open: Desk.expanded ? 1 : 0
    property real ready: Desk.a && Desk.b ? 1 : 0
    readonly property real openW: Math.max(knob.implicitWidth, cell * 2 + gap)
    readonly property real openH: knob.implicitHeight + gap + cell + (fightBtn.implicitHeight + gap) * ready

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

        PxButton {
            id: knob
            compact: true
            icon: "heart"
            hell: root.hellish
            onClicked: Desk.expanded = !Desk.expanded
        }

        Row {
            id: cellRow
            spacing: root.gap
            opacity: root.open
            visible: root.open > 0.04

            Rectangle {
                id: cellA
                width: root.cell
                height: root.cell
                radius: Skin.radius
                color: Skin.sunken
                border.width: Skin.macWidgets ? 0 : Math.max(1, Theme.u)
                border.color: Desk.a ? Skin.accent : Skin.separator

                PxText {
                    anchors.centerIn: parent
                    visible: !Desk.a
                    text: "+"
                    kind: "title"
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
                height: root.cell
                radius: Skin.radius
                color: Skin.sunken
                border.width: Skin.macWidgets ? 0 : Math.max(1, Theme.u)
                border.color: Desk.b ? Skin.accent : Skin.separator

                PxText {
                    anchors.centerIn: parent
                    visible: !Desk.b
                    text: "+"
                    kind: "title"
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

        Item {
            width: cellRow.width
            height: fightBtn.implicitHeight * root.ready
            clip: true
            opacity: root.ready

            PxButton {
                id: fightBtn
                width: parent.width
                accent: true
                compact: true
                hell: root.hellish
                text: I18n.t("В бой!", "Fight!")
                onClicked: Desk.ask()
            }
        }
    }
}
