pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Tournament bracket shown between matches, same place and size as the arena (click-through).
PanelWindow {
    id: tb
    required property var game
    readonly property var g: game
    readonly property var tr: (g.tourRev, g.tour)
    readonly property var rds: tr ? tr.rounds : []
    readonly property int nr: rds.length

    screen: Shell.focusedScreen || Shell.primaryScreen
    readonly property real sc: g.scaleFor(screen)
    implicitWidth: Math.round(900 * sc)
    implicitHeight: Math.round(560 * sc)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "angelos-crew-fight-bracket"

    function nextOf() { const n = g.tour ? g.nextMatch() : null; return n ? n.m : null; }
    readonly property var nxt: (g.tourRev, nextOf())
    readonly property var champ: (g.tourRev, tr ? tr.champion : null)
    readonly property var last: (g.tourRev, tr ? tr.last : null)
    readonly property real colW: 840 / Math.max(1, nr + 1)
    readonly property real bw: Math.min(180, colW - 34)
    function cx(c) { return 30 + c * colW; }
    function cy(c, i) { const n = c < nr ? rds[c].length : 1; return 92 + 16 + (380 / n) * (i + 0.5); }
    // path animation: line grows (prog), then the name pops into the next slot (pop)
    property real prog: last ? 0 : 1
    property real pop: last ? 0 : 1
    SequentialAnimation {
        running: !!tb.last
        PauseAnimation { duration: 350 }
        ScriptAction { script: tb.g.sfx(tb.champ ? "fanfare" : "swoosh", 0.6) }
        NumberAnimation { target: tb; property: "prog"; from: 0; to: 1; duration: 750; easing.type: Easing.InOutQuad }
        NumberAnimation { target: tb; property: "pop"; from: 0; to: 1; duration: 260; easing.type: Easing.OutBack }
    }
    onProgChanged: lines.requestPaint()
    function isNew(r, i) { return !!last && last.r === r && last.i === i; }

    Rectangle {
        id: box
        width: 900; height: 560
        scale: tb.sc
        transformOrigin: Item.TopLeft
        color: Qt.darker(Theme.face, 1.8)
        border.width: 4; border.color: Theme.accent
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 250 } }

        // hall stripes
        Repeater { model: 6; Rectangle { required property int index; x: 10; width: 880; y: 124 + index * 22; height: 10; color: Qt.darker(Theme.face, 1.35); opacity: 0.18 } }

        PxText {
            anchors.horizontalCenter: parent.horizontalCenter; y: 16
            text: tb.champ ? "🏆 TOURNAMENT CHAMPION 🏆" : tb.g.t("⚔ ТУРНИР ВОЙСА ⚔", "⚔ VOICE CHAT TOURNAMENT ⚔")
            color: tb.champ ? "#ffd34d" : Theme.accent2; font.bold: true; font.pixelSize: 26
            style: Text.Outline; styleColor: "#2b2433"
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter; y: 52
            text: tb.champ ? tb.champ.name : (tb.g.tour && tb.g.tour.demo ? tb.g.t("демо-турнир · ", "demo tournament · ") : "") + (tb.g.tour ? tb.g.tour.players.length : 0) + tb.g.t(" бойцов · матчи: ", " fighters · matches: ") + (tb.g.tourMatchRounds || tb.g.t("до KO", "to KO")) + tb.g.t(" · финал: ", " · final: ") + (tb.g.tourFinalRounds || tb.g.t("до KO", "to KO"))
            color: tb.champ ? "#ffffff" : Theme.text; font.bold: !!tb.champ; font.pixelSize: tb.champ ? 22 : 12
        }

        // columns: one per round
        Repeater {
            model: tb.nr
            Item {
                id: col
                required property int index
                readonly property var ms: tb.rds[index] || []
                readonly property real colW: tb.colW
                readonly property real bw: tb.bw
                x: 30 + index * colW; y: 92; width: colW; height: 400
                PxText { x: 0; y: -4; width: col.bw; horizontalAlignment: Text.AlignHCenter; text: tb.g.tour ? tb.g.stageName(col.index) : ""; color: Theme.textDim; font.pixelSize: 11 }
                Repeater {
                    model: col.ms.length
                    Item {
                        id: mb
                        required property int index
                        readonly property var m: (tb.g.tourRev, col.ms[index])
                        readonly property bool isNext: !!tb.nxt && tb.nxt === m
                        readonly property real slot: 380 / col.ms.length
                        y: 16 + slot * (index + 0.5) - 25
                        width: col.bw; height: 50
                        // connector to the next round
                        
                        Rectangle {
                            anchors.fill: parent
                            color: "#1a1a20"
                            border.width: mb.isNext ? 3 : 2
                            border.color: mb.isNext ? "#ffd34d" : Theme.accent
                            SequentialAnimation on opacity { running: mb.isNext; loops: Animation.Infinite; NumberAnimation { to: 0.6; duration: 450 } NumberAnimation { to: 1; duration: 450 } }
                            Column {
                                x: 4; y: 3; spacing: 2
                                Repeater {
                                    model: 2
                                    Row {
                                        id: rw
                                        required property int index
                                        readonly property var who: mb.m ? (index === 0 ? mb.m.a : mb.m.b) : null
                                        readonly property bool won: !!mb.m && mb.m.w === index
                                        readonly property bool lost: !!mb.m && mb.m.w >= 0 && mb.m.w !== index
                                        readonly property bool popping: !!tb.last && col.index === tb.last.r + 1 && mb.index === (tb.last.i >> 1) && index === tb.last.i % 2
                                        spacing: 5; height: 20
                                        opacity: (lost ? 0.4 : 1) * (popping ? tb.pop : 1)
                                        scale: popping ? 0.6 + 0.4 * tb.pop : 1
                                        transformOrigin: Item.Left
                                        Rectangle {
                                            width: 18; height: 18; color: rw.who ? tb.g.coat(rw.who.id) : "#333340"
                                            Image { anchors.fill: parent; anchors.margins: 1; visible: !!rw.who && rw.who.avatar !== ""; source: rw.who && rw.who.avatar ? rw.who.avatar : ""; smooth: false; fillMode: Image.PreserveAspectCrop }
                                            PxText { anchors.centerIn: parent; visible: !!rw.who && !rw.who.avatar; text: rw.who ? String(rw.who.name).charAt(0).toUpperCase() : ""; color: "#2b2433"; font.bold: true; font.pixelSize: 11 }
                                        }
                                        PxText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: mb.width - 50; elide: Text.ElideRight
                                            text: rw.who ? rw.who.name : (mb.m && mb.m.a && !mb.m.b && col.index === 0 ? "— bye —" : "…")
                                            color: rw.won ? "#ffd34d" : Theme.text; font.bold: rw.won; font.pixelSize: 12
                                        }
                                        PxText { anchors.verticalCenter: parent.verticalCenter; visible: rw.won; text: "★"; color: "#ffd34d"; font.pixelSize: 12 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Canvas {
            id: lines
            anchors.fill: parent
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d"); ctx.reset();
                const G = "#ffd34d", D = String(Theme.textDim);
                const seg = (pts, upto) => {                  // polyline truncated at length `upto`
                    const out = [pts[0]]; let left = upto;
                    for (let k = 1; k < pts.length; k++) {
                        const a = pts[k - 1], b = pts[k], L = Math.hypot(b[0] - a[0], b[1] - a[1]);
                        if (left >= L) { out.push(b); left -= L; } else { const t = left / L; out.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]); return out; }
                    }
                    return out;
                };
                const plen = pts => { let L = 0; for (let k = 1; k < pts.length; k++) L += Math.hypot(pts[k][0] - pts[k - 1][0], pts[k][1] - pts[k - 1][1]); return L; };
                const stroke = pts => { ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); for (let k = 1; k < pts.length; k++) ctx.lineTo(pts[k][0], pts[k][1]); ctx.stroke(); };
                const dashed = pts => { const L = plen(pts); for (let d = 0; d < L; d += 10) { const a = seg(pts, d), b = seg(pts, Math.min(L, d + 5)); stroke([a[a.length - 1], b[b.length - 1]]); } };
                const arrow = (x, y, col) => { ctx.fillStyle = col; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x - 9, y - 6); ctx.lineTo(x - 9, y + 6); ctx.closePath(); ctx.fill(); };
                for (let r = 0; r < tb.nr; r++) {
                    for (let i = 0; i < tb.rds[r].length; i++) {
                        const m = tb.rds[r][i];
                        const x0 = tb.cx(r) + tb.bw, y0 = tb.cy(r, i);
                        const x1 = tb.cx(r + 1) - 2, y1 = r + 1 < tb.nr ? tb.cy(r + 1, i >> 1) + (i % 2 ? 10 : -10) : tb.cy(r + 1, 0);
                        const xm = x0 + (x1 - x0) * 0.5;
                        const pts = [[x0, y0], [xm, y0], [xm, y1], [x1 - 8, y1]];
                        if (m.w < 0) { ctx.globalAlpha = 0.45; ctx.strokeStyle = D; ctx.lineWidth = 2; dashed(pts); ctx.globalAlpha = 1; continue; }
                        if (tb.isNew(r, i)) {
                            const L = plen(pts), part = seg(pts, L * tb.prog);
                            ctx.strokeStyle = G; ctx.globalAlpha = 0.25; ctx.lineWidth = 10; stroke(part);
                            ctx.globalAlpha = 1; ctx.lineWidth = 3; stroke(part);
                            const tip = part[part.length - 1];
                            ctx.fillStyle = "#ffffff"; ctx.fillRect(tip[0] - 3, tip[1] - 3, 6, 6);
                            if (tb.prog >= 1) arrow(x1, y1, G);
                            continue;
                        }
                        ctx.strokeStyle = G; ctx.globalAlpha = 0.85; ctx.lineWidth = 3; stroke(pts); ctx.globalAlpha = 1; arrow(x1, y1, G);
                    }
                }
            }
        }
        // champion slot (trophy)
        Rectangle {
            x: tb.cx(tb.nr); y: tb.cy(tb.nr, 0) - 34
            width: tb.bw; height: 68
            color: "#1a1a20"; border.width: 3; border.color: tb.champ ? "#ffd34d" : Qt.darker(Theme.accent, 1.4)
            Column {
                anchors.centerIn: parent; spacing: 2
                PxText { anchors.horizontalCenter: parent.horizontalCenter; text: "🏆"; font.pixelSize: 22; opacity: tb.champ ? 1 : 0.35 }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property bool popping: !!tb.champ && !!tb.last && tb.last.r === tb.nr - 1
                    width: tb.bw - 10; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: tb.champ ? tb.champ.name : tb.g.t("чемпион?", "champion?")
                    color: tb.champ ? "#ffd34d" : Theme.textDim; font.bold: !!tb.champ; font.pixelSize: 13
                    opacity: popping ? tb.pop : 1; scale: popping ? 0.6 + 0.4 * tb.pop : 1
                }
            }
        }
        PxText { x: tb.cx(tb.nr); y: 88; width: tb.bw; horizontalAlignment: Text.AlignHCenter; text: tb.g.t("Чемпион", "Champion"); color: Theme.textDim; font.pixelSize: 11 }

        // footer: next match / champion
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter; y: 500
            width: Math.min(820, ft.implicitWidth + 30); height: 38
            color: Theme.face; border.width: 3; border.color: tb.champ ? "#ffd34d" : Theme.accent
            PxText {
                id: ft; anchors.centerIn: parent
                text: tb.champ ? tb.g.t("Чемпион турнира — " + tb.champ.name + "! Поклонитесь!", "Tournament champion — " + tb.champ.name + "! Take a bow!") : tb.g.tourNext ? tb.g.t("Следующий бой → ", "Next fight → ") + tb.g.tourNext : ""
                color: Theme.text; font.bold: true; font.pixelSize: 16
            }
        }
    }
}
