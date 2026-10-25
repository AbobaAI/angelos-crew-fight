pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Pre-fight card: fighters, weapons, arena, rounds. Secondary switches sit in «Дополнительно».
// Motion is NumberAnimation / SequentialAnimation only (no per-frame JS). Eco mode shortens it.
// Tooltips follow AngelOS StartButtonCell: there is no tooltip widget in qs.widgets.
PanelWindow {
    id: win

    required property var game

    screen: Shell.focusedScreen || Shell.primaryScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "angelos-crew-fight-picker"

    readonly property int anim: ecoOn ? 1 : 180
    readonly property var pool: game.pickDemo ? game.fakes : game.people
    readonly property var weaponIds: ["random", "fists", "slipper", "bat", "fish", "mic", "keyboard", "bread", "laser"]
    readonly property var arenaIds: ["random", "dojo", "desert", "fjord", "plaza", "terem"]
    readonly property var roundIds: [1, 3, 5, 0]
    readonly property var rateIds: ["rare", "normal", "often"]
    readonly property string hintLine: (game.pickDemo ? ((game.crewHint || game.t("Демо-бойцы.", "Demo fighters.")) + " ") : "")
        + (!game.first ? game.t("Выбери первого бойца", "Pick the first fighter")
            : !game.second ? game.t("Против кого " + game.first.name + "?", "Who fights " + game.first.name + "?")
            : game.t("Выбери оружие и жми «В бой!»", "Pick weapons and hit “Fight!”"))
    readonly property real lift: ecoOn ? 0 : bob * Theme.u * 2

    property bool snd: game.soundOn
    property int vol: game.soundVol
    property bool shld: game.shieldOn
    property bool sup: game.superOn
    property bool picks: game.pickupsOn
    property string rate: game.pickupRate
    property bool afx: game.arenaFx
    property bool ecoOn: game.eco
    property string arenaId: game.arenaPick
    property bool moreOpen: false

    property int aIdx: 0
    property int bIdx: 1
    property bool showB: false
    property real bob: 0
    property real flake: 0
    property real faceScale: 1
    property real hallScale: 1
    property real dimIn: 0
    property real cardIn: 0

    property string tip: ""
    property real tipX: 8
    property real tipY: 8
    property bool tipShow: false
    property var tipItem: null
    property bool shotDone: false

    function hallAt(i) {
        if (i === 1) return "desert"
        if (i === 2) return "fjord"
        if (i === 3) return "plaza"
        if (i === 4) return "terem"
        return "dojo"
    }
    function arenaName(id) {
        if (id === "dojo") return game.t("додзё", "dojo")
        if (id === "desert") return game.t("пустыня", "desert")
        if (id === "fjord") return game.t("фьорд", "fjord")
        if (id === "plaza") return game.t("площадь", "plaza")
        if (id === "terem") return game.t("терем", "terem")
        return game.t("случайная", "random")
    }
    function arenaTip(id) {
        if (id === "dojo") return I18n.t("Додзё: у края татами скользко.", "Dojo: the mat edge is slippery.")
        if (id === "desert") return I18n.t("Пустыня: иногда дует песок.", "Desert: sand blows through now and then.")
        if (id === "fjord") return I18n.t("Фьорд: на льду скользко.", "Fjord: the ice is slippery.")
        if (id === "plaza") return I18n.t("Площадь: в центре копится супер.", "Plaza: the center fills the super meter.")
        if (id === "terem") return I18n.t("Терем: снег у забора тормозит.", "Terem: snow by the fence slows you.")
        return I18n.t("Зал выберется сам в начале боя.", "The hall is drawn when the fight starts.")
    }
    function roundLabel(n) {
        return n === 0 ? game.t("до нокаута", "to KO") : String(n)
    }
    function roundTip(n) {
        return n === 0
            ? I18n.t("Бой идёт, пока кто-то не упадёт.", "The fight goes on until someone drops.")
            : I18n.t("Сколько раундов в этом матче.", "How many rounds this match lasts.")
    }
    function rateLabel(id) {
        if (id === "rare") return game.t("редко", "rare")
        if (id === "often") return game.t("часто", "often")
        return game.t("обычно", "normal")
    }
    function weaponById(id) {
        var list = game.weapons
        if (!list) return null
        for (var i = 0; i < list.length; i++)
            if (list[i].id === id) return list[i]
        return null
    }
    function pickPerson(person) {
        var id = person.id
        if (game.first && game.first.id === id) {
            game.first = game.second
            game.second = null
            game.wpA = game.wpB
            game.wpB = "random"
        } else if (game.second && game.second.id === id) {
            game.second = null
        } else if (!game.first) {
            game.first = person
        } else {
            game.second = person
        }
    }
    function setWeapon(index, id) {
        if (index === 0) game.wpA = id
        else game.wpB = id
    }
    function chooseArena(id) {
        if (arenaId === id) return
        arenaId = id
        game.setCfg("gpArena", id)
        bumpHall()
    }
    function chooseRate(id) {
        rate = id
        game.setCfg("gpPickupRate", id)
    }
    function bumpFaces() {
        if (ecoOn) return
        facePulse.restart()
    }
    function bumpHall() {
        if (ecoOn) return
        hallPulse.restart()
    }
    function armTip(item, text) {
        if (!item || !text) return
        tipItem = item
        tip = text
        tipShow = false
        tipDelay.restart()
    }
    function clearTip(item) {
        if (item && tipItem !== item) return
        tipDelay.stop()
        tipShow = false
        tipItem = null
    }
    function placeTip() {
        if (!tipItem) return
        var p = tipItem.mapToItem(stage, 0, 0)
        var tw = Math.max(1, tipBox.width)
        var th = Math.max(1, tipBox.height)
        var x = p.x + tipItem.width / 2 - tw / 2
        var y = p.y - th - Theme.u * 2
        if (x < 8) x = 8
        if (x > stage.width - 8 - tw) x = Math.max(8, stage.width - 8 - tw)
        if (y < 8) y = p.y + tipItem.height + Theme.u * 2
        if (y > stage.height - 8 - th) y = Math.max(8, stage.height - 8 - th)
        tipX = x
        tipY = y
    }

    function applyShotHall() {
        if (game.pickShot !== "" && game.pickHall !== "")
            arenaId = game.pickHall
    }
    Component.onCompleted: {
        applyShotHall()
        dimIn = 1
        cardIn = 1
        keys.forceActiveFocus()
    }

    Connections {
        target: win.game
        function onFirstChanged() { win.bumpFaces() }
        function onSecondChanged() { win.bumpFaces() }
        function onPickShotChanged() {
            if (win.game.pickShot !== "")
                win.shotDone = false
            win.applyShotHall()
        }
        function onPickHallChanged() { win.applyShotHall() }
    }

    SequentialAnimation {
        id: bobAnim
        running: !win.ecoOn
        loops: Animation.Infinite
        NumberAnimation { target: win; property: "bob"; to: 1; duration: 700; easing.type: Easing.InOutQuad }
        NumberAnimation { target: win; property: "bob"; to: 0; duration: 700; easing.type: Easing.InOutQuad }
    }
    SequentialAnimation {
        id: flakeAnim
        running: !win.ecoOn
        loops: Animation.Infinite
        NumberAnimation { target: win; property: "flake"; to: 1; duration: 3200; easing.type: Easing.Linear }
        PropertyAction { target: win; property: "flake"; value: 0 }
    }
    Timer {
        interval: 1500
        repeat: true
        running: win.arenaId === "random" && !win.ecoOn
        onTriggered: {
            if (win.showB) {
                win.aIdx = win.bIdx < 4 ? win.bIdx + 1 : 0
                win.showB = false
            } else {
                win.bIdx = win.aIdx < 4 ? win.aIdx + 1 : 0
                win.showB = true
            }
        }
    }
    SequentialAnimation {
        id: facePulse
        NumberAnimation { target: win; property: "faceScale"; to: 1.05; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: win; property: "faceScale"; to: 1; duration: 140; easing.type: Easing.OutQuad }
    }
    SequentialAnimation {
        id: hallPulse
        NumberAnimation { target: win; property: "hallScale"; to: 1.06; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation { target: win; property: "hallScale"; to: 1; duration: 120; easing.type: Easing.OutQuad }
    }
    Timer {
        id: tipDelay
        interval: 700
        onTriggered: {
            if (!win.tipItem) return
            win.placeTip()
            win.tipShow = true
        }
    }
    Timer {
        id: shotClose
        interval: 150
        onTriggered: win.game.picking = false
    }
    Timer {
        interval: 900
        repeat: false
        running: win.game.pickShot !== "" && !win.shotDone
        onTriggered: {
            win.shotDone = true
            var path = win.game.pickShot
            cardHost.grabToImage(function (res) {
                if (res) res.saveToFile(path)
                console.info("crew-fight picker shot " + path)
                win.game.pickHall = ""
                win.game.pickShot = ""
                shotClose.start()
            })
        }
    }
    Shortcut {
        sequences: ["Escape"]
        enabled: win.game.picking
        onActivated: win.game.picking = false
    }

    component HallThumb: Item {
        id: hall
        property string kind: "dojo"
        property real flake: 0
        property bool quiet: false
        width: Theme.u * 52
        height: Theme.u * 34
        clip: true

        readonly property color sky: kind === "desert" ? "#e09048" : kind === "fjord" ? "#163040" : kind === "plaza" ? "#4a2040" : kind === "terem" ? "#1c3050" : "#3a241c"
        readonly property bool petals: !quiet && (kind === "dojo" || kind === "desert" || kind === "fjord" || kind === "terem")
        readonly property color speck: kind === "dojo" ? "#f4a0b8" : kind === "desert" ? "#f0d090" : "#ffffff"

        Rectangle { anchors.fill: parent; color: hall.sky }
        Rectangle {
            visible: hall.kind === "dojo"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Theme.u * 10
            color: "#cbb98a"
        }
        Rectangle { visible: hall.kind === "dojo"; x: Theme.u * 18; width: Theme.u; height: Theme.u * 10; anchors.bottom: parent.bottom; color: "#7f9348" }
        Rectangle { visible: hall.kind === "dojo"; x: Theme.u * 34; width: Theme.u; height: Theme.u * 10; anchors.bottom: parent.bottom; color: "#7f9348" }
        Rectangle { visible: hall.kind === "dojo"; x: Theme.u * 2; y: Theme.u * 6; width: Theme.u * 12; height: Theme.u * 16; color: "#f3e2c4"; border.width: Theme.u; border.color: "#5a3a28" }
        Rectangle { visible: hall.kind === "dojo"; x: Theme.u * 2; y: Theme.u * 13; width: Theme.u * 12; height: Theme.u; color: "#c4a882" }
        Rectangle { visible: hall.kind === "dojo"; x: Theme.u * 7; y: Theme.u * 6; width: Theme.u; height: Theme.u * 16; color: "#c4a882" }
        Rectangle { visible: hall.kind === "dojo"; x: Theme.u * 16; y: Theme.u * 4; width: Theme.u * 18; height: Theme.u * 2; color: "#5a3a28" }
        Rectangle { visible: hall.kind === "dojo"; x: Theme.u * 18; y: Theme.u * 2; width: Theme.u * 3; height: Theme.u * 3; color: "#f4a0b8" }
        Rectangle { visible: hall.kind === "dojo"; x: Theme.u * 24; y: Theme.u * 5; width: Theme.u * 3; height: Theme.u * 3; color: "#ffd0dc" }
        Rectangle { visible: hall.kind === "dojo"; x: Theme.u * 30; y: Theme.u * 2; width: Theme.u * 3; height: Theme.u * 3; color: "#f4a0b8" }

        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 40; y: Theme.u * 3; width: Theme.u * 6; height: Theme.u * 6; color: "#ffd34d" }
        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 42; y: Theme.u * 5; width: Theme.u * 2; height: Theme.u * 2; color: "#fff2a8" }
        Rectangle { visible: hall.kind === "desert"; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: Theme.u * 10; color: "#e0b060" }
        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 2; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.u * 8; width: Theme.u * 16; height: Theme.u * 3; color: "#c4922a" }
        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 14; y: Theme.u * 22; width: Theme.u * 24; height: Theme.u * 3; color: "#e0c080" }
        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 26; y: Theme.u * 22; width: Theme.u * 12; height: Theme.u * 3; color: "#a07838" }
        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 17; y: Theme.u * 19; width: Theme.u * 18; height: Theme.u * 3; color: "#e0c080" }
        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 26; y: Theme.u * 19; width: Theme.u * 9; height: Theme.u * 3; color: "#a07838" }
        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 20; y: Theme.u * 16; width: Theme.u * 12; height: Theme.u * 3; color: "#e0c080" }
        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 26; y: Theme.u * 16; width: Theme.u * 6; height: Theme.u * 3; color: "#a07838" }
        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 23; y: Theme.u * 13; width: Theme.u * 6; height: Theme.u * 3; color: "#e0c080" }
        Rectangle { visible: hall.kind === "desert"; x: Theme.u * 26; y: Theme.u * 13; width: Theme.u * 3; height: Theme.u * 3; color: "#a07838" }

        Rectangle { visible: hall.kind === "fjord"; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: Theme.u * 8; color: "#d7f1fb" }
        Rectangle { visible: hall.kind === "fjord"; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.u * 7; height: Theme.u * 2; color: "#ffffff" }
        Rectangle { visible: hall.kind === "fjord"; x: Theme.u * 2; y: Theme.u * 18; width: Theme.u * 18; height: Theme.u * 8; color: "#3a5060" }
        Rectangle { visible: hall.kind === "fjord"; x: Theme.u * 5; y: Theme.u * 14; width: Theme.u * 12; height: Theme.u * 4; color: "#3a5060" }
        Rectangle { visible: hall.kind === "fjord"; x: Theme.u * 8; y: Theme.u * 11; width: Theme.u * 6; height: Theme.u * 3; color: "#f4fbff" }
        Rectangle { visible: hall.kind === "fjord"; x: Theme.u * 22; y: Theme.u * 16; width: Theme.u * 26; height: Theme.u * 10; color: "#2c4254" }
        Rectangle { visible: hall.kind === "fjord"; x: Theme.u * 27; y: Theme.u * 11; width: Theme.u * 16; height: Theme.u * 5; color: "#2c4254" }
        Rectangle { visible: hall.kind === "fjord"; x: Theme.u * 31; y: Theme.u * 7; width: Theme.u * 8; height: Theme.u * 4; color: "#f4fbff" }

        Rectangle { visible: hall.kind === "plaza"; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: Theme.u * 10; color: "#cbb8a0" }
        Rectangle { visible: hall.kind === "plaza"; x: Theme.u * 4; y: Theme.u * 26; width: Theme.u; height: Theme.u * 8; color: "#8a7560" }
        Rectangle { visible: hall.kind === "plaza"; x: Theme.u * 18; y: Theme.u * 26; width: Theme.u; height: Theme.u * 8; color: "#8a7560" }
        Rectangle { visible: hall.kind === "plaza"; x: Theme.u * 32; y: Theme.u * 26; width: Theme.u; height: Theme.u * 8; color: "#8a7560" }
        Rectangle { visible: hall.kind === "plaza"; x: Theme.u * 4; y: Theme.u * 6; width: Theme.u * 44; height: Theme.u; color: "#2b2433" }
        Rectangle { visible: hall.kind === "plaza"; x: Theme.u * 6; y: Theme.u * 7; width: Theme.u * 5; height: Theme.u * 4; color: "#e8668b" }
        Rectangle { visible: hall.kind === "plaza"; x: Theme.u * 14; y: Theme.u * 7; width: Theme.u * 5; height: Theme.u * 4; color: "#ffd34d" }
        Rectangle { visible: hall.kind === "plaza"; x: Theme.u * 22; y: Theme.u * 7; width: Theme.u * 5; height: Theme.u * 4; color: "#5dd6c0" }
        Rectangle { visible: hall.kind === "plaza"; x: Theme.u * 30; y: Theme.u * 7; width: Theme.u * 5; height: Theme.u * 4; color: "#f08a5d" }
        Rectangle { visible: hall.kind === "plaza"; x: Theme.u * 38; y: Theme.u * 7; width: Theme.u * 5; height: Theme.u * 4; color: "#b48cf0" }

        Rectangle { visible: hall.kind === "terem"; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: Theme.u * 8; color: "#eef4fb" }
        Rectangle { visible: hall.kind === "terem"; x: Theme.u * 14; y: Theme.u * 16; width: Theme.u * 24; height: Theme.u * 12; color: "#f4e4c4"; border.width: Theme.u; border.color: "#6b3a2a" }
        Rectangle { visible: hall.kind === "terem"; x: Theme.u * 18; y: Theme.u * 20; width: Theme.u * 5; height: Theme.u * 8; color: "#6b3a2a" }
        Rectangle { visible: hall.kind === "terem"; x: Theme.u * 28; y: Theme.u * 18; width: Theme.u * 5; height: Theme.u * 4; color: "#ffd34d" }
        Rectangle { visible: hall.kind === "terem"; x: Theme.u * 12; y: Theme.u * 14; width: Theme.u * 28; height: Theme.u * 3; color: "#8b3030" }
        Rectangle { visible: hall.kind === "terem"; x: Theme.u * 12; y: Theme.u * 13; width: Theme.u * 28; height: Theme.u; color: "#ffffff" }
        Rectangle { visible: hall.kind === "terem"; x: Theme.u * 16; y: Theme.u * 11; width: Theme.u * 20; height: Theme.u * 3; color: "#8b3030" }
        Rectangle { visible: hall.kind === "terem"; x: Theme.u * 16; y: Theme.u * 10; width: Theme.u * 20; height: Theme.u; color: "#ffffff" }
        Rectangle { visible: hall.kind === "terem"; x: Theme.u * 20; y: Theme.u * 8; width: Theme.u * 12; height: Theme.u * 3; color: "#8b3030" }
        Rectangle { visible: hall.kind === "terem"; x: Theme.u * 20; y: Theme.u * 7; width: Theme.u * 12; height: Theme.u; color: "#ffffff" }
        Rectangle { visible: hall.kind === "terem"; x: Theme.u * 24; y: Theme.u * 5; width: Theme.u * 4; height: Theme.u * 3; color: "#8b3030" }

        Rectangle {
            visible: hall.petals
            width: Theme.u * 2
            height: Theme.u * 2
            color: hall.speck
            x: Theme.u * 10
            y: ((hall.flake + 0.12) % 1) * (hall.height - Theme.u * 2)
        }
        Rectangle {
            visible: hall.petals
            width: Theme.u * 2
            height: Theme.u * 2
            color: hall.speck
            x: Theme.u * 36
            y: ((hall.flake + 0.48) % 1) * (hall.height - Theme.u * 2)
        }
        Rectangle {
            visible: hall.petals
            width: Theme.u
            height: Theme.u
            color: hall.speck
            x: Theme.u * 22
            y: ((hall.flake + 0.77) % 1) * (hall.height - Theme.u)
        }
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: Theme.u; border.color: Theme.edge }
    }

    component FaceCard: Column {
        id: face
        property var who: null
        property string badge: ""
        property color coat: "#888888"
        property string emptyName: "—"
        width: Theme.u * 44
        spacing: Theme.u
        Rectangle {
            x: Math.round((parent.width - width) / 2)
            width: Theme.u * 18
            height: Theme.u * 18
            color: face.who ? face.coat : Theme.sunken
            border.width: Theme.u
            border.color: Theme.edge
            Image {
                anchors.fill: parent
                anchors.margins: Theme.u
                source: face.who && face.who.avatar ? ("file://" + face.who.avatar) : ""
                smooth: false
                fillMode: Image.PreserveAspectCrop
            }
            Row {
                visible: !face.who || !face.who.avatar
                anchors.centerIn: parent
                spacing: Theme.u
                Rectangle { width: Theme.u * 2; height: Theme.u * 2; color: "#1a1a20" }
                Rectangle { width: Theme.u * 2; height: Theme.u * 2; color: "#1a1a20" }
            }
            Rectangle {
                visible: face.badge !== "" && !!face.who
                width: Theme.u * 7
                height: Theme.u * 7
                anchors.right: parent.right
                anchors.top: parent.top
                color: Theme.accent
                PxText { anchors.centerIn: parent; text: face.badge; color: Theme.face; kind: "tiny" }
            }
        }
        PxText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: Theme.text
            text: face.who ? face.who.name : face.emptyName
        }
    }

    component ChoiceChip: Item {
        id: chip
        property var host: null
        property string label: ""
        property bool lit: false
        property string tip: ""
        property var bmp: null
        property var palette: null
        signal choose()
        width: face.width
        height: face.height
        scale: ma.pressed ? 0.96 : (ma.containsMouse ? 1.05 : 1)
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: chip.host && chip.host.anim > 1 ? 120 : 1; easing.type: Easing.OutBack } }
        Rectangle {
            id: face
            width: inner.implicitWidth + Theme.u * 6
            height: Theme.u * 16
            color: chip.lit ? Theme.accent : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
            border.width: Theme.u
            border.color: Theme.accent
            Behavior on color { ColorAnimation { duration: chip.host ? chip.host.anim : 1 } }
            Row {
                id: inner
                anchors.centerIn: parent
                spacing: Theme.u * 2
                Rectangle {
                    visible: !!chip.bmp
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.u * 12
                    height: Theme.u * 12
                    color: "#2b2433"
                    PxIcon {
                        anchors.centerIn: parent
                        bitmap: chip.bmp
                        exactPixel: Theme.u * 10 / Math.max(5, chip.bmp ? chip.bmp.length : 5)
                        palette: chip.palette
                    }
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.label
                    color: chip.lit ? Theme.selectText : Theme.text
                }
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.choose()
                onContainsMouseChanged: {
                    if (!chip.host) return
                    if (containsMouse) chip.host.armTip(chip, chip.tip)
                    else chip.host.clearTip(chip)
                }
            }
        }
    }

    component OptRow: Item {
        id: opt
        property string label: ""
        property string tip: ""
        property bool lit: false
        property var host: null
        signal flip(bool checked)
        width: parent ? parent.width : implicitWidth
        height: tog.implicitHeight
        PxToggle {
            id: tog
            width: opt.width
            checked: opt.lit
            text: opt.label
            onToggled: function (v) { opt.flip(v) }
        }
        HoverHandler {
            onHoveredChanged: {
                if (!opt.host) return
                if (hovered) opt.host.armTip(opt, opt.tip)
                else opt.host.clearTip(opt)
            }
        }
    }

    component BounceButton: Item {
        id: bb
        property string label: ""
        property string tip: ""
        property bool accent: false
        property bool alive: true
        property bool stretch: false
        property var host: null
        signal go()
        width: stretch ? (parent ? parent.width : btn.implicitWidth) : btn.implicitWidth
        height: btn.implicitHeight
        scale: btn.pressed ? 0.96 : (btn.hovered && btn.enabled ? (accent ? 1.04 : 1.03) : 1)
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: bb.host && bb.host.anim > 1 ? 130 : 1; easing.type: Easing.OutBack } }
        PxButton {
            id: btn
            width: bb.stretch ? bb.width : implicitWidth
            text: bb.label
            accent: bb.accent
            enabled: bb.alive
            onClicked: bb.go()
            onHoveredChanged: {
                if (!bb.host) return
                if (hovered) bb.host.armTip(bb, bb.tip)
                else bb.host.clearTip(bb)
            }
        }
        HoverHandler {
            onHoveredChanged: {
                if (!bb.host || btn.enabled) return
                if (hovered) bb.host.armTip(bb, bb.tip)
                else bb.host.clearTip(bb)
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: win.dimIn * 0.55
            Behavior on opacity { NumberAnimation { duration: win.anim; easing.type: Easing.OutQuad } }
        }
        MouseArea { anchors.fill: parent; onClicked: win.game.picking = false }

        Item {
            id: cardHost
            anchors.centerIn: parent
            width: Math.min(stage.width - Theme.u * 16, Theme.u * 300)
            height: stack.implicitHeight + card.inset * 2
            opacity: win.cardIn
            scale: win.ecoOn ? 1 : (0.96 + 0.04 * win.cardIn)
            transformOrigin: Item.Center
            Behavior on opacity { NumberAnimation { duration: win.anim; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: win.anim > 1 ? 220 : 1; easing.type: Easing.OutBack } }

            MouseArea { anchors.fill: parent }
            PxBox {
                id: card
                anchors.fill: parent
                color: Theme.face
                edgeColor: Theme.accent
                shadow: Theme.zine
                Column {
                    id: stack
                    width: parent.width
                    spacing: Theme.u * 5

                    Column {
                        id: headCol
                        width: parent.width
                        spacing: Theme.u * 3
                        PxText { text: win.game.t("⚔ Драка человечков", "⚔ Crew Fight"); color: Theme.accent; font.bold: true }
                        Rectangle { width: Theme.u * 28; height: Theme.u; color: Theme.accent }
                        PxText { width: parent.width; wrapMode: Text.Wrap; color: Theme.textDim; text: win.hintLine }
                        Rectangle {
                            width: parent.width
                            height: previewRow.height + Theme.u * 4
                            color: Theme.sunken
                            border.width: Math.max(1, Theme.u / 2)
                            border.color: Theme.edge
                            Row {
                                id: previewRow
                                anchors.centerIn: parent
                                spacing: Theme.u * 3
                                Item {
                                    width: Theme.u * 44
                                    height: Theme.u * 50
                                    FaceCard {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: win.game.first ? win.lift : 0
                                        who: win.game.first
                                        badge: win.game.first ? "1" : ""
                                        coat: win.game.first ? win.game.coat(win.game.first.id) : Theme.sunken
                                        emptyName: win.game.t("пусто", "empty")
                                        scale: win.faceScale
                                        transformOrigin: Item.Bottom
                                    }
                                }
                                Item {
                                    width: vsText.implicitWidth
                                    height: Theme.u * 50
                                    PxText {
                                        id: vsText
                                        anchors.centerIn: parent
                                        text: "VS"
                                        color: Theme.accent
                                        font.bold: true
                                    }
                                }
                                Item {
                                    width: Theme.u * 44
                                    height: Theme.u * 50
                                    FaceCard {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: win.game.second ? win.lift : 0
                                        who: win.game.second
                                        badge: win.game.second ? "2" : ""
                                        coat: win.game.second ? win.game.coat(win.game.second.id) : Theme.sunken
                                        emptyName: win.game.t("пусто", "empty")
                                        scale: win.faceScale
                                        transformOrigin: Item.Bottom
                                    }
                                }
                                Item {
                                    width: Theme.u * 52
                                    height: Theme.u * 50
                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        spacing: Theme.u
                                        scale: win.hallScale
                                        transformOrigin: Item.Bottom
                                        Item {
                                            width: Theme.u * 52
                                            height: Theme.u * 34
                                            HallThumb {
                                                anchors.fill: parent
                                                kind: win.arenaId === "random" ? win.hallAt(win.aIdx) : win.arenaId
                                                flake: win.flake
                                                quiet: win.ecoOn
                                                opacity: win.arenaId !== "random" || win.ecoOn || !win.showB ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: win.anim > 1 ? 450 : 1 } }
                                            }
                                            HallThumb {
                                                anchors.fill: parent
                                                kind: win.hallAt(win.bIdx)
                                                flake: win.flake
                                                quiet: win.ecoOn
                                                visible: win.arenaId === "random" && !win.ecoOn
                                                opacity: win.showB ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: win.anim > 1 ? 450 : 1 } }
                                            }
                                            PxText {
                                                anchors.centerIn: parent
                                                visible: win.arenaId === "random" && win.ecoOn
                                                text: "?"
                                                color: Theme.text
                                                font.bold: true
                                            }
                                        }
                                        PxText {
                                            width: Theme.u * 52
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            kind: "tiny"
                                            color: Theme.textDim
                                            text: win.arenaName(win.arenaId)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Flickable {
                        id: mid
                        width: parent.width
                        readonly property real room: Math.max(Theme.u * 36, stage.height - Theme.u * 20 - headCol.implicitHeight - footCol.implicitHeight - moreWrap.implicitHeight - card.inset * 2 - stack.spacing * 3)
                        height: Math.min(midCol.implicitHeight, room)
                        contentWidth: width
                        contentHeight: midCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick
                        interactive: contentHeight > height + 1

                        Column {
                            id: midCol
                            width: mid.width
                            spacing: Theme.u * 6

                            Column {
                                width: parent.width
                                spacing: Theme.u * 2
                                PxText { text: win.game.t("Бойцы", "Fighters"); color: Theme.accent; font.bold: true }
                                PxText {
                                    visible: !win.pool || win.pool.length === 0
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    color: Theme.textDim
                                    text: win.game.t("В списке никого нет.", "Nobody is on the list.")
                                }
                                Repeater {
                                    model: win.pool
                                    Rectangle {
                                        id: row
                                        required property var modelData
                                        readonly property bool sel: (win.game.first && win.game.first.id === modelData.id) || (win.game.second && win.game.second.id === modelData.id)
                                        readonly property bool isFirst: win.game.first && win.game.first.id === modelData.id
                                        property real pop: 1
                                        width: midCol.width
                                        height: Theme.u * 22
                                        color: sel ? Theme.accent : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                                        border.width: Theme.u
                                        border.color: sel ? Theme.accent : Qt.darker(win.game.coat(modelData.id), 1.4)
                                        scale: (ma.pressed ? 0.98 : (ma.containsMouse ? 1.02 : 1)) * pop
                                        transformOrigin: Item.Center
                                        Behavior on color { ColorAnimation { duration: win.anim } }
                                        Behavior on scale { NumberAnimation { duration: win.anim > 1 ? 120 : 1; easing.type: Easing.OutBack } }
                                        onSelChanged: { if (sel && win.anim > 1) popAnim.restart() }
                                        SequentialAnimation {
                                            id: popAnim
                                            NumberAnimation { target: row; property: "pop"; to: 1.04; duration: 80 }
                                            NumberAnimation { target: row; property: "pop"; to: 1; duration: 120 }
                                        }
                                        Rectangle {
                                            x: Theme.u * 3
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Theme.u * 14
                                            height: width
                                            color: win.game.coat(row.modelData.id)
                                            border.width: Theme.u
                                            border.color: Theme.edge
                                            Image {
                                                anchors.fill: parent
                                                anchors.margins: Theme.u
                                                source: row.modelData.avatar ? ("file://" + row.modelData.avatar) : ""
                                                smooth: false
                                                fillMode: Image.PreserveAspectCrop
                                            }
                                            Row {
                                                visible: !row.modelData.avatar
                                                anchors.centerIn: parent
                                                spacing: Theme.u
                                                Rectangle { width: Theme.u * 2; height: Theme.u * 2; color: "#1a1a20" }
                                                Rectangle { width: Theme.u * 2; height: Theme.u * 2; color: "#1a1a20" }
                                            }
                                        }
                                        PxText {
                                            x: Theme.u * 22
                                            width: parent.width - Theme.u * 36
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            text: row.modelData.name
                                            color: row.sel ? Theme.selectText : Theme.text
                                        }
                                        Rectangle {
                                            visible: row.sel
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.u * 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Theme.u * 8
                                            height: Theme.u * 8
                                            color: Theme.face
                                            PxText {
                                                anchors.centerIn: parent
                                                text: row.isFirst ? "1" : "2"
                                                color: Theme.accent
                                                font.bold: true
                                            }
                                        }
                                        MouseArea {
                                            id: ma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.pickPerson(row.modelData)
                                            onContainsMouseChanged: {
                                                if (containsMouse) win.armTip(row, I18n.t("Поставить бойцом. Повторный клик снимает выбор.", "Set as a fighter. Click again to clear."))
                                                else win.clearTip(row)
                                            }
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: 2
                                Item {
                                    id: wslot
                                    required property int index
                                    readonly property var who: index === 0 ? win.game.first : win.game.second
                                    readonly property string cur: index === 0 ? win.game.wpA : win.game.wpB
                                    width: midCol.width
                                    clip: true
                                    visible: !!who
                                    height: visible ? wcol.implicitHeight : 0
                                    Behavior on height { NumberAnimation { duration: win.anim; easing.type: Easing.OutQuad } }
                                    Column {
                                        id: wcol
                                        width: wslot.width
                                        spacing: Theme.u * 2
                                        PxText {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            color: Theme.textDim
                                            text: win.game.t("Оружие: ", "Weapon: ") + (wslot.who ? wslot.who.name : "")
                                        }
                                        Flow {
                                            width: parent.width
                                            spacing: Theme.u * 2
                                            Repeater {
                                                model: win.weaponIds
                                                Item {
                                                    id: chipHost
                                                    required property string modelData
                                                    readonly property var wp: win.weaponById(modelData)
                                                    width: chip.width
                                                    height: chip.height
                                                    ChoiceChip {
                                                        id: chip
                                                        host: win
                                                        lit: wslot.cur === chipHost.modelData
                                                        label: chipHost.wp ? chipHost.wp.name : win.game.t("случайное", "random")
                                                        bmp: chipHost.wp ? chipHost.wp.bmp : null
                                                        palette: win.game.wpal
                                                        tip: chipHost.modelData === "random"
                                                             ? I18n.t("Оружие выпадет само в начале боя.", "A weapon is drawn at the start.")
                                                             : I18n.t("Оружие этого бойца.", "This fighter's weapon.")
                                                        onChoose: win.setWeapon(wslot.index, chipHost.modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: Theme.u * 2
                                PxText { text: win.game.t("Арена", "Arena"); color: Theme.accent; font.bold: true }
                                Flow {
                                    width: parent.width
                                    spacing: Theme.u * 2
                                    Repeater {
                                        model: win.arenaIds
                                        Item {
                                            id: arenaHost
                                            required property string modelData
                                            width: arenaChip.width
                                            height: arenaChip.height
                                            ChoiceChip {
                                                id: arenaChip
                                                host: win
                                                lit: win.arenaId === arenaHost.modelData
                                                label: win.arenaName(arenaHost.modelData)
                                                tip: win.arenaTip(arenaHost.modelData)
                                                onChoose: win.chooseArena(arenaHost.modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: Theme.u * 2
                                PxText { text: win.game.t("Раунды", "Rounds"); color: Theme.accent; font.bold: true }
                                Flow {
                                    width: parent.width
                                    spacing: Theme.u * 2
                                    Repeater {
                                        model: win.roundIds
                                        Item {
                                            id: roundHost
                                            required property var modelData
                                            width: roundChip.width
                                            height: roundChip.height
                                            ChoiceChip {
                                                id: roundChip
                                                host: win
                                                lit: win.game.pickRounds === roundHost.modelData
                                                label: win.roundLabel(roundHost.modelData)
                                                tip: win.roundTip(roundHost.modelData)
                                                onChoose: win.game.pickRounds = roundHost.modelData
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        id: footCol
                        width: parent.width
                        spacing: Theme.u * 3
                        BounceButton {
                            stretch: true
                            accent: true
                            alive: !!win.game.second
                            host: win
                            label: win.game.t("В бой!", "Fight!")
                            tip: I18n.t("Начать бой выбранных бойцов.", "Start the fight with the chosen fighters.")
                            onGo: win.game.start(win.game.first, win.game.second, win.game.wpA, win.game.wpB, String(win.game.pickRounds))
                        }
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 3
                            BounceButton {
                                host: win
                                label: win.game.t("Случайно", "Random")
                                tip: I18n.t("Случайная пара из списка и случайное оружие.", "A random pair from the list and random weapons.")
                                onGo: {
                                    var pair = win.game.randomPair(win.pool)
                                    if (pair) win.game.start(pair[0], pair[1], "random", "random", String(win.game.pickRounds))
                                }
                            }
                            BounceButton {
                                host: win
                                label: win.game.t("Турнир", "Tournament")
                                tip: I18n.t("Сетка на всех из списка, по одному раунду.", "A bracket of everyone on the list, one round each.")
                                onGo: win.game.startTour(win.pool, "1", win.game.pickDemo)
                            }
                            BounceButton {
                                host: win
                                label: win.game.t("Отмена", "Cancel")
                                tip: I18n.t("Закрыть, бой не начнётся.", "Close. The fight will not start.")
                                onGo: win.game.picking = false
                            }
                        }
                    }

                    Column {
                        id: moreWrap
                        width: parent.width
                        spacing: Theme.u * 2
                        Rectangle {
                            id: moreHead
                            width: parent.width
                            height: Theme.u * 16
                            color: moreMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            border.width: Theme.u
                            border.color: Theme.edge
                            scale: moreMa.pressed ? 0.98 : 1
                            transformOrigin: Item.Center
                            Behavior on scale { NumberAnimation { duration: win.anim > 1 ? 100 : 1; easing.type: Easing.OutQuad } }
                            PxText {
                                x: Theme.u * 3
                                anchors.verticalCenter: parent.verticalCenter
                                text: (win.moreOpen ? "[-] " : "[+] ") + win.game.t("Дополнительно", "More")
                                color: Theme.text
                            }
                            MouseArea {
                                id: moreMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.moreOpen = !win.moreOpen
                                onContainsMouseChanged: {
                                    if (containsMouse) win.armTip(moreHead, I18n.t("Звук, щит, супер, предметы и механики арен.", "Sound, shield, super, pickups and arena mechanics."))
                                    else win.clearTip(moreHead)
                                }
                            }
                        }
                        Item {
                            id: moreBody
                            width: parent.width
                            clip: true
                            height: win.moreOpen ? moreCol.implicitHeight : 0
                            Behavior on height { NumberAnimation { duration: win.anim > 1 ? win.anim : 1; easing.type: Easing.OutQuad } }
                            Column {
                                id: moreCol
                                width: parent.width
                                spacing: Theme.u * 4
                                topPadding: Theme.u * 3
                                PxText { text: win.game.t("Звук", "Sound"); color: Theme.accent; font.bold: true }
                                OptRow {
                                    host: win
                                    label: win.game.t("Звуки боя", "Fight sounds")
                                    tip: I18n.t("Звуки ударов и комментатора.", "Hit sounds and the announcer.")
                                    lit: win.snd
                                    onFlip: function (v) { win.snd = v; win.game.setSound(v) }
                                }
                                Column {
                                    id: volRow
                                    width: parent.width
                                    spacing: Theme.u
                                    PxText { text: win.game.t("Громкость", "Volume"); color: Theme.textDim }
                                    PxSlider {
                                        width: Math.min(parent.width, Theme.u * 120)
                                        from: 0
                                        to: 100
                                        stepSize: 5
                                        suffix: "%"
                                        value: win.vol
                                        enabled: win.snd
                                        onReleased: function (v) { win.vol = Math.round(v); win.game.setSound(undefined, win.vol) }
                                    }
                                    HoverHandler {
                                        onHoveredChanged: {
                                            if (hovered) win.armTip(volRow, I18n.t("Громкость звуков боя.", "Fight sound volume."))
                                            else win.clearTip(volRow)
                                        }
                                    }
                                }
                                PxText { text: win.game.t("Бой", "Fight"); color: Theme.accent; font.bold: true }
                                OptRow {
                                    host: win
                                    label: win.game.t("Демо-бойцы", "Demo fighters")
                                    tip: I18n.t("Демо-бойцы вместо людей из звонка.", "Demo fighters instead of people from the call.")
                                    lit: win.game.pickDemo
                                    onFlip: function (v) {
                                        win.clearTip(null)
                                        win.game.first = null
                                        win.game.second = null
                                        win.game.pickDemo = v
                                    }
                                }
                                OptRow {
                                    host: win
                                    label: win.game.t("Щит", "Shield")
                                    tip: I18n.t("Бойцы сами ставят щит, урон меньше.", "Fighters raise a shield, so hits hurt less.")
                                    lit: win.shld
                                    onFlip: function (v) { win.shld = v; win.game.setCfg("gpShield", v) }
                                }
                                OptRow {
                                    host: win
                                    label: win.game.t("Суперудар", "Super")
                                    tip: I18n.t("Шкала суперудара и суперудары.", "The super meter and super moves.")
                                    lit: win.sup
                                    onFlip: function (v) { win.sup = v; win.game.setCfg("gpSuper", v) }
                                }
                                OptRow {
                                    host: win
                                    label: win.game.t("Предметы", "Pickups")
                                    tip: I18n.t("На ринг падают аптечка, ускорение и бомба.", "A heal kit, a speed boost and a bomb drop into the ring.")
                                    lit: win.picks
                                    onFlip: function (v) { win.picks = v; win.game.setCfg("gpPickups", v) }
                                }
                                Column {
                                    width: parent.width
                                    spacing: Theme.u * 2
                                    PxText { text: win.game.t("Как часто предметы", "How often pickups drop"); color: Theme.textDim }
                                    Flow {
                                        width: parent.width
                                        spacing: Theme.u * 2
                                        Repeater {
                                            model: win.rateIds
                                            Item {
                                                id: rateHost
                                                required property string modelData
                                                width: rateChip.width
                                                height: rateChip.height
                                                ChoiceChip {
                                                    id: rateChip
                                                    host: win
                                                    lit: win.rate === rateHost.modelData
                                                    label: win.rateLabel(rateHost.modelData)
                                                    tip: I18n.t("Как часто падают предметы.", "How often pickups drop.")
                                                    onChoose: win.chooseRate(rateHost.modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                                OptRow {
                                    host: win
                                    label: win.game.t("Механики арен", "Arena mechanics")
                                    tip: I18n.t("Включить механику выбранной арены.", "Turn on the chosen arena's mechanic.")
                                    lit: win.afx
                                    onFlip: function (v) { win.afx = v; win.game.setCfg("gpArenaFx", v) }
                                }
                                OptRow {
                                    host: win
                                    label: win.game.t("Эко-режим", "Eco mode")
                                    tip: I18n.t("Рисовать бой реже, около 30 кадров в секунду.", "Draw the fight less often, about 30 frames a second.")
                                    lit: win.ecoOn
                                    onFlip: function (v) { win.ecoOn = v; win.game.setCfg("eco", v) }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: keys
            z: -1
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: function (event) {
                win.game.picking = false
                event.accepted = true
            }
        }

        PxBox {
            id: tipBox
            z: 80
            x: win.tipX
            y: win.tipY
            opacity: win.tipShow && win.tip !== "" ? 1 : 0
            visible: opacity > 0.01 || win.tipShow
            enabled: false
            width: tipText.width + Theme.u * 6
            height: tipText.implicitHeight + Theme.u * 4
            color: Theme.menuSurface
            edgeColor: Theme.menuBorder
            flat: true
            Behavior on opacity { NumberAnimation { duration: win.anim > 1 ? 140 : 1 } }
            Behavior on x { NumberAnimation { duration: win.anim > 1 ? 80 : 1 } }
            Behavior on y { NumberAnimation { duration: win.anim > 1 ? 80 : 1 } }
            onWidthChanged: { if (win.tipShow) win.placeTip() }
            onHeightChanged: { if (win.tipShow) win.placeTip() }
            PxText {
                id: tipText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, Math.max(Theme.u * 40, stage.width - Theme.u * 16))
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                kind: "tiny"
                color: Theme.text
                text: win.tip
            }
        }
    }
}
