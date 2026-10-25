pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Desktop widget. The host draws the outer frame. Collapsed it is a fist
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
    // Same art pixel as the walking crew, and the bigger "main" size, so a whole
    // person stands in the cell with the feet and the head inside it.
    readonly property real crewU: Math.max(1, Theme.u + (Config.discord.crewSize === "l" ? 1 : Config.discord.crewSize === "s" ? -1 : 0))
    readonly property real figU: Math.max(crewU + 1, Math.round(crewU * 1.5))
    readonly property real cell: figU * 18 + Theme.u * 6
    readonly property real cellH: figU * 32 + Theme.u * 12
    readonly property real post: Theme.u * 2
    readonly property real pad: Skin.px(10)
    readonly property var coats: ["#e8668b", "#6ec3e8", "#f0b44c", "#8bd17c", "#b48cf0", "#f08a5d", "#5dd6c0", "#e0e070"]
    // 0..1 drives opacity and scale only. The frame size flips once, not every frame,
    // so the desktop grid does not step the window along.
    property real open: 0
    property bool roomy: false
    property bool wantOpen: Desk.expanded
    property real ready: Desk.a && Desk.b ? 1 : 0
    readonly property real cellsW: cell * 2 + gap
    readonly property real actionH: Math.max(botBtn.implicitHeight, fightBtn.implicitHeight)
    readonly property real stageH: Theme.u * 6 + cellH + gap + actionH + Theme.u * 2
    readonly property real openW: Math.max(knob.implicitWidth, cellsW + post * 2 + gap * 2, botBtn.implicitWidth + post * 2, fightBtn.implicitWidth + post * 2)
    readonly property real openH: knob.implicitHeight + gap + stageH

    implicitWidth: roomy ? openW : knob.implicitWidth
    implicitHeight: roomy ? openH : knob.implicitHeight
    clip: true

    NumberAnimation {
        id: openAnim
        target: root
        property: "open"
        duration: Skin.ms(260)
        easing.type: Easing.OutCubic
        onFinished: {
            if (!Desk.expanded)
                root.roomy = false
        }
    }
    onWantOpenChanged: root.syncOpen()
    Component.onCompleted: if (Desk.expanded) {
        root.roomy = true
        root.open = 1
    }
    function syncOpen() {
        if (wantOpen) {
            roomy = true
            openAnim.to = 1
            openAnim.restart()
        } else {
            openAnim.to = 0
            openAnim.restart()
        }
    }
    function coatOf(id) {
        var s = String(id || ""), h = 0, i
        for (i = 0; i < s.length; i++)
            h = (h * 33 + s.charCodeAt(i)) % 4096
        return coats[h % coats.length]
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
            implicitWidth: Skin.macWidgets ? Skin.px(26) : fistIcon.width + Theme.u * 2
            implicitHeight: Skin.macWidgets ? Skin.px(26) : fistIcon.height + Theme.u * 2
            width: implicitWidth
            height: implicitHeight

            PxIcon {
                id: fistIcon
                anchors.centerIn: parent
                visible: !Skin.macWidgets
                pixel: Theme.u
                ink: root.ink
                fill: "#e85a4a"
                fill3: root.gold
                bitmap: ["...................y.................", "...................y.................", "...........y......y.......y..........", "............y.....y......y...........", "............y......y.....y...........", ".............y.....y....y............", "......y......y....y.....y......y.....", ".......y......y...y....y......y......", "........y....................y.......", ".........y........####......y........", "............####.#oooo#.###..........", ".y.........#oooo#oooooo#ooo#.......y.", "..yy....####oooo#oooooo#oooo#....yy..", "....y..#ooo#oooooooooooooooo#..yy....", ".......#oooooooooooooooooooo#........", ".......#oooooooooooooo#ooooo#........", ".......#oooooooo#ooooo#ooooo#........", ".......#ooo#oooo#ooooo#ooooo#........", ".yy....#ooo#oooo#ooooo#ooooo#...yy..y", "y..yy..#ooo#oooo#ooooo#ooooo##....yy.", ".......#ooo#oooo#ooooo#ooooo##.......", ".......#ooo#oooo#ooooo#ooooo#o#......", "........###.#ooo#ooooo#ooooo#o#......", ".............###.#oooo##ooo#oo#......", ".....y............####oo###oooo#.....", "...yy.............#ooo#ooooooo##..y..", "..y........y.......#ooo#ooooo#.....y.", "..........y....y....#########.......y", ".........y.....y.....................", "........y.....y...y..........y.......", ".......y......y...y....y......y......", "......y......y.....y....y......y.....", ".............y.....y....y............", "............y.....y......y...........", "............y.....y......y...........", "...........y.......y......y..........", "...................y................."]
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
            scale: 0.92 + 0.08 * root.open
            transformOrigin: Item.Top
            visible: root.roomy

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
                    clip: true
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
                    StillGuy {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: nameA.top
                        anchors.bottomMargin: Theme.u
                        visible: !!Desk.a
                        u: root.figU
                        coat: root.coatOf(Desk.a ? Desk.a.id : "")
                        whoName: Desk.a ? String(Desk.a.name || "") : ""
                        whoAvatar: Desk.a && Desk.a.avatar ? String(Desk.a.avatar) : ""
                    }
                    PxText {
                        id: nameA
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
                    clip: true
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
                    StillGuy {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: nameB.top
                        anchors.bottomMargin: Theme.u
                        visible: !!Desk.b
                        u: root.figU
                        coat: root.coatOf(Desk.b ? Desk.b.id : "")
                        whoName: Desk.b ? String(Desk.b.name || "") : ""
                        whoAvatar: Desk.b && Desk.b.avatar ? String(Desk.b.avatar) : ""
                    }
                    PxText {
                        id: nameB
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

    // A crew person standing still. No step timer: the legs and arms stay down.
    component StillGuy: Item {
        id: guy

        property real u: 2
        property color coat: "#e8668b"
        property string whoName: ""
        property string whoAvatar: ""

        width: u * 18
        height: u * 32

        Rectangle {
            x: guy.u * 5
            y: guy.height - guy.u * 5
            width: guy.u * 3
            height: guy.u * 5
            color: "#2b2433"
        }
        Rectangle {
            x: guy.u * 10
            y: guy.height - guy.u * 5
            width: guy.u * 3
            height: guy.u * 5
            color: "#2b2433"
        }
        Rectangle {
            x: guy.u * 4
            y: guy.height - guy.u * 13
            width: guy.u * 10
            height: guy.u * 8
            color: guy.coat
            border.width: Math.max(1, guy.u)
            border.color: Qt.darker(guy.coat, 1.6)
        }
        Rectangle {
            x: guy.u * 2
            y: guy.height - guy.u * 12
            width: guy.u * 2
            height: guy.u * 6
            color: Qt.darker(guy.coat, 1.25)
        }
        Rectangle {
            x: guy.u * 14
            y: guy.height - guy.u * 12
            width: guy.u * 2
            height: guy.u * 6
            color: Qt.darker(guy.coat, 1.25)
        }
        Rectangle {
            x: (guy.width - width) / 2
            y: guy.height - guy.u * 13 - height
            width: guy.u * 14
            height: guy.u * 14
            color: "#2b2433"
            Rectangle {
                x: guy.u
                y: guy.u
                width: parent.width - guy.u * 2
                height: parent.height - guy.u * 2
                color: guy.coat
                PxText {
                    anchors.centerIn: parent
                    visible: pic.status !== Image.Ready
                    color: "#2b2433"
                    text: guy.whoName.length ? guy.whoName.charAt(0).toUpperCase() : "?"
                }
                Image {
                    id: pic
                    anchors.fill: parent
                    source: guy.whoAvatar ? "file://" + guy.whoAvatar : ""
                    sourceSize.width: 32
                    sourceSize.height: 32
                    fillMode: Image.PreserveAspectCrop
                    smooth: false
                    asynchronous: true
                }
            }
        }
    }
}
