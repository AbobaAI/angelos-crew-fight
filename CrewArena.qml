pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The ring of crew-fight: rounds, round-card girl, corner trainers, announcer, weapon moves and
// finishers. One 30 fps timer + one Canvas, alive only while a fight is on (Main's LazyLoader).
PanelWindow {
    id: ar
    required property var game
    readonly property var g: game

    visible: g.on
    screen: Shell.focusedScreen || Shell.primaryScreen
    // the ring is laid out in 900×560 units and scaled as a whole (Settings: arena size, auto = fit the monitor)
    readonly property real sc: g.scaleFor(screen)
    implicitWidth: Math.round(900 * sc)
    implicitHeight: Math.round(560 * sc)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "angelos-crew-fight"

    readonly property color cAccent: Theme.accent
    readonly property color cAccent2: Theme.accent2
    readonly property color cFace: Theme.face
    readonly property color cSunken: Theme.sunken
    readonly property color cText: Theme.text
    readonly property color cDanger: Theme.danger
    readonly property color cOk: Theme.ok

    readonly property real ww: 900
    readonly property real fy: 470
    readonly property real pl: 150
    readonly property real pr: 750
    readonly property real ropeL: 180
    readonly property real ropeR: 720
    readonly property int roundFr: g.rounds === 0 ? 330 : 450
    readonly property real dmgScale: g.rounds === 1 ? 1 : g.rounds === 0 ? 0.8 : g.rounds === 3 ? 0.5 : 0.38
    property var sm: null
    readonly property var crowdRows: [{ "y": 262, "n": 34, "s": 1.0, "a": 0.55 }, { "y": 228, "n": 38, "s": 0.82, "a": 0.42 }, { "y": 198, "n": 44, "s": 0.66, "a": 0.3 }]
    // hit feel per weapon: heavy bat / laser, light slipper
    readonly property var power: ({ "fists": 1, "slipper": 0.55, "bat": 1.7, "fish": 0.9, "mic": 1, "keyboard": 0.8, "bread": 0.9, "laser": 1.5 })

    function rnd(xs) { return xs[Math.floor(Math.random() * xs.length)]; }
    function tl(ru, en) { return g.t(ru, en); }
    function mkF(who, side) {
        return { "who": who, "side": side, "x": side === 0 ? -40 : ww + 40, "y": 0, "vx": side === 0 ? 10 : -10, "vy": 15,
                 "face": side === 0 ? 1 : -1, "st": "enter", "t": 0, "cd": 20, "flash": 0, "trail": [], "coat": g.coat(who.id),
                 "img": who.avatar ? "file://" + who.avatar : "", "hp": 100, "squash": 0, "wep": side === 0 ? g.wa : g.wb,
                 "stun": 0, "mv": null, "noWep": false, "alpha": 1, "low": false, "spin": 0,
                 "blkAge": 99, "blkCd": 0, "gd": 100, "bflash": 0, "seen": 0, "atkN": 0, "sp": 0, "spd": 0, "mvT": 0, "tgt": null, "fetchT": 0, "bomb": null, "fled": 0 };
    }
    Component.onCompleted: {
        sm = { "f": [mkF(g.a, 0), mkF(g.b, 1)], "mvStat": { "m": 0, "r": 0 }, "parts": [], "floats": [], "proj": [], "beams": [], "rings": [], "shake": 0, "slow": 1, "slowT": 0,
               "zoom": 1, "zx": 450, "zy": fy - 60, "ropeW": [0, 0], "hype": 0, "frame": 0, "phase": "intro", "phT": 0, "round": 0,
               "roundT": 0, "dmg": [0, 0], "scores": [0, 0], "cardX": -80, "cardHold": 0, "flash": 0, "sayCd": 0, "last": "",
               "combo": 0, "endT": 0, "trX": [112, 788], "rec": null, "maxBeam": 0, "cam": 0, "camX": 450, "camY": 280, "camZ": 1, "punch": 0, "px": 450, "py": 300, "freeze": 0, "sdx": 1, "sdy": 0.3, "vig": 0, "fightT": 0, "maxStall": 0, "pidN": 0,
               "flashC": "#ffffff",
               "items": [], "itemT": 0, "itemN": 0,
               "st": { "blk": [0, 0], "par": [0, 0], "gb": [0, 0], "maxMv": 0, "hits": [0, 0], "sup": [0, 0], "supHit": [0, 0], "pk": { "drop": 0, "heal": 0, "speed": 0, "bomb": 0, "boom": 0, "bombHit": 0, "giveUp": 0 } } };
        for (const f of sm.f)
            if (f.img) { fCv0.loadImage(f.img); fCv1.loadImage(f.img); }
        g.say = tl("Дааамы и господааа! Добро пожаловать на бой года!", "Ladies and gentlemen! Welcome to the fight of the year!");
        tick.last = 0; tick.start();
        hallBg.requestPaint(); staticCv.requestPaint(); ropeBack.requestPaint(); ropeFront.requestPaint(); annCv.requestPaint(); trCv.requestPaint(); scanCv.requestPaint(); vigCv.requestPaint();
        fadeIn.start();
    }

    // ── helpers
    function comment(txt, force) {
        if (force || sm.sayCd <= 0) { g.say = txt; sm.sayCd = 80; g.sayT = 40; if (force && sm.frame - (sm.blipT || -999) > 90) { sm.blipT = sm.frame; g.sfx("blip", 0.35); } }
    }
    function dust(x, n) {
        for (let i = 0; i < n; i++)
            sm.parts.push({ "x": x + (Math.random() - 0.5) * 30, "y": fy - 2, "vx": (Math.random() - 0.5) * 4, "vy": -Math.random() * 2, "g": 0.05, "life": 18 + Math.random() * 10, "c": "#b9a88a", "s": 4 });
    }
    function wcols(wp) { return wp ? wp.cols.map(c => c.length === 1 ? g.wcol(c) : c) : []; }
    function sparks(x, y, n, crit, wp, extra) {
        const cols = [String(cAccent), String(cAccent2), "#ffffff", crit ? String(cDanger) : "#ffe066"].concat(wcols(wp), wcols(wp), extra || []);
        for (let i = 0; i < n; i++) {
            const ang = Math.random() * Math.PI * 2, sp = 2 + Math.random() * (crit ? 9 : 5);
            sm.parts.push({ "x": x, "y": y, "vx": Math.cos(ang) * sp, "vy": Math.sin(ang) * sp, "g": 0.25, "life": 12 + Math.random() * 12, "c": rnd(cols), "s": crit ? 5 : 4 });
        }
    }
    function splash(x, y) {
        for (let i = 0; i < 14; i++)
            sm.parts.push({ "x": x, "y": y, "vx": (Math.random() - 0.5) * 5, "vy": -Math.random() * 4, "g": 0.3, "life": 18, "c": rnd(["#6ec3e8", "#bfe8ff", "#ffffff"]), "s": 4 });
    }
    function confetti() {
        const cols = g.coats.concat([String(cAccent), String(cAccent2), "#ffffff"]);
        for (let i = 0; i < 110; i++)
            sm.parts.push({ "x": 60 + Math.random() * 780, "y": -10 - Math.random() * 180, "vx": (Math.random() - 0.5) * 2, "vy": 1 + Math.random() * 2, "g": 0.03, "life": 170 + Math.random() * 60, "c": rnd(cols), "s": 4, "wob": Math.random() * 6 });
    }
    function rain(bmp) {
        for (let i = 0; i < 24; i++)
            sm.parts.push({ "x": 120 + Math.random() * 660, "y": -20 - Math.random() * 200, "vx": (Math.random() - 0.5) * 2, "vy": 2 + Math.random() * 2, "g": 0.2, "life": 90, "bmp": bmp, "rot": Math.random() * 6, "s": 3 });
    }
    function floatText(x, y, txt, col, big, vx, vy) {
        sm.floats.push({ "x": x, "y": y, "t": txt, "c": col, "life": 36, "big": big, "vx": vx || 0, "vy": vy === undefined ? -1.1 : vy });
    }

    // ── combat
    // per-weapon impact sounds
    readonly property var hitSfx: ({ "fists": "punch", "slipper": "slap", "bat": "crack", "fish": "splat", "mic": "boom", "keyboard": "clack", "bread": "thud", "laser": "zap" })
    function hitSound(wp, mv, crit) {
        let n = hitSfx[wp.id] || "punch";
        if (mv.k === "homerun") n = "homerun";
        else if (mv.id === "spray") n = "clack";
        else if (mv.k === "wave") n = mv.big ? "feedback" : "boom";
        g.sfx(n, 0.9);
        if (crit) { g.sfx("crit", 0.8); g.sfx("cheer", 0.5); }
    }
    function hit(att, def, mv, jump) {
        if (sm.phase !== "fight" || def.st === "ko") return;
        mv = mv || {};
        const wp = att.wep;
        const hx = (att.x + def.x) / 2, hy = fy - def.y - 60;
        if (!mv.sp && Math.random() < 0.1) {
            floatText(hx, hy - 20, tl("мимо!", "miss!"), String(cText), false);
            g.sfx("whoosh", 0.5);
            sm.last = ""; sm.combo = 0; g.combo = 0;
            return;
        }
        const crit = !mv.sp && Math.random() < wp.crit * (mv.cm || 1);
        const hits = wp.hits && !mv.dm ? wp.hits[0] + Math.floor(Math.random() * (wp.hits[1] - wp.hits[0] + 1)) : 1;
        let dmg = 0;
        for (let i = 0; i < hits; i++) dmg += wp.dmg[0] + Math.random() * (wp.dmg[1] - wp.dmg[0] + 1);
        if (mv.fixed) dmg = mv.fixed * (0.88 + Math.random() * 0.27);          // supers: a fixed share of the bar, whatever the weapon
        else dmg = dmg * (mv.dm || 1) + (jump ? 4 : 0);
        if (crit) dmg *= (wp.critMul || 2);
        dmg = Math.max(1, Math.round(dmg * dmgScale * (g.rounds === 0 ? 1 + 0.5 * (sm.round - 1) : 1)));
        if (g.shieldOn && def.st === "block") { blocked(att, def, dmg, crit, mv, wp, hx, hy); return; }
        sm.st.hits[att.side]++;
        if (mv.sp) sm.st.supHit[att.side] += dmg;
        else { const dm = Math.min(1.3, mv.dm || 1); addSp(att, 6 + 7 * dm); addSp(def, 5 + 5 * dm); }
        def.hp = Math.max(0, def.hp - dmg);
        hitSound(wp, mv, crit);
        sm.dmg[att.side] += dmg;
        sm.lastDmg = sm.frame;
        def.vx = att.face * (crit ? 15 : 8) * wp.kb * (mv.kb || 1);
        def.vy = mv.vy || (crit ? 8 : 4);
        const armor = def.st === "atk" && def.mv && def.mv.k === "super";          // a charging super can't be interrupted
        if (armor) def.vx *= 0.2;
        else if (def.st !== "ko") { def.st = "hurt"; def.t = crit ? 16 : 10; }
        def.flash = 5;
        def.squash = 7;
        att.vx = -att.face * 2;
        {
            const pw = (ar.power[wp.id] || 1) * (crit ? 1.6 : 1) * ((mv.kb || 1) > 1.5 ? 1.3 : 1);
            sm.freeze = Math.max(sm.freeze, Math.min(4, Math.round(1 + pw * 1.2)));
            sm.punch = Math.min(0.28, sm.punch + 0.045 * pw);
            sm.px = hx; sm.py = hy;
            sm.sdx = att.face; sm.sdy = (mv.k === "overhead" || mv.k === "spacebar") ? 1 : 0.25;
            sm.shake = Math.max(sm.shake, 3 * pw);
            sm.rings.push({ "x": hx, "y": hy, "r": 6, "life": 12 + 4 * pw, "round": true, "c": crit ? "#ffe066" : "#ffffff" });
            if (crit) { sm.flash = Math.max(sm.flash, 4); sm.scan = 6; }
            sm.vig = Math.min(1, sm.vig + 0.25 * pw);
        }
        sparks(hx, hy, crit ? 22 : 9, crit, wp);
        sm.shake = Math.max(sm.shake, (crit ? 12 : 4) + (mv.shake || 0));
        sm.hype = Math.min(1, sm.hype + (crit ? 0.6 : 0.25));
        if (!armor && (mv.stun || wp.stun) && Math.random() < (mv.stun || wp.stun)) {
            def.stun = 34; floatText(hx, hy - 64, tl("оглушён(а)!", "stunned!"), "#6ec3e8", false);
            comment(rnd(tl([def.who.name + " видит звёзды и пинг 999!", "Оглушение! Кто-нибудь, дайте ему нашатырь!", def.who.name + " временно AFK!"], [def.who.name + " sees stars and ping 999!", "Stunned! Somebody get the smelling salts!", def.who.name + " is temporarily AFK!"])));
        }
        if (wp.heal) { att.hp = Math.min(100, att.hp + wp.heal); floatText(att.x, fy - 130, "+" + wp.heal + tl(" хрум", " crunch"), String(cOk), false); }
        if (wp.keys) for (let i = 0; i < 5; i++) floatText(hx, hy, rnd(["Q", "W", "E", "A", "S", "D", "F4", "Esc", "Shift", "Ctrl", "Tab"]), "#ffffff", false, (Math.random() - 0.5) * 7, -2 - Math.random() * 3);
        if (sm.last === att.who.id) sm.combo++; else { sm.last = att.who.id; sm.combo = 1; }
        g.combo = sm.combo;
        g.lastHit = wp.id + ":" + (mv.id || "basic") + (crit ? " crit" : "") + " " + dmg;
        floatText(hx, hy - 24, (crit ? tl("КРИТ! ", "CRIT! ") : "") + "−" + dmg + (hits > 1 ? " ×" + hits : ""), crit ? String(cDanger) : "#ffffff", crit);
        floatText(hx, hy - 44, rnd(mv.w || wp.words), String(cAccent2), false);
        if (crit) sm.cam = 18;
        if (crit) comment(rnd(tl(["Какой крит! Это было больно даже мне!", "КРИТИЧЕСКИЙ УРОН! Судьи плачут!", "Ой-ой-ой, это в хайлайты!"], ["What a crit! Even I felt that!", "CRITICAL DAMAGE! The judges are crying!", "Oh-oh-oh, that one goes in the highlights!"])));
        else if (sm.combo >= 3) comment(tl("Комбо ×" + sm.combo + "! Зал в экстазе!", "Combo ×" + sm.combo + "! The crowd goes wild!"));
        if (def.hp < 25 && !def.low && def.hp > 0) { def.low = true; comment(def.who.name + tl(" на последнем издыхании! Держись, бро!", " is on their last legs! Hang in there, bro!")); }
        g.hpA = sm.f[0].hp; g.hpB = sm.f[1].hp;
        if (def.hp <= 0) finisher(att, def);
    }
    // a hit that lands on a raised shield: chip damage, no stagger; a perfectly timed block staggers the attacker
    function blocked(att, def, dmg, crit, mv, wp, hx, hy) {
        const sup = !!mv.sp;
        // perfect = early shield window only (startup frames 0–2 don't count; holding too long doesn't either)
        const perfect = !sup && def.blkAge >= 3 && def.blkAge <= 9;
        const d = perfect ? 0 : Math.max(1, Math.round(dmg * (sup ? 0.5 : crit ? 0.32 : 0.2)));
        def.hp = Math.max(0, def.hp - d);
        sm.dmg[att.side] += d; sm.lastDmg = sm.frame;
        def.vx = att.face * 2.5; def.flash = 0; def.bflash = 7;
        att.vx = -att.face * (perfect ? 7 : 3);
        def.gd -= sup ? 120 : 14 + dmg * 0.8;
        sm.st.blk[def.side]++;
        if (sup) sm.st.supHit[att.side] += d; else { addSp(def, perfect ? 12 : 5); addSp(att, 3); }
        g.sfx(perfect ? "parry" : "block", 0.9);
        g.sfx(hitSfx[wp.id] || "punch", 0.25);
        sm.freeze = Math.max(sm.freeze, perfect ? 4 : 2);
        sm.shake = Math.max(sm.shake, perfect ? 6 : 3);
        sm.rings.push({ "x": hx, "y": hy, "r": 6, "life": 12, "round": true, "c": perfect ? "#ffffff" : "#7fe0ff" });
        for (let i = 0; i < (perfect ? 18 : 9); i++) {
            const ang = Math.random() * Math.PI * 2, sp = 2 + Math.random() * 5;
            sm.parts.push({ "x": hx, "y": hy, "vx": Math.cos(ang) * sp, "vy": Math.sin(ang) * sp, "g": 0.15, "life": 12 + Math.random() * 8, "c": rnd(["#7fe0ff", "#bff3ff", "#ffffff"]), "s": 4 });
        }
        snapEv(perfect ? "parry" : "block", 90);
        floatText(hx, hy - 24, perfect ? tl("ИДЕАЛЬНЫЙ БЛОК!", "PERFECT BLOCK!") : tl("БЛОК!", "BLOCK!"), perfect ? "#ffffff" : "#7fe0ff", perfect);
        if (d > 0) floatText(hx, hy - 4, "−" + d, "#bff3ff", false);
        if (perfect) {
            att.st = "hurt"; att.t = 18; att.stun = 22; att.flash = 4; att.squash = 6; att.mv = null; att.noWep = false;
            def.t = Math.min(def.t, 3); def.cd = 0;
            sm.st.par[def.side]++;
            sm.cam = Math.max(sm.cam, 14);
            floatText(att.x, fy - att.y - 150, tl("оглушён(а)!", "staggered!"), "#6ec3e8", false);
            comment(rnd(tl([def.who.name + " читает " + att.who.name + " как открытую книгу!", "Идеальный блок! Контратака на подходе!", "Парирование! " + att.who.name + " в шоке!"], [def.who.name + " reads " + att.who.name + " like an open book!", "Perfect block! A counter is coming!", "Parried! " + att.who.name + " is stunned!"])));
        } else if (Math.random() < 0.3) comment(rnd(tl(["Щит держит!", "Какой блок!", "Через такую защиту не пройти!"], ["The shield holds!", "What a block!", "Nothing gets through that guard!"])));
        if (def.gd <= 0 && def.st === "block") {
            def.gd = 0; def.st = "hurt"; def.t = 20; def.stun = 30; def.blkCd = 90; def.squash = 6;
            sm.st.gb[def.side]++;
            floatText(def.x, fy - def.y - 150, tl("ЩИТ РАЗБИТ!", "GUARD BREAK!"), "#ff8a3d", true); snapEv("guard", 80);
            sparks(def.x, fy - def.y - 60, 16, true, null, ["#7fe0ff", "#ffffff"]);
            g.sfx("crit", 0.5);
        }
        g.lastHit = wp.id + ":" + (mv.id || "basic") + (perfect ? " parry" : " block") + " " + d;
        g.hpA = sm.f[0].hp; g.hpB = sm.f[1].hp;
        if (def.hp <= 0) finisher(att, def);
    }
    function tryBlock(f, e, dist, dt) {
        if (f.blkCd > 0 || f.gd < 30 || f.stun > 0) return false;
        let threat = 0, id = 0;
        if (e.st === "atk" && e.mv && e.mv.k !== "eat" && e.mv.k !== "super") {
            const reach = e.mv.r ? Math.min(e.mv.r, 340) : Math.min(e.wep.range, 104) + 16;
            if (dist < reach) { threat = 1; id = e.atkN; }
        } else if (e.st === "jatk" && dist < 140) { threat = 0.8; id = e.atkN; }
        if (!threat)
            for (const q of sm.proj)
                if (q.tgt === f && q.k !== "mic" && Math.abs(q.x - f.x) < 150 && (q.x - f.x) * q.vx < 0) { if (!q.pid) q.pid = 1000 + (++sm.pidN); threat = 0.9; id = q.pid; break; }
        if (threat) {
            if (f.seen === id) return false;                   // already decided about this attack
            f.seen = id;
            if (Math.random() >= (0.4 + (f.hp < 40 ? 0.15 : 0) + (f.hp < 20 ? 0.1 : 0)) * threat) return false;
        } else if (f.cd <= 0 || dist > 190 || Math.random() > 0.012 * dt) return false;   // idle guard stance while waiting
        f.st = "block"; f.t = 14 + Math.random() * 4; f.blkAge = 0; f.gd -= 8; f.vx = 0;
        return true;
    }
    // ── super move: the meter fills from hits dealt/taken; when full the fighter fires a flashy, unstoppable (but guard-breakable) weapon move
    function addSp(f, n) {
        if (!g.superOn || f.st === "ko") return;
        const was = f.sp;
        f.sp = Math.min(100, f.sp + n);
        if (was < 100 && f.sp >= 100) {
            floatText(f.x, fy - f.y - 165, tl("СУПЕР ГОТОВ!", "SUPER READY!"), "#ffd34d", true);
            g.sfx("sting", 0.45);
            for (let i = 0; i < 16; i++) sm.parts.push({ "x": f.x + (Math.random() - 0.5) * 50, "y": fy - f.y - 20 - Math.random() * 90, "vx": (Math.random() - 0.5) * 2, "vy": -1 - Math.random() * 3, "g": 0.02, "life": 24, "c": rnd(["#ffd34d", "#fff2a8", "#ffffff"]), "s": 4 });
        }
    }
    // weapon-specific supers: n = name, nh = hits, lunge = dash to the target first, fx = extra effect
    function superOf(wp) {
        const S = {
            "fists": { "n": tl("МЕГА-ХУК", "MEGA HOOK"), "nh": 1, "lunge": true, "kb": 2.6, "vy": 15, "fx": "stars" },
            "slipper": { "n": tl("ТАПОЧНЫЙ АРМАГЕДДОН", "SLIPPER ARMAGEDDON"), "nh": 5, "lunge": true, "kb": 0.5, "fx": "stars" },
            "bat": { "n": tl("ГРАНД-СЛЭМ", "GRAND SLAM"), "nh": 1, "lunge": true, "kb": 3.4, "vy": 16, "fx": "stars" },
            "fish": { "n": tl("РЫБНОЕ ЦУНАМИ", "FISH TSUNAMI"), "nh": 1, "lunge": false, "kb": 2.4, "vy": 12, "fx": "tsunami" },
            "mic": { "n": tl("ЗВУКОВОЙ УДАР", "SONIC BOOM"), "nh": 1, "lunge": false, "kb": 2.8, "vy": 10, "fx": "sonic" },
            "keyboard": { "n": tl("СИНИЙ ЭКРАН СМЕРТИ", "BLUE SCREEN OF DEATH"), "nh": 3, "lunge": true, "kb": 1.2, "fx": "bsod" },
            "bread": { "n": tl("ХЛЕБНЫЙ ПИР", "BREAD FEAST"), "nh": 2, "lunge": true, "kb": 1.6, "fx": "feast" },
            "laser": { "n": tl("ОРБИТАЛЬНЫЙ ЛАЗЕР", "ORBITAL LASER"), "nh": 1, "lunge": false, "kb": 2.2, "vy": 12, "fx": "orbital" }
        };
        const s = S[wp.id] || S.fists;
        return Object.assign({ "id": "super", "k": "super", "t": 34, "sp": true, "fixed": 36, "dm": 1, "w": [s.n + "!"] }, s);
    }
    function superStart(f, mv) {
        f.sp = 0;
        sm.st.sup[f.side]++;
        g.sfx("supercharge", 1);
        sm.vig = 1; sm.cam = 36; sm.punch = Math.max(sm.punch, 0.1); sm.px = f.x; sm.py = fy - 90; sm.scan = 14;
        floatText(f.x, fy - f.y - 175, mv.n + "!", "#ffd34d", true, 0, -0.4);
        comment(rnd(tl([f.who.name + ": СУПЕРУДАР «" + mv.n + "»!", "Зал замер! Сейчас будет больно!", f.who.name + " заряжает что-то ужасное!"], [f.who.name + ": SUPER MOVE “" + mv.n + "”!", "The hall goes silent! This will hurt!", f.who.name + " is charging something terrible!"])), true);
        snapEv("supercharge", 330);
    }
    function superStrike(f, e, i, mv) {
        const first = i === 0;
        if (first && mv.lunge) {
            const nx = Math.max(ropeL, Math.min(ropeR, e.x - f.face * 56));
            for (let k = 0; k < 7; k++) f.trail.unshift({ "x": f.x + (nx - f.x) * k / 7, "y": f.y });
            if (f.trail.length > 4) f.trail.length = 4;
            dust(f.x, 6); f.x = nx; dust(nx, 8); f.vx = 0;
        }
        const m2 = { "id": "super", "sp": true, "fixed": mv.fixed / mv.nh, "kb": i === mv.nh - 1 ? mv.kb : 0.3, "vy": i === mv.nh - 1 ? mv.vy : 3, "w": mv.w, "shake": 10, "dm": 1 };
        sm.flash = Math.max(sm.flash, first ? 7 : 3);
        sm.flashC = mv.fx === "bsod" ? "#2f6bff" : mv.fx === "orbital" ? "#ff4f6d" : mv.fx === "tsunami" ? "#6ec3e8" : "#fff2a8";
        sm.shake = Math.max(sm.shake, 12); sm.cam = 40; sm.punch = Math.min(0.3, sm.punch + 0.1); sm.scan = 8;
        if (first) {
            g.sfx("super", 1); g.sfx("cheer", 0.6);
            snapEv("super", 190);
        }
        switch (mv.fx) {
        case "tsunami": splash(e.x, fy - 90); splash(e.x - 30, fy - 60); splash(e.x + 30, fy - 60); sm.rings.push({ "x": e.x, "y": fy - 4, "r": 10, "life": 26 }); break;
        case "sonic": for (const r0 of [8, 30, 56]) sm.rings.push({ "x": f.x + f.face * 40, "y": fy - 80, "r": r0, "life": 24, "round": true, "c": "#ffffff" }); sm.beams.push({ "x1": f.x + f.face * 30, "x2": e.x, "y": fy - f.y - 80, "life": 8, "w": 36 }); break;
        case "orbital": sm.beams.push({ "x1": e.x, "x2": e.x + (f.face > 0 ? 60 : -60), "y": fy - 150, "life": 12, "w": 20 }); sm.beams.push({ "x1": f.x + f.face * 40, "x2": e.x, "y": fy - f.y - 80, "life": 12, "w": 42 }); sm.maxBeam = 10; break;
        case "bsod": for (let k = 0; k < 5; k++) floatText(e.x + (Math.random() - 0.5) * 80, fy - 100 - Math.random() * 40, rnd([":(", "0x0000007B", "FATAL", "Ctrl+Alt+Del", "STOP"]), "#ffffff", false, (Math.random() - 0.5) * 4, -2); break;
        case "feast": sparks(f.x + f.face * 30, fy - f.y - 70, 24, true, null, ["#e0b060", "#8a5a2b"]); if (first) { f.hp = Math.min(100, f.hp + 8); g.hpA = sm.f[0].hp; g.hpB = sm.f[1].hp; floatText(f.x, fy - f.y - 140, "+8 " + tl("*хрум*", "*crunch*"), String(cOk), false); } break;
        default: for (let k = 0; k < 6; k++) floatText(e.x, fy - 120, "★", "#ffe066", true, (Math.random() - 0.5) * 6, -2 - Math.random() * 2);
        }
        hit(f, e, m2, false);
        if (first) comment(tl("«" + mv.n + "»! Прямо в цель!", "“" + mv.n + "”! Right on target!"), true);
    }
    // ── arena pickups: heal kit, speed boost, bomb. They drop from above; fighters walk over to grab them
    function itemGap() { return g.pickupRate === "rare" ? 330 : g.pickupRate === "often" ? 115 : 190; }
    function spawnItem(kind) {
        if (sm.items.length >= 3) return;
        if (!kind) {
            const lo = Math.min(sm.f[0].hp, sm.f[1].hp);
            const wh = lo < 50 ? 0.5 : lo < 80 ? 0.34 : 0.14, ws = 0.34, wb = 0.28;
            let r = Math.random() * (wh + ws + wb);
            kind = (r -= wh) < 0 ? "heal" : (r -= ws) < 0 ? "speed" : "bomb";
        }
        const used = sm.items.map(q => q.slot); let slot = 0; while (used.indexOf(slot) >= 0) slot++;
        const pick = () => ropeL + 70 + Math.random() * (ropeR - ropeL - 140);
        let x = pick();
        for (let k = 0; k < 8 && !sm.f.every(f => Math.abs(f.x - x) > 80); k++) x = pick();
        sm.items.push({ "id": ++sm.itemN, "k": kind, "x": x, "y": 320, "vy": 0, "vx": 0, "st": "fall", "t": 0, "life": 330, "fuse": 0, "slot": slot, "thrown": false, "bounced": false });
        sm.st.pk.drop++;
        g.sfx("drop", 0.7);
        snapEv("drop", 900);
    }
    function bombNear(f) {
        for (const it of sm.items) if (it.k === "bomb" && it.st === "fuse" && it.fuse > 8 && Math.abs(f.x - it.x) < 135) return it;
        return null;
    }
    // which item (if any) this fighter decides to walk to: closer than the rival, or badly wanted
    function pickTarget(f, e) {
        let best = null, bs = 0;
        for (const it of sm.items) {
            if (it.st !== "ready" && !(it.k === "bomb" && it.st === "fuse" && it.fuse > 40 && !it.thrown)) continue;
            const dm = Math.abs(f.x - it.x), de = Math.abs(e.x - it.x);
            if (dm > 420) continue;
            const want = it.k === "heal" ? (f.hp < 45 ? 1 : f.hp < 70 ? 0.75 : 0.3) : it.k === "speed" ? 0.6 : 0.65;
            if (dm > de * 1.15 + 60 && want < 0.9) continue;
            const s = want * (1 - dm / 600);
            if (s > bs) { bs = s; best = it; }
        }
        return best && Math.random() < Math.min(1, bs * 1.5 + 0.15) ? best : null;
    }
    function collect(f, e, it) {
        const hx = it.x, hy = fy - 50;
        if (it.k === "heal") {
            const H = Math.round(24 * Math.max(0.55, dmgScale));
            f.hp = Math.min(100, f.hp + H); if (f.hp >= 25) f.low = false;
            g.hpA = sm.f[0].hp; g.hpB = sm.f[1].hp;
            sm.st.pk.heal++;
            g.sfx("heal", 0.9);
            for (let i = 0; i < 30; i++) sm.parts.push({ "x": f.x + (Math.random() - 0.5) * 56, "y": fy - f.y - 10 - Math.random() * 40, "vx": (Math.random() - 0.5) * 1.5, "vy": -1 - Math.random() * 2.6, "g": -0.015, "life": 26 + Math.random() * 14, "c": rnd(["#3ddc84", "#9bffb8", "#ffffff", "#5de6a0"]), "s": 4 });
            sm.rings.push({ "x": f.x, "y": fy - 6, "r": 8, "life": 16, "c": "#3ddc84" });
            floatText(f.x, fy - f.y - 140, "+" + H + " HP", "#3ddc84", true);
            comment(rnd(tl([f.who.name + " хватает аптечку!", "Аптечка! Свежие силы!", f.who.name + " подлатался!"], [f.who.name + " grabs the heal kit!", "A heal kit! Fresh strength!", f.who.name + " patches up!"])));
            snapEv("heal", 140);
        } else if (it.k === "speed") {
            f.spd = 210;
            sm.st.pk.speed++;
            g.sfx("boost", 0.9);
            sparks(f.x, fy - f.y - 50, 16, false, null, ["#ffe066", "#fff2a8", "#6ec3e8"]);
            sm.rings.push({ "x": f.x, "y": fy - 6, "r": 8, "life": 14, "c": "#ffe066" });
            floatText(f.x, fy - f.y - 140, tl("УСКОРЕНИЕ!", "SPEED UP!"), "#ffe066", true);
            comment(rnd(tl([f.who.name + " ускоряется! Не моргай!", "Ускорение! Это уже не бокс, это Формула-1!"], [f.who.name + " speeds up! Don't blink!", "Speed boost! This isn't boxing anymore, it's Formula 1!"])));
            snapEv("speed", 650);
        } else {
            // the bomb: grabbed and lobbed straight at the rival, a fresh short fuse
            it.st = "fly"; it.thrown = true; it.own = f; it.y = 55; it.t = 0;
            const tx = Math.max(ropeL + 20, Math.min(ropeR - 20, e.x + e.vx * 6));
            it.vy = 11; const tl2 = (it.vy + Math.sqrt(it.vy * it.vy + 2 * 1.1 * it.y)) / 1.1;
            it.vx = (tx - it.x) / tl2; it.x = f.x + f.face * 16;  it.vx = (tx - it.x) / tl2;
            sm.st.pk.bomb++;
            g.sfx("whoosh", 0.7);
            floatText(f.x, fy - f.y - 140, tl("ПОЛУЧАЙ!", "CATCH!"), "#ff8a3d", true);
            comment(rnd(tl(["Бомба летит! Все в укрытие!", f.who.name + " швыряет бомбу в " + e.who.name + "!"], ["The bomb is flying! Take cover!", f.who.name + " lobs the bomb at " + e.who.name + "!"])));
            f.cd = Math.max(f.cd, 6);
        }
    }
    function explode(it) {
        const R = 110;
        sm.st.pk.boom++;
        g.sfx("boom", 1); g.sfx("crack", 0.6);
        sm.flash = Math.max(sm.flash, 5); sm.flashC = "#ffb347"; sm.shake = Math.max(sm.shake, 16); sm.cam = 30; sm.punch = Math.min(0.3, sm.punch + 0.12); sm.px = it.x; sm.py = fy - 40; sm.freeze = Math.max(sm.freeze, 3);
        sm.rings.push({ "x": it.x, "y": fy - 14, "r": 10, "life": 22, "round": true, "c": "#ffb347" });
        sm.rings.push({ "x": it.x, "y": fy - 14, "r": 2, "life": 18, "round": true, "c": "#ffffff" });
        for (let i = 0; i < 46; i++) {
            const an = Math.random() * Math.PI * 2, sp = 2 + Math.random() * 9;
            sm.parts.push({ "x": it.x, "y": fy - 14, "vx": Math.cos(an) * sp, "vy": Math.sin(an) * sp - 2, "g": 0.2, "life": 16 + Math.random() * 16, "c": rnd(["#ff8a3d", "#ffd34d", "#ffffff", "#c0392b", "#444444"]), "s": 5 });
        }
        floatText(it.x, fy - 120, "BOOM!", "#ffb347", true);
        snapEv("boom", 170);
        const dead = [];
        for (const f of sm.f) {
            const dx = f.x - it.x, d = Math.abs(dx);
            if (d > R || f.y > 90 || f.st === "ko") continue;
            let dmg = Math.round((12 + 12 * (1 - d / R)) * Math.max(0.5, dmgScale));
            if (g.shieldOn && f.st === "block") {
                dmg = Math.round(dmg * 0.4); f.gd -= 30; f.bflash = 6; g.sfx("block", 0.8);
                floatText(f.x, fy - f.y - 130, tl("БЛОК!", "BLOCK!"), "#7fe0ff", false);
            } else if (!(f.st === "atk" && f.mv && f.mv.k === "super")) {
                f.st = "hurt"; f.t = 16; f.vx = (dx >= 0 ? 1 : -1) * (6 + 12 * (1 - d / R)); f.vy = 10; f.flash = 5; f.squash = 7; f.stun = 14; f.mv = null; f.noWep = false;
            }
            f.hp -= dmg; sm.st.pk.bombHit += dmg; sm.dmg[1 - f.side] += dmg; sm.lastDmg = sm.frame;
            floatText(f.x, fy - f.y - 100, "−" + dmg, String(cDanger), true);
            if (f.hp <= 0) dead.push(f);
        }
        if (dead.length === 2) { const keep = dead[0].hp > dead[1].hp ? dead[0] : dead[1]; keep.hp = 1; dead.splice(dead.indexOf(keep), 1); }
        for (const f of sm.f) f.hp = Math.max(0, f.hp);
        g.hpA = sm.f[0].hp; g.hpB = sm.f[1].hp;
        g.lastHit = "bomb " + sm.st.pk.bombHit;
        if (dead.length && sm.phase === "fight") finisher(sm.f[1 - dead[0].side], dead[0]);
        else comment(rnd(tl(["БАБАХ! Зал в восторге!", "Это было громко!"], ["KABOOM! The crowd loves it!", "That was loud!"])));
    }
    function stepItems(dt) {
        if (g.dbgSpawn) { if (sm.phase === "fight") spawnItem(g.dbgSpawn); g.dbgSpawn = ""; }
        if (sm.phase !== "fight") { if (sm.items.length) sm.items = []; return; }
        if (g.pickupsOn) { sm.itemT -= dt; if (sm.itemT <= 0) { spawnItem(); sm.itemT = itemGap() * (0.7 + Math.random() * 0.6); } }
        if (!sm.items.length) return;
        const keep = [];
        for (const it of sm.items) {
            it.t += dt;
            if (it.st === "fall" || it.st === "fly") {
                it.vy -= 1.1 * dt; it.y += it.vy * dt; it.x += it.vx * dt;
                if (it.y <= 0 && it.vy < 0) {
                    it.y = 0;
                    if (it.st === "fall" && it.vy < -6 && !it.bounced) { it.vy = -it.vy * 0.3; it.bounced = true; it.y = 0.01; dust(it.x, 5); }
                    else { it.vy = 0; it.vx = 0; dust(it.x, 5); it.t = 0; if (it.st === "fly") { it.st = "fuse"; it.fuse = 36; g.sfx("fuse", 0.8); } else it.st = "ready"; }
                }
            } else if (it.st === "ready") {
                it.life -= dt;
                if (it.life <= 0) { sparks(it.x, fy - 20, 8, false, null, ["#ffffff"]); continue; }
                if (it.k === "bomb" && it.t > 105) { it.st = "fuse"; it.fuse = 70; g.sfx("fuse", 0.8); snapEv("fuse", 500); }
            } else if (it.st === "fuse") {
                it.fuse -= dt;
                if (it.fuse <= 0) { explode(it); continue; }
            }
            if (sm.phase === "fight" && (it.st === "ready" || (it.k === "bomb" && it.st === "fuse" && it.fuse > 28 && !it.thrown))) {
                let got = null;
                for (const f of (Math.random() < 0.5 ? [sm.f[0], sm.f[1]] : [sm.f[1], sm.f[0]]))
                    if (Math.abs(f.x - it.x) < 28 && f.y < 40 && (f.st === "idle" || f.st === "dash" || f.st === "fetch" || f.st === "block" || f.st === "atk" || f.st === "jatk" || f.st === "flee")) { got = f; break; }
                if (got) { collect(got, sm.f[1 - got.side], it); if (it.k !== "bomb") continue; }
            }
            keep.push(it);
        }
        sm.items = keep;
        for (const f of sm.f)
            if (f.spd > 0 && Math.abs(f.vx) > 2 && Math.random() < 0.6)
                sm.parts.push({ "x": f.x - Math.sign(f.vx) * 12, "y": fy - f.y - 8 - Math.random() * 62, "vx": -f.vx * 0.15, "vy": 0, "g": 0, "life": 9, "c": rnd(["#ffe066", "#fff2a8", "#6ec3e8"]), "s": 4 });
    }
    function finisher(att, def) {
        const fin = att.wep.fin;
        def.st = "ko"; def.vx = att.face * 20; def.vy = 13;
        att.st = "idle"; att.noWep = false;
        sm.phase = "ko"; sm.phT = 0; sm.slow = 0.22; sm.slowT = 40; sm.shake = 16;
        sparks((att.x + def.x) / 2, fy - def.y - 60, 34, true, att.wep);
        g.ko = true; g.banner = "K.O.!"; g.finText = fin.t;
        g.sfx("ko", 1); g.sfx("cheer", 0.8); g.sfx("gong", 0.6);
        sm.cam = 60; sm.hype = 1; sm.freeze = 6; sm.punch = 0.3; sm.vig = 1; sm.scan = 10;
        sm.rings.push({ "x": def.x, "y": fy - def.y - 60, "r": 8, "life": 30, "round": true, "c": "#ffffff" });
        sm.winner = att; sm.loser = def; sm.byKO = true;
        g.lastHit = att.wep.id + ":finisher";
        switch (fin.fx) {
        case "launch": def.vy = 26; def.vx = att.face * 9; break;
        case "rain": rain(att.wep.bmp); break;
        case "micdrop": sm.proj.push({ "k": "mic", "x": def.x, "y": -40, "vy": 0, "tgt": def, "bmp": att.wep.bmp }); break;
        case "altf4": def.fade = true; floatText(def.x, fy - 150, tl("[×] окно закрыто", "[×] window closed"), "#ffffff", true); break;
        case "crumbs": sparks(def.x, fy - 60, 70, true, att.wep, ["#e0b060", "#8a5a2b"]); break;
        case "maxbeam": sm.flash = 12; sm.maxBeam = 18; break;
        default: for (let i = 0; i < 6; i++) floatText(def.x, fy - 120, "★", "#ffe066", true, (Math.random() - 0.5) * 6, -2 - Math.random() * 2);
        }
        comment(tl("НОКАУТ! ", "KNOCKOUT! ") + fin.t + " " + att.who.name + tl(" побеждает ", " wins ") + att.wep.ins + "!", true);
    }
    function startMove(f, mv) {
        f.st = "atk"; f.mv = mv; f.t = mv.t || 10; f.hitDone = false; f.atkN++;
        const k = mv.k;
        if (k === "swing" || k === "overhead" || k === "homerun" || k === "spacebar" || k === "flurry" || k === "throw") g.sfx("whoosh", 0.55);
        else if (k === "spray") g.sfx("keys", 0.7);
        else if (k === "wave") g.sfx("feedback", mv.big ? 0.6 : 0.35);
        else if (k === "beam" || k === "eyeblast") g.sfx("zap", 0.5);
        if (k !== "super") floatText(f.x, fy - f.y - 140, "«" + mv.n + "»", String(cAccent2), false, 0, -0.6);
        if (k === "super") superStart(f, mv);
        if (mv.k === "homerun" && Math.random() < 0.5) comment(f.who.name + tl(" замахивается на хоумран!", " winds up for a home run!"));
    }
    function moveTick(f, e, dist) {
        const mv = f.mv, k = mv.k, t = f.t, wp = f.wep;
        const melee = () => { if (dist < Math.min(wp.range, 104) + 12) hit(f, e, mv, false); else floatText(f.x + f.face * 50, fy - 100, tl("мимо!", "miss!"), String(cText), false); };
        const at = n => t <= n && t + sm.dt > n;
        switch (k) {
        case "swing": case "overhead": case "homerun": case "spacebar": if (at(4)) melee(); break;
        case "flurry": for (const n of [11, 8, 5, 2].slice(0, mv.nh || 3)) if (at(n)) melee(); break;
        case "throw": if (at(5)) { f.noWep = true; sm.proj.push({ "k": "throw", "x": f.x + f.face * 10, "y": fy - 80, "vx": f.face * 11, "own": f, "tgt": e, "bmp": wp.bmp, "rot": 0, "back": false, "life": 90, "mv": mv }); } break;
        case "wave": if (at(5)) sm.proj.push({ "k": "wave", "x": f.x + f.face * 14, "y": fy - 80, "vx": f.face * 11, "own": f, "tgt": e, "life": 50, "size": mv.big ? 1.7 : 1, "mv": mv }); break;
        case "flop": if (at(5)) sm.proj.push({ "k": "flop", "x": f.x + f.face * 10, "y": fy - 6, "vx": f.face * 6, "own": f, "tgt": e, "life": 80, "bmp": wp.bmp, "mv": mv }); break;
        case "spray": if (at(6)) for (let i = 0; i < 5; i++) sm.proj.push({ "k": "key", "x": f.x + f.face * 10, "y": fy - 90, "vx": f.face * (6 + Math.random() * 5), "vy": -3 - Math.random() * 4, "own": f, "tgt": e, "ch": rnd(["Q", "W", "E", "R", "A", "S", "D", "Z", "Ё", "Й"]), "life": 70, "mv": { "id": "spray", "dm": 0.35, "kb": 0.3, "w": tl(["клац!", "тык!"], ["clack!", "tap!"]) } }); break;
        case "beam":
            if (t > 8) for (let i = 0; i < 2; i++) { const a = Math.random() * 6.3; sm.parts.push({ "x": f.x + f.face * 40 + Math.cos(a) * 40, "y": fy - 80 + Math.sin(a) * 40, "vx": -Math.cos(a) * 3, "vy": -Math.sin(a) * 3, "g": 0, "life": 12, "c": rnd(["#ff4f6d", String(cAccent), "#ffffff"]), "s": 4 }); }
            if (at(8)) { sm.beams.push({ "x1": f.x + f.face * 50, "x2": e.x, "y": fy - f.y - 80, "life": 8, "w": 14 }); if (dist < 330) hit(f, e, mv, false); }
            break;
        case "eyeblast":
            if (at(6)) { const y = fy - f.y - 64 - 30; sm.beams.push({ "x1": f.x + f.face * 10, "x2": e.x, "y": y - 6, "life": 7, "w": 6 }); sm.beams.push({ "x1": f.x + f.face * 10, "x2": e.x, "y": y + 6, "life": 7, "w": 6 }); if (dist < 330) hit(f, e, mv, false); }
            break;
        case "super":
            if (t > 12) {
                sm.vig = Math.max(sm.vig, 0.7);
                if (Math.floor(t * 2) % 2 === 0) for (let i = 0; i < 3; i++) { const an = Math.random() * 6.3; sm.parts.push({ "x": f.x + Math.cos(an) * 58, "y": fy - f.y - 60 + Math.sin(an) * 58, "vx": -Math.cos(an) * 3.6, "vy": -Math.sin(an) * 3.6, "g": 0, "life": 15, "c": rnd(["#ffd34d", "#fff2a8", "#ffffff", String(cAccent2)]), "s": 4 }); }
            }
            for (let i = 0; i < mv.nh; i++) if (at(12 - i * 3)) superStrike(f, e, i, mv);
            break;
        case "eat":
            if (at(8)) { f.hp = Math.min(100, f.hp + 7); g.hpA = sm.f[0].hp; g.hpB = sm.f[1].hp; floatText(f.x, fy - 140, tl("+7 *хрум*", "+7 *crunch*"), String(cOk), false); sparks(f.x + f.face * 10, fy - f.y - 80, 10, false, null, ["#e0b060", "#8a5a2b"]); }
            break;
        }
    }

    // ── physics
    function physics(f, dt) {
        f.x += f.vx * dt;
        if (f.y > 0 || f.vy !== 0) {
            f.vy -= 1.1 * dt;
            f.y += f.vy * dt;
            if (f.y <= 0) { if (f.vy < -7) { dust(f.x, 8); f.squash = 6; } f.y = 0; f.vy = 0; }
        }
        if (f.y === 0 && f.st !== "dash" && f.st !== "walk" && f.st !== "fetch" && f.st !== "flee") f.vx *= Math.pow(0.8, dt);
        if (f.st !== "enter") {
            if (f.x < ropeL) { f.x = ropeL; if (Math.abs(f.vx) > 3) { sm.ropeW[0] = Math.min(14, Math.abs(f.vx)); f.vx = Math.abs(f.vx) * 0.75; } else f.vx = 0; }
            if (f.x > ropeR) { f.x = ropeR; if (Math.abs(f.vx) > 3) { sm.ropeW[1] = Math.min(14, Math.abs(f.vx)); f.vx = -Math.abs(f.vx) * 0.75; } else f.vx = 0; }
        }
        if (f.squash > 0) f.squash -= dt;
        if (f.flash > 0) f.flash -= dt;
        if (f.bflash > 0) f.bflash -= dt;
        if (f.spd > 0) f.spd -= dt;
        if (f.blkCd > 0) f.blkCd -= dt;
        if (f.st !== "block" && f.gd < 100) f.gd = Math.min(100, f.gd + 0.8 * dt);
        if (f.st === "dash" || Math.abs(f.vx) > 8 || (f.spd > 0 && Math.abs(f.vx) > 2)) { f.trail.unshift({ "x": f.x, "y": f.y }); if (f.trail.length > (f.spd > 0 ? 6 : 4)) f.trail.pop(); }
        else if (f.trail.length) f.trail.pop();
    }
    function brain(f, e, dt) {
        const dx = e.x - f.x, dist = Math.abs(dx);
        if (f.st !== "ko" && f.st !== "win" && f.y === 0 && f.st !== "jatk") f.face = dx >= 0 ? 1 : -1;
        f.t -= dt;
        if (f.stun > 0 && f.st !== "ko") { f.stun -= dt; if (f.st !== "hurt") f.st = "idle"; return; }
        const wp = f.wep;
        switch (f.st) {
        case "idle": {
            f.cd -= dt;
            if (sm.items.length) { const bb = bombNear(f); if (bb && f.fled !== bb.id) { f.fled = bb.id; if (Math.random() < 0.85) { f.st = "flee"; f.bomb = bb; break; } } }
            if (g.shieldOn && tryBlock(f, e, dist, dt)) break;
            if (g.superOn && f.sp >= 100 && f.cd <= 0 && !f.noWep) {
                const smv = f.superMv || (f.superMv = superOf(wp));
                if ((!smv.lunge || dist < 430) && Math.random() < 0.5) { startMove(f, smv); break; }
            }
            if (f.cd <= 0 && sm.items.length) { const it = pickTarget(f, e); if (it) { f.st = "fetch"; f.tgt = it; f.fetchT = 0; break; } }
            const mr = Math.min(wp.range, 104);                     // melee reach (mic/laser too: bonk / butt bash)
            if (f.cd > 0) { if (dist > mr + 40 && Math.random() < 0.04 * dt) f.st = "dash"; break; }
            const stall = sm.frame - (sm.lastDmg || 0) > 90;
            const ok = m => !(m.k === "eat" && f.hp > 85) && !(m.k === "throw" && f.noWep);
            let mel = wp.moves.filter(m => !m.r && ok(m) && (m.k === "eat" || dist <= mr - 8));
            const rng = wp.moves.filter(m => m.r && ok(m) && dist <= m.r - 8);
            // ranged: never twice in a row, >= 2.5 s apart, mostly at long distance
            const rOk = rng.length && !f.lastRanged && sm.frame - (f.rT || -999) >= 75 && !stall;
            const rWant = dist > 170 ? 0.7 : dist > mr ? 0.45 : 0.28;
            let cand;
            if (rOk && Math.random() < rWant) cand = rng;
            else if (mel.length) cand = mel;
            else { f.st = "dash"; f.forced = stall; break; }
            if (f.rep >= 2 && cand.length > 1) cand = cand.filter(m => m.id !== f.lastMv);
            if (cand === mel && Math.random() < 0.14 && dist < mr && f.hp > 0) { f.st = "jatk"; f.atkN++; f.vy = 13; f.vx = f.face * Math.min(7, dist / 8 + 2); f.hitDone = false; f.mv = { "id": "jump", "n": tl("прыжок", "jump") }; f.lastRanged = false; sm.mvStat.m++; break; }
            const pick = rnd(cand);
            f.rep = pick.id === f.lastMv ? (f.rep || 0) + 1 : 1; f.lastMv = pick.id;
            if (pick.r) { f.lastRanged = true; f.rT = sm.frame; sm.mvStat.r++; } else { f.lastRanged = false; if (pick.k !== "eat") sm.mvStat.m++; }
            g.moveStat = sm.mvStat.m + "/" + sm.mvStat.r;
            startMove(f, pick);
            break;
        }
        case "block":
            f.blkAge += dt;
            if (f.t <= 0) { f.st = "idle"; f.cd = 3 + Math.random() * 6; f.blkCd = 34 + Math.random() * 30; }
            break;
        case "fetch": {
            const it = f.tgt;
            if (!it || sm.items.indexOf(it) < 0 || (it.st !== "ready" && !(it.k === "bomb" && it.st === "fuse" && it.fuse > 28 && !it.thrown))) { f.st = "idle"; f.cd = 2; break; }
            f.fetchT += dt;
            const d = it.x - f.x;
            f.face = d >= 0 ? 1 : -1;
            f.vx = f.face * (f.spd > 0 ? 10 : 7);
            if (Math.abs(d) < 12) { f.st = "idle"; f.cd = 2; }
            else if (f.fetchT > 130) { f.st = "idle"; f.cd = 4; sm.st.pk.giveUp++; }
            break;
        }
        case "flee": {
            const b = f.bomb;
            if (!b || b.st !== "fuse" || Math.abs(f.x - b.x) > 150) { f.st = "idle"; f.cd = 3; break; }
            const away = f.x >= b.x ? 1 : -1;
            f.vx = away * (f.spd > 0 ? 13 : 10);
            if (f.y === 0 && ((away > 0 && f.x > ropeR - 14) || (away < 0 && f.x < ropeL + 14))) { f.vy = 14; f.vx = -away * 9; }    // cornered: jump over the bomb
            break;
        }
        case "dash":
            f.vx = f.face * (f.spd > 0 ? 14 : 9);
            if (dist <= Math.min(70, Math.min(wp.range, 104) - 24) || (f.forced && dist <= Math.min(wp.range, 104) - 20)) { f.forced = false; f.st = "idle"; f.cd = 3 + Math.random() * 6; dust(f.x - f.face * 20, 3); }
            break;
        case "atk":
            moveTick(f, e, dist);
            if (f.t <= 0) { f.st = "idle"; f.cd = (14 + Math.random() * 22) * wp.cd; }
            break;
        case "jatk":
            if (!f.hitDone && f.vy < 0 && dist < 80 && f.y < 50) { f.hitDone = true; hit(f, e, f.mv, true); }
            if (f.y === 0 && f.vy === 0) { f.st = "idle"; f.cd = (16 + Math.random() * 20) * wp.cd; }
            break;
        case "hurt":
            if (f.t <= 0 && f.y === 0) { f.st = "idle"; f.cd = 6 + Math.random() * 10; }
            break;
        }
    }
    function walkTo(f, x, dt) {
        const d = x - f.x;
        if (Math.abs(d) < 5) { f.x = x; f.vx = 0; return true; }
        f.st = "walk"; f.face = d > 0 ? 1 : -1; f.vx = f.face * 5;
        return false;
    }

    // ── rounds
    function startCard(n) {
        g.sfx("sting", 0.6);
        sm.phase = "card"; sm.phT = 0; sm.round = n; sm.cardX = 200; sm.cardHold = 0;
        g.round = n; g.banner = ""; g.sayL = ""; g.sayR = "";
        for (const f of sm.f) if (f.st !== "enter") { f.st = "idle"; f.sit = false; f.noWep = false; }
        comment(rnd(tl(["Раунд " + n + "! Встречайте нашу прекрасную помощницу!", "Раунд " + n + "! Табличку уже несут!", "Раунд " + n + "! Ставки сделаны, ставок больше нет!"], ["Round " + n + "! Please welcome our lovely ring card girl!", "Round " + n + "! Here comes the card!", "Round " + n + "! Bets are in, no more bets!"])), true);
    }
    function endRound() {
        const d0 = sm.dmg[0], d1 = sm.dmg[1];
        let s0 = 10, s1 = 10;
        if (Math.abs(d0 - d1) >= 3) { if (d0 > d1) s1 = d0 - d1 >= 25 ? 8 : 9; else s0 = d1 - d0 >= 25 ? 8 : 9; }
        sm.scores[0] += s0; sm.scores[1] += s1;
        g.scoreTxt = sm.scores[0] + " : " + sm.scores[1];
        g.sfx("gong", 0.7);
        sm.dmg = [0, 0];
        for (const q of sm.proj) if (q.own) q.own.noWep = false;
        sm.proj = []; sm.beams = [];
        const who = s0 > s1 ? sm.f[0].who.name : s1 > s0 ? sm.f[1].who.name : "";
        comment(tl("Гонг! Конец раунда " + sm.round + ". Судьи: " + s0 + "–" + s1 + (who ? " в пользу " + who : ", поровну") + "!", "Gong! End of round " + sm.round + ". Judges: " + s0 + "–" + s1 + (who ? " for " + who : ", even") + "!"), true);
        const last = g.rounds > 0 ? sm.round >= g.rounds : sm.round >= 8;
        sm.rw = last ? -1 : s0 > s1 ? 0 : s1 > s0 ? 1 : -1;
        sm.phT = 0;
        sm.phase = last ? "decision" : "break";
        for (const f of sm.f) if (f.st !== "ko") { f.st = "idle"; f.stun = 0; }
        if (sm.rw >= 0) { sm.f[sm.rw].st = "win"; sm.f[sm.rw].vx = 0; sm.cam = 12; floatText(sm.f[sm.rw].x, fy - 175, "★", "#ffd34d", true, 0, -0.6); }
        if (!last)
            sm.rec = sm.f.map(f => ({ "from": f.hp, "to": Math.min(100, f.hp + (6 + 0.25 * (100 - f.hp)) * (g.rounds === 0 ? Math.max(0, 1 - 0.4 * (sm.round - 1)) : 1)) }));
    }
    function stepRoundFlow(dt) {
        const A = sm.f[0], B = sm.f[1];
        sm.phT += dt;
        if (sm.phase === "intro") {
            for (const f of sm.f)
                if (f.st === "enter") {
                    f.x += f.vx * dt; f.vy -= 1.1 * dt; f.y += f.vy * dt;
                    if (f.y <= 0 && f.vy < 0) { f.y = 0; f.vy = 0; f.vx = 0; f.st = "idle"; f.squash = 6; dust(f.x, 10); sm.hype = 0.8; }
                }
            if (sm.phT > 4 && sm.phT - dt <= 4 && g.tourStage) comment(tl("Турнир! " + g.tourStage + "! Матч " + g.tourMatchNo + ".", "Tournament! " + g.tourStage + "! Match " + g.tourMatchNo + "."), true);
            if (sm.phT > 40 && sm.phT - dt <= 40) comment(tl("В синем углу — " + A.who.name + " с оружием «" + A.wep.name + "»!", "In the blue corner — " + A.who.name + " with the " + A.wep.name + "!"), true);
            if (sm.phT > 100 && sm.phT - dt <= 100) comment(tl("В красном — " + B.who.name + " с оружием «" + B.wep.name + "»! " + (g.rounds ? g.rounds + " раунд" + (g.rounds === 1 ? "" : g.rounds < 5 ? "а" : "ов") : "До нокаута") + "!", "In the red corner — " + B.who.name + " with the " + B.wep.name + "! " + (g.rounds ? g.rounds + " round" + (g.rounds === 1 ? "" : "s") : "To the knockout") + "!"), true);
            if (sm.phT > 165 && A.st === "idle" && B.st === "idle") startCard(1);
        } else if (sm.phase === "card") {
            if (Math.abs(sm.cardX - 450) < 4 && sm.cardHold < 32) sm.cardHold += dt;
            else sm.cardX += 7 * dt;
            for (const f of sm.f) physics(f, dt);
            if (sm.cardX > 700) {
                sm.phase = "fight"; sm.phT = 0; sm.roundT = roundFr; sm.itemT = itemGap() * 0.55; g.banner = "FIGHT!"; g.sfx("bell", 0.8); sm.lastDmg = sm.frame;
                for (const f of sm.f) { f.st = "idle"; f.cd = 10 + Math.random() * 15; }
            }
        } else if (sm.phase === "fight") {
            if (sm.phT > 30 && g.banner === "FIGHT!") g.banner = "";
            sm.roundT -= dt;
            sm.fightT += dt; sm.maxStall = Math.max(sm.maxStall, sm.frame - (sm.lastDmg || 0));
            brain(A, B, dt * (A.spd > 0 ? 1.35 : 1)); brain(B, A, dt * (B.spd > 0 ? 1.35 : 1));
            for (const f of sm.f) { f.mvT = (f.st === "dash" || f.st === "fetch") ? f.mvT + dt : 0; if (f.mvT > sm.st.maxMv) sm.st.maxMv = f.mvT; }
            for (const f of sm.f) physics(f, dt);
            const d = B.x - A.x;
            if (sm.phase === "fight" && Math.abs(d) < 40 && A.y < 30 && B.y < 30) { const push = (40 - Math.abs(d)) / 2 * (d >= 0 ? 1 : -1); A.x -= push; B.x += push; }
            if (sm.phase === "fight" && sm.roundT <= 0) endRound();
        } else if (sm.phase === "break") {
            const corners = [ropeL + 12, ropeR - 12];
            for (const f of sm.f) {
                if (sm.phT < 45) { if (f.st === "walk") f.st = "idle"; f.vx = 0; }
                else if (!f.sit) { if (f.y === 0 && walkTo(f, corners[f.side], dt)) { f.sit = true; f.st = "sit"; f.face = f.side === 0 ? 1 : -1; } }
                physics(f, dt);
            }
            const tr = [pl - 22, pr + 22];
            sm.trX = sm.trX.map((x, i) => x + (tr[i] - x) * 0.1);
            if (sm.rec && sm.phT > 40 && sm.phT < 130) {
                const k = (sm.phT - 40) / 90;
                sm.f.forEach((f, i) => f.hp = sm.rec[i].from + (sm.rec[i].to - sm.rec[i].from) * k);
                g.hpA = A.hp; g.hpB = B.hp;
            }
            const adv = tl(["Работай джебом!", "Он открыт слева!", "Дыши, брат, дыши!", "Ты лучший в этом войсе!", "Не забывай про блок!", "Мама смотрит стрим!", "Бей, пока он в AFK!", "Меньше кринжа, больше урона!"], ["Work the jab!", "He's open on the left!", "Breathe, bro, breathe!", "You're the best in this voice chat!", "Don't forget to block!", "Mom's watching the stream!", "Hit them while they're AFK!", "Less cringe, more damage!"]);
            if (sm.phT > 30 && sm.phT - dt <= 30) { g.sayL = rnd(adv.concat([tl("Маши " + A.wep.ins + " смелее!", "Swing harder " + A.wep.ins + "!")])); for (const f of sm.f) splash(f.x + (f.side === 0 ? -6 : 6), fy - 110); }
            if (sm.phT > 95 && sm.phT - dt <= 95) g.sayR = rnd(adv.concat([tl("Маши " + B.wep.ins + " смелее!", "Swing harder " + B.wep.ins + "!")]));
            if (sm.phT > (g.rounds === 0 ? 175 : 195)) { sm.trX = [112, 788]; startCard(sm.round + 1); }
        } else if (sm.phase === "decision") {
            for (const f of sm.f) physics(f, dt);
            if (sm.phT > 70 && !sm.winner) {
                const wi = sm.scores[0] > sm.scores[1] ? 0 : sm.scores[1] > sm.scores[0] ? 1 : (A.hp >= B.hp ? 0 : 1);
                sm.winner = sm.f[wi]; sm.loser = sm.f[1 - wi];
                const tie = sm.scores[0] === sm.scores[1];
                g.banner = tl("ПО ОЧКАМ", "ON POINTS"); g.finText = sm.scores[0] + " : " + sm.scores[1];
                comment(tl((tie ? "Ничья по очкам! По остатку HP " : "Решением судей " + Math.max(sm.scores[0], sm.scores[1]) + "–" + Math.min(sm.scores[0], sm.scores[1]) + " ") + "побеждает " + sm.winner.who.name + "!", (tie ? "A draw on points! On remaining HP " : "By the judges' decision " + Math.max(sm.scores[0], sm.scores[1]) + "–" + Math.min(sm.scores[0], sm.scores[1]) + " ") + "the winner is " + sm.winner.who.name + "!"), true);
            }
            if (sm.phT > 110) toWin();
        } else if (sm.phase === "ko") {
            for (const f of sm.f) physics(f, dt);
            if (sm.slowT <= 0 && sm.phT > 40 && sm.loser.y === 0 && Math.abs(sm.loser.vx) < 1) toWin();
        } else if (sm.phase === "win") {
            const w = sm.winner, l = sm.loser, P = sm.pod, ph = 64;
            sm.endT += dt;
            P.rise = Math.min(1, P.rise + dt / 28);
            if (P.st === 0) {
                physics(w, dt);
                const side = w.x < 450 ? 375 : 525;
                if (P.rise >= 1 && w.y === 0 && walkTo(w, side, dt)) { P.st = 1; P.jt = 0; P.x0 = w.x; w.st = "jump"; dust(w.x, 8); }
            } else if (P.st === 1) {
                P.jt += dt; const t = Math.min(1, P.jt / 16);
                w.x = P.x0 + (450 - P.x0) * t; w.y = ph * t + 70 * Math.sin(Math.PI * t); w.vy = 0; w.vx = 0;
                if (t >= 1) { P.st = 2; P.t2 = 0; w.y = ph; w.st = "win"; w.squash = 5; w.face = l.x > 450 ? 1 : -1; dust(450, 12); confetti(); sm.cam = 60; sm.hype = 1; sm.punch = 0.12; g.sfx("fanfare", 0.8); g.sfx("cheer", 0.7); comment(g.tourFinal ? w.who.name + tl(" — ЧЕМПИОН ТУРНИРА! На пьедестал!", " — TOURNAMENT CHAMPION! To the podium!") : w.who.name + tl(" на пьедестале! Пояс чемпиона войса!", " takes the podium! Voice chat champion belt!"), true); }
            } else {
                P.t2 += dt; w.y = ph; w.vx = 0; w.st = "win";
                if (Math.floor(P.t2 / 30) !== Math.floor((P.t2 - dt) / 30)) { sm.cam = 20; for (let i = 0; i < 26; i++) sm.parts.push({ "x": 450 + (Math.random() - 0.5) * 60, "y": fy - ph - 120, "vx": (Math.random() - 0.5) * 7, "vy": -3 - Math.random() * 4, "g": 0.18, "life": 70, "c": rnd(["#ffd34d", String(cAccent), String(cAccent2), "#ffffff"]), "s": 4 }); }
            }
            if (!l.sit) {
                if (l.st === "ko" && sm.phT > 45) { l.st = "idle"; l.squash = 3; }
                if (l.st !== "ko" && l.y === 0 && walkTo(l, l.x > 450 ? 640 : 260, dt)) { l.sit = true; l.st = "sit"; l.face = l.x > 450 ? -1 : 1; }
                physics(l, dt);
            }
            if (sm.endT > (g.tourOn && !g.tourFinal ? 170 : 290) && !fadeOut.running) fadeOut.start();
        }
    }
    function toWin() {
        console.info("crew-fight moves " + sm.f[0].wep.id + " vs " + sm.f[1].wep.id + ": melee " + sm.mvStat.m + ", ranged " + sm.mvStat.r);
        sm.phase = "win"; sm.phT = 0; sm.endT = 1; sm.pod = { "rise": 0, "st": 0, "jt": 0, "x0": 0, "t2": 0 };
        g.lastResult = JSON.stringify({ "fight": Math.round(sm.fightT / 3) / 10, "ko": !!sm.byKO, "win": sm.winner.side, "rounds": g.rounds, "wep": [sm.f[0].wep.id, sm.f[1].wep.id],
                                        "hp": [Math.round(sm.f[0].hp), Math.round(sm.f[1].hp)], "stall": Math.round(sm.maxStall / 3) / 10, "mv": Math.round(sm.st.maxMv / 3) / 10, "st": sm.st });
        sm.winner.st = "win"; sm.winner.sit = false;
        if (sm.loser.st !== "ko") sm.loser.st = "idle";
        g.banner = g.tourFinal ? "TOURNAMENT CHAMPION" : sm.winner.who.name + " WINS";
        g.matchWinner = sm.winner.side;
        g.caption = rnd(g.endings).replace("%WI", sm.winner.wep.ins).replace("%WN", sm.winner.wep.name).replace("%W", sm.winner.who.name).replace("%L", sm.loser.who.name)
            + (sm.byKO ? "" : tl(" (по очкам ", " (on points ") + sm.scores[sm.winner.side] + "–" + sm.scores[sm.loser.side] + ")");
        if (g.tourFinal) comment(tl("Дамы и господа! Чемпион турнира — " + sm.winner.who.name + "!!! Пояс уезжает домой!", "Ladies and gentlemen! Your tournament champion — " + sm.winner.who.name + "!!! The belt goes home!"), true);
        else if (!sm.byKO) comment(tl("Итак, победитель по очкам — " + sm.winner.who.name + "! Поаплодируем проигравшему, он старался!", "And the winner on points is " + sm.winner.who.name + "! A round of applause for the loser, they tried!"), true);
    }

    function step(dt) {
        sm.dt = dt;
        sm.frame += dt;
        if (g.dbgCharge) { g.dbgCharge = false; for (const f of sm.f) f.sp = 100; }
        stepRoundFlow(dt);
        stepItems(dt);
        g.phase = sm.phase;
        { const q0 = sm.f[0], q1 = sm.f[1]; g.spA = Math.round(q0.sp); g.spB = Math.round(q1.sp); g.gdA = Math.max(0, Math.min(100, Math.round(q0.gd))); g.gdB = Math.max(0, Math.min(100, Math.round(q1.gd))); g.sdA = q0.blkCd <= 0 && q0.gd >= 30; g.sdB = q1.blkCd <= 0 && q1.gd >= 30; }
        const sec = Math.max(0, Math.ceil(sm.roundT / 30));
        g.timerTxt = sm.phase === "fight" ? "0:" + (sec < 10 ? "0" : "") + sec : "";
        sm.proj = sm.proj.filter(q => {
            const tg = q.tgt;
            if (q.k === "mic") {
                q.vy += 0.9 * dt; q.y += q.vy * dt;
                if (q.y >= fy - 10) { sm.rings.push({ "x": q.x, "y": fy - 4, "r": 4, "life": 24 }); sm.shake = 14; dust(q.x, 14); floatText(q.x, fy - 140, tl("*БУМ*", "*BOOM*"), "#ffffff", true); return false; }
                return true;
            }
            q.life -= dt;
            if (q.k === "key") { q.vy += 0.25 * dt; q.y += q.vy * dt; }
            if (q.k === "throw") {
                q.rot += 0.5 * dt;
                if (q.back) { const d = q.own.x - q.x; q.x += Math.sign(d) * 12 * dt; if (Math.abs(d) < 20 || q.life <= -60) { q.own.noWep = false; return false; } return true; }
            }
            const ox = q.x;
            q.x += q.vx * dt;
            const crossed = (ox - tg.x) * (q.x - tg.x) <= 0;
            const near = crossed || Math.abs(q.x - tg.x) < (q.k === "wave" ? 26 * q.size : 28);
            const yOk = q.k === "flop" ? tg.y < 30 : q.k === "key" ? (q.y > fy - tg.y - 115 && q.y < fy - tg.y + 6) : tg.y < 80;
            if (near && yOk) {
                hit(q.own, tg, q.k === "flop" ? Object.assign({ "stun": 1 }, q.mv) : q.mv, false);
                if (q.k === "throw") { q.back = true; return true; }
                return false;
            }
            if (q.k === "throw" && (q.life <= 0 || q.x < 40 || q.x > ww - 40)) { q.back = true; return true; }
            if (q.k === "key" && q.y > fy) return false;
            return q.life > 0 && q.x > 40 && q.x < ww - 40;
        });
        sm.beams = sm.beams.filter(bm => { bm.life -= dt; return bm.life > 0; });
        sm.rings = sm.rings.filter(r => { r.r += 9 * dt; r.life -= dt; return r.life > 0; });
        const ps = [];
        for (const p of sm.parts) {
            p.vy += p.g * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt;
            if (p.wob !== undefined) p.x += Math.sin((sm.frame + p.wob * 10) / 6) * 0.8;
            if (p.bmp) p.rot += 0.2 * dt;
            if (p.life > 0 && p.y < 580) ps.push(p);
        }
        if (ps.length > 220) ps.splice(0, ps.length - 220);
        sm.parts = ps;
        sm.floats = sm.floats.filter(t => { t.x += t.vx * dt; t.y += t.vy * dt; if (t.vy > -1.1) t.vy -= 0.15 * dt; t.life -= dt; return t.life > 0; });
        sm.ropeW = sm.ropeW.map(w => w * Math.pow(0.86, dt));
        sm.hype = Math.max(0, sm.hype - 0.01 * dt);
        if (sm.shake > 0) sm.shake -= dt;
        if (sm.flash > 0) sm.flash -= dt;
        if (sm.scan > 0) sm.scan -= dt;
        if (sm.cam > 0) sm.cam -= dt;
        if (sm.phase === "win") sm.hype = Math.max(sm.hype, 0.8);
        if (sm.maxBeam > 0) sm.maxBeam -= dt;
        if (sm.sayCd > 0) sm.sayCd -= dt;
        if (g.sayT > 0) g.sayT -= dt;
        for (const f of sm.f) if (f.fade) f.alpha = Math.max(0.25, f.alpha - 0.02 * dt);
        const zt = sm.phase === "ko" ? 1.5 : 1;
        // virtual camera: follow the fighters' midpoint, zoom in when they are close, punch toward
        // impacts, dramatic zoom on the KO; clamped so the view never leaves the hall
        const A0 = sm.f[0], B0 = sm.f[1], H0 = 560;
        let tz = 1, tx = ww / 2, ty = H0 / 2;
        if (sm.phase === "fight") {
            const d = Math.abs(A0.x - B0.x);
            tz = Math.max(1, Math.min(1.22, 1.32 - d / 650));
            tx = (A0.x + B0.x) / 2;
            ty = H0 / 2 + (fy - 120 - H0 / 2) * ((tz - 1) / 0.3);
        } else if (sm.phase === "win" && sm.pod) {
            tz = 1.12; tx = 450; ty = fy - 150;
        } else if (sm.phase === "ko" && sm.loser) {
            tz = 1.6; tx = sm.loser.x; ty = fy - 90 - sm.loser.y * 0.5;
        }
        tz += sm.punch;
        if (sm.punch > 0.001) { tx += (sm.px - tx) * 0.5; ty += (sm.py - ty) * 0.4; }
        sm.punch *= Math.pow(0.78, dt);
        sm.camZ += (tz - sm.camZ) * 0.2;
        sm.camX += (tx - sm.camX) * 0.15;
        sm.camY += (ty - sm.camY) * 0.15;
        const hw = ww / (2 * sm.camZ), hh = H0 / (2 * sm.camZ);
        sm.camX = Math.max(hw, Math.min(ww - hw, sm.camX));
        sm.camY = Math.max(hh, Math.min(H0 - hh, sm.camY));
        if (sm.vig > 0) sm.vig -= 0.06 * dt;
    }

    // ── vsync driver (FrameAnimation): sim in 30-fps units, scaled by the real frame time
    property real paintAcc: 1
    property real crowdAcc: 1
    property int ecoN: 0
    // the GPU crowd unless it failed to compile/load or the user turned it off
    readonly property bool shaderOk: g.crowdShader && crowdFx.status !== ShaderEffect.Error
    onShaderOkChanged: if (!shaderOk) console.warn("crew-fight: crowd shader unavailable (" + crowdFx.log + "), using the canvas crowd")
    property real flashO: 0
    property color flashC: "#ffffff"
    property real scanO: 0
    property real vigO: 0
    property string jName: ""
    property string jScore: ""
    property string jRound: ""
    // perf: frame time and paint time stats over the fight
    property var perf: ({ "n": 0, "sum": 0, "max": 0, "slow": 0, "pn": 0, "psum": 0, "pmax": 0, "t0": 0 })
    function perfTick(ft) {
        const P = perf;
        P.n++; P.sum += ft; if (ft > P.max) P.max = ft; if (ft > 0.034) P.slow++;
        if (!P.t0) P.t0 = Date.now();
        if (Date.now() - P.t0 > 1000) {
            g.perf = "fps " + (P.n / ((Date.now() - P.t0) / 1000)).toFixed(0) + ", frame avg " + (P.sum / P.n * 1000).toFixed(1) + " ms / max " + (P.max * 1000).toFixed(0)
                + " ms, >34ms: " + P.slow + ", paint avg " + (P.pn ? (P.psum / P.pn).toFixed(1) : "-") + " / max " + P.pmax + " ms, parts " + (sm ? sm.parts.length : 0);
            if (sm && sm.phase === "fight") console.info("crew-fight perf: " + g.perf);
            perf = { "n": 0, "sum": 0, "max": 0, "slow": 0, "pn": 0, "psum": 0, "pmax": 0, "t0": Date.now() };
        }
    }
    // repaint only the layers whose content changes; everything is positioned on the GPU
    function upd(cv, act) { if (act || cv.was) cv.requestPaint(); cv.was = act; }
    // everything the fighter sprite depends on (its position is a GPU translate, not a repaint)
    function fKey(f, fr) {
        const st = f.st, mv = st === "atk" || st === "jatk" || st === "hurt";
        return st + "|" + f.face + "|" + Math.round(f.squash > 0 ? f.squash * 2 : 0) + "|" + (f.flash > 0 ? Math.floor(f.flash) % 2 : -1)
            + "|" + (f.fade ? Math.floor(fr / 2) % 2 + ":" + f.alpha : "") + "|" + (mv && f.mv ? f.mv.id + ":" + Math.round(f.t * 2) : "")
            + "|" + (f.noWep ? 1 : 0) + "|" + ((st === "dash" || st === "walk") ? Math.floor(fr / 3) % 2 : "")
            + "|" + (st === "ko" ? (f.y === 0 && Math.abs(f.vx) < 2 ? "L" : Math.round(fr % 40)) : "") + "|" + (st === "jatk" ? (f.vy > 0 ? 1 : 0) + ":" + (f.vy < 0 ? 1 : 0) : "")
            + "|" + (f.stun > 0 ? Math.round(fr * 2) : "") + "|" + (f.x % 1 >= 0.5 ? 1 : 0) + (f.y % 1 >= 0.5 ? 1 : 0) + "|" + f.wep.id + "|" + (f.st === "win" ? Math.round(fr) : "")
            + "|" + (st === "block" ? Math.floor(fr / 3) % 2 : "") + (f.bflash > 0 ? "b" + Math.floor(f.bflash) : "")
            + "|" + (g.superOn && f.sp >= 100 ? Math.floor(fr / 5) % 2 : "") + "|" + (f.spd > 0 ? Math.floor(fr / 3) % 2 : "");
    }
    function paintLayers() {
        const s = sm, fr = s.frame;
        crowdFx.fr = fr; crowdFx.hype = s.hype;
        if (!shaderOk) { crowdAcc += 1; if (crowdAcc >= (g.eco ? 2 : 3)) { crowdAcc = 0; crowdCv.requestPaint(); } }
        if (Math.abs(g.crowdLvl - s.hype) > 0.08) g.crowdLvl = s.hype; crowdFx.cam = s.cam > 0 ? 1 : 0;
        smokeLayer.fr = fr; smokeLayer.boost = s.phase === "intro" || s.phase === "ko";
        for (let i = 0; i < 2; i++) {
            const f = s.f[i], cv = i === 0 ? fCv0 : fCv1;
            cv.x = Math.round(f.x) - 160; cv.y = Math.round(fy - f.y) - 250;
            const k = fKey(f, fr);
            if (k !== cv.key) { cv.key = k; cv.requestPaint(); }
        }
        for (let i = 0; i < 3; i++) {
            const it = s.items.find(q => q.slot === i), cv = itemRep.itemAt(i);
            if (!cv) continue;
            if (!it) { cv.visible = false; continue; }
            const bob = it.st === "ready" && it.k !== "bomb" ? 3 + Math.sin(fr / 6) * 3 : 0;
            cv.x = Math.round(it.x) - 130; cv.y = Math.round(fy - it.y - bob) - 84;
            const fl = it.st === "ready" && it.life < 90 ? Math.floor(fr / 3) % 2 : 0;
            cv.visible = !fl;
            const key = it.k + "|" + it.st + "|" + (it.st === "fuse" ? Math.floor(it.fuse / (it.fuse > 30 ? 6 : 3)) % 2 : "") + "|" + (it.st === "fly" ? Math.floor(fr / 2) % 4 : "");
            if (key !== cv.key) { cv.key = key; cv.requestPaint(); }
        }
        const wob = Math.abs(s.ropeW[0]) + Math.abs(s.ropeW[1]) > 0.05;
        upd(ropeBack, wob); upd(ropeFront, wob);
        const br = s.phase === "break";
        const tk = Math.round(s.trX[0]) + "," + Math.round(s.trX[1]) + (br && (s.f[0].sit || s.f[1].sit) ? "," + fr : "");
        if (tk !== trCv.key) { trCv.key = tk; trCv.requestPaint(); }
        const glow = br && s.rw >= 0 && s.phT < 45, pod = s.phase === "win" && !!s.pod;
        upd(backCv, glow || pod || s.f[0].trail.length > 0 || s.f[1].trail.length > 0);
        upd(frontCv, glow || pod || s.phase === "card");
        const talk = g.sayT > 0 && Math.floor(fr / 3) % 2 === 0;
        if (talk !== annCv.talk) { annCv.talk = talk; annCv.requestPaint(); }
        upd(canvas, s.parts.length > 0 || s.proj.length > 0 || s.beams.length > 0 || s.rings.length > 0 || s.floats.length > 0 || s.maxBeam > 0);
    }
    function applyCam() {
        const s = sm;
        let shx = 0, shy = 0;
        if (s.shake > 0) { const o = Math.sin(s.frame * 2.7) * s.shake; shx = s.sdx * o + (Math.random() - 0.5) * s.shake * 0.3; shy = s.sdy * o; }
        world.scale = s.camZ;
        world.x = Math.round(450 - s.camZ * (s.camX - shx));
        world.y = Math.round(280 - s.camZ * (s.camY - shy));
        flashO = s.flash > 0 ? Math.min(0.85, s.flash / 8) : 0;
        flashC = s.flash > 0 ? s.flashC : "#ffffff"; if (s.flash <= 0) s.flashC = "#ffffff";
        scanO = s.scan > 0 ? 1 : 0;
        vigO = Math.max(0, Math.min(1, s.vig));
        const nm = n => (String(n).length > 10 ? String(n).slice(0, 9) + "…" : String(n));
        jName = nm(s.f[0].who.name) + "  VS  " + nm(s.f[1].who.name);
        const live = s.phase === "fight" ? (Math.floor(s.frame / 15) % 2 ? "● LIVE" : "○ LIVE") : s.phase === "break" ? tl("ПЕРЕРЫВ", "BREAK") : s.phase === "ko" || s.phase === "win" ? (s.byKO ? "K.O.!" : tl("ПОБЕДА", "VICTORY")) : "SHOWTIME";
        jScore = g.scoreTxt + "   " + live;
        jRound = tl("РАУНД ", "ROUND ") + Math.max(1, s.round) + (g.rounds ? "/" + g.rounds : "") + (g.timerTxt ? "  ·  " + g.timerTxt : "");
    }
    // test helper: grab the arena item itself (never the screen) when an event fires: IPC snap <events|all> <dir>
    property var snapN: ({})
    property var snapQ: []
    function snapEv(ev, delay) {
        if (!g.snapDir || (g.snapEv !== "all" && ("," + g.snapEv + ",").indexOf("," + ev + ",") < 0)) return;
        const n = snapN[ev] || 0;
        if (n >= 3) return;
        snapN[ev] = n + 1;
        snapQ = snapQ.concat([{ "at": Date.now() + (delay || 100), "path": g.snapDir + "/" + ev + "-" + (n + 1) + ".png" }]);
    }
    Timer {
        interval: 25; repeat: true; running: ar.snapQ.length > 0
        onTriggered: {
            const due = ar.snapQ.filter(q => q.at <= Date.now());
            if (!due.length) return;
            ar.snapQ = ar.snapQ.filter(q => q.at > Date.now());
            for (const q of due) stage.grabToImage(res => res.saveToFile(q.path));
        }
    }
    function simStep(raw) {
        const s = sm;
        if (s.freeze > 0) { s.freeze -= raw; return false; }
        const dt = s.slow * raw;
        if (s.slowT > 0) { s.slowT -= raw; if (s.slowT <= 0) s.slow = 1; }
        step(dt);
        return true;
    }
    Timer {
        id: tick
        interval: 16
        repeat: true
        property real last: 0
        onTriggered: {
            const now = Date.now(), frameTime = last ? Math.min(0.1, (now - last) / 1000) : 0.016; last = now;
            if (!ar.g.on || !ar.sm) { stop(); return; }
            // vsync-driven, but the sim + scene update is capped at ~60 Hz (high-refresh outputs would otherwise redraw 200x/s)
            ar.paintAcc += frameTime;
            // eco mode: 30 Hz sim + repaint (the sim runs in 30-fps units, so it only gets coarser)
            if (ar.paintAcc < 0.014) return;
            if (ar.g.eco && (++ar.ecoN & 1)) return;      // every second ~60 Hz step
            const ft = Math.min(0.066, ar.paintAcc); ar.paintAcc = 0;
            ar.perfTick(ft);
            if (ar.g.turbo > 1) { for (let k = 0; k < ar.g.turbo && ar.sm; k++) ar.simStep(0.5); if (ar.sm) { ar.applyCam(); ar.paintLayers(); } return; }   // test helper
            if (!ar.simStep(ft * 30)) { ar.applyCam(); return; }
            ar.applyCam();
            ar.paintLayers();
        }
    }

    Item {
        id: stage
        width: 900; height: 560
        scale: ar.sc
        transformOrigin: Item.TopLeft
        clip: true
        opacity: 0
        NumberAnimation { id: fadeIn; target: stage; property: "opacity"; to: 1; duration: 250 }
        NumberAnimation { id: fadeOut; target: stage; property: "opacity"; to: 0; duration: 600; onFinished: ar.g.finishMatch() }

        // the hall: painted once
        Canvas {
            id: hallBg
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d"); ctx.reset();
                const dark = Qt.darker(ar.cFace, 1.8).toString(), dark2 = Qt.darker(ar.cFace, 1.35).toString();
                canvas.px(ctx, dark, 4, 4, width - 8, height - 8);
                ctx.globalAlpha = 0.18; for (let k = 0; k < 6; k++) canvas.px(ctx, dark2, 10, 124 + k * 22, width - 20, 10); ctx.globalAlpha = 1;
            }
        }
        // the world under the camera: one GPU transform (scale + translate) per frame
        Item {
            id: world
            width: 900; height: 560
            transformOrigin: Item.TopLeft
            // crowd + spotlights: one fragment shader on the GPU (no CPU redraw)
            ShaderEffect {
                id: crowdFx
                anchors.fill: parent
                property real fr: 0
                property real hype: 0
                property real cam: 0
                property color a2: ar.cAccent2
                readonly property var cs: ar.g.coats
                property color c0: cs[0]; property color c1: cs[1]; property color c2: cs[2]; property color c3: cs[3]
                property color c4: cs[4]; property color c5: cs[5]; property color c6: cs[6]; property color c7: cs[7]
                fragmentShader: Qt.resolvedUrl("shaders/crowd.frag.qsb")
                visible: ar.shaderOk
            }
            // fallback when the shader can't load (old GPU/driver, missing .qsb) or is turned off: the
            // same crowd + spotlights on a Canvas, repainted at ~20 fps
            Canvas {
                id: crowdCv
                anchors.fill: parent
                visible: !ar.shaderOk
                smooth: false
                renderStrategy: Canvas.Threaded
                property var cols: null
                onPaint: {
                    const sm = ar.sm; if (!sm || !visible) return;
                    const ctx = getContext("2d"); ctx.reset();
                    const ww = width, fy = ar.fy, fr = sm.frame, hallTop = 84, A2 = ar.cAccent2.toString();
                    if (!cols) {
                        const c = [];
                        for (let r = 0; r < 3; r++) { c.push([]); for (let k = 0; k < 97; k++) c[r].push(Qt.darker(ar.g.coats[k % ar.g.coats.length], 1.6 + r * 0.3).toString()); }
                        cols = c;
                    }
                    const rows = ar.crowdRows;
                    for (let r = rows.length - 1; r >= 0; r--) {
                        const R = rows[r], step = (ww - 40) / R.n, sh = Math.sin(fr / 20 + r) * (3 - r);
                        const hw = 12 * R.s, al = R.a + sm.hype * 0.25, cheerOn = sm.hype > 0.35;
                        for (let i = 0; i < R.n; i++) {
                            const seed = (i * 7919 + r * 104729) % 97;
                            const c = cols[r][seed];
                            const cx = 20 + i * step + sh, jump = Math.round(Math.abs(Math.sin(fr / 4 + seed)) * (1 + sm.hype * 10) * R.s);
                            const by2 = R.y - jump;
                            ctx.globalAlpha = al;
                            ctx.fillStyle = c;
                            ctx.fillRect(Math.round(cx), by2 - hw, hw, hw);
                            ctx.fillRect(Math.round(cx - 2 * R.s), by2, hw + 4 * R.s, 16 * R.s);
                            if (cheerOn && seed % 3 !== 0) { const wv = Math.sin(fr / 2 + seed) * 3; ctx.fillRect(Math.round(cx - 5 * R.s + wv), by2 - hw - 8 * R.s, 3 * R.s, 12 * R.s); ctx.fillRect(Math.round(cx + hw + 2 * R.s - wv), by2 - hw - 8 * R.s, 3 * R.s, 12 * R.s); }
                            if (seed % 9 === 0) {
                                ctx.globalAlpha = 0.9; ctx.fillStyle = "#cfe3ff"; ctx.fillRect(Math.round(cx + hw + 2), by2 - hw - 10 * R.s, 5 * R.s, 8 * R.s);
                                if (sm.cam > 0 && (seed + Math.floor(fr)) % 5 === 0) { ctx.fillStyle = "#ffffff"; ctx.globalAlpha = 0.85; ctx.fillRect(Math.round(cx + hw - 6), by2 - hw - 18 * R.s, 22 * R.s, 22 * R.s); ctx.globalAlpha = 0.25; ctx.fillRect(Math.round(cx + hw - 16), by2 - hw - 28 * R.s, 42 * R.s, 42 * R.s); }
                            }
                        }
                    }
                    for (let k = 0; k < 2; k++) {
                        const sx = k === 0 ? 120 : ww - 120, tx = 450 + Math.sin(fr / 30 + k * 2.4) * 260;
                        ctx.globalAlpha = 0.07 + sm.hype * 0.05; ctx.fillStyle = k === 0 ? A2 : "#ffffff";
                        ctx.beginPath(); ctx.moveTo(sx - 8, hallTop + 4); ctx.lineTo(sx + 8, hallTop + 4); ctx.lineTo(tx + 70, fy); ctx.lineTo(tx - 70, fy); ctx.closePath(); ctx.fill();
                        ctx.globalAlpha = 0.18; ctx.beginPath(); ctx.ellipse(tx - 70, fy - 8, 140, 16); ctx.fill();
                    }
                    ctx.fillStyle = "#ffffff"; ctx.globalAlpha = 0.05;
                    ctx.beginPath(); ctx.moveTo(410, hallTop + 72); ctx.lineTo(490, hallTop + 72); ctx.lineTo(ar.pr + 30, fy); ctx.lineTo(ar.pl - 30, fy); ctx.closePath(); ctx.fill();
                    ctx.globalAlpha = 1;
                }
            }
            // banners, apron, posts, doors: painted once
            Canvas {
                id: staticCv
                anchors.fill: parent
                smooth: false
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset();
                    const ww = width, fy = ar.fy, pl = ar.pl, pr = ar.pr, hallTop = 84, dk = canvas.dk, px = canvas.px;
                    const A = ar.cAccent.toString(), A2 = ar.cAccent2.toString(), SUNK = ar.cSunken.toString();
                    for (const bx2 of [40, ww - 220]) {
                        px(ctx, A, bx2, hallTop + 20, 180, 30); px(ctx, dk, bx2 + 3, hallTop + 23, 174, 24);
                        for (let t = 0; t < 6; t++) px(ctx, A, bx2 + 6 + t * 30, hallTop + 50, 12, 6 + (t % 2) * 4);
                        ctx.fillStyle = A2; ctx.font = "bold 15px \"" + Theme.fontTitle + "\""; ctx.textAlign = "center";
                        ctx.fillText(String(ar.g.arenaName).toUpperCase().slice(0, 18), bx2 + 90, hallTop + 40);
                    }
                    px(ctx, A, pl - 40, fy, pr - pl + 80, 14);
                    px(ctx, dk, pl - 40, fy + 14, pr - pl + 80, 30);
                    ctx.globalAlpha = 0.25; px(ctx, A2, pl - 32, fy + 18, pr - pl + 64, 4); ctx.globalAlpha = 1;
                    px(ctx, SUNK, pl - 40, fy - 6, pr - pl + 80, 6);
                    for (const x of [pl, pr]) { px(ctx, "#d8d8e0", x, fy - 104, 8, 104); px(ctx, A, x - 2, fy - 110, 12, 10); }
                    for (const tx2 of [170, 670]) { px(ctx, "#111116", tx2, fy - 150, 60, 144); px(ctx, A, tx2 - 4, fy - 156, 68, 6); ctx.globalAlpha = 0.5; px(ctx, A2, tx2, fy - 150, 4, 144); px(ctx, A2, tx2 + 56, fy - 150, 4, 144); ctx.globalAlpha = 1; }
                }
            }
        component Lyr: Canvas {
            anchors.fill: parent
            smooth: false
            property bool was: false
            renderStrategy: Canvas.Threaded
        }
        Lyr {
            id: ropeBack
            onPaint: { const ctx = getContext("2d"); ctx.reset(); if (ar.sm) { canvas.drawRope(ctx, 96, "#e04848", false); canvas.drawRope(ctx, 70, "#ffffff", false); } }
        }
        Lyr {
            id: trCv
            property string key: ""
            onPaint: {
                const ctx = getContext("2d"); ctx.reset(); const sm = ar.sm; if (!sm) return;
                const br = sm.phase === "break", acts = t => t < 88 ? "water" : t < 140 ? "towel" : "fan";
                for (let i = 0; i < 2; i++) canvas.drawTrainer(ctx, sm.trX[i], i, br && sm.f[i].sit ? acts(sm.phT) : "", sm.frame, sm.f[i].coat, sm.f[i].x);
            }
        }
        Lyr {
            id: backCv
            onPaint: {
                const ctx = getContext("2d"); ctx.reset(); const sm = ar.sm; if (!sm) return;
                const fy = ar.fy;
                for (const f of sm.f)
                    for (let i = 0; i < f.trail.length; i++) { ctx.globalAlpha = 0.28 - i * 0.06; canvas.px(ctx, f.coat, f.trail[i].x - 15, fy - f.trail[i].y - 66, 30, 54); }
                ctx.globalAlpha = 1;
                if (sm.phase === "win" && sm.pod) canvas.drawPodium(ctx, sm.pod.rise, sm.frame);
                if (sm.phase === "break" && sm.rw >= 0 && sm.phT < 45) canvas.drawRoundGlow(ctx, sm.f[sm.rw], sm.phT, sm.frame, true);
            }
        }
        // fighters: small sprite canvases moved by x/y (GPU), 320x320 each instead of a full-window redraw
        component FCv: Canvas {
            required property int idx
            property string key: ""
            width: 320; height: 320
            smooth: false
            renderStrategy: Canvas.Threaded
            onPaint: {
                const ctx = getContext("2d"); ctx.reset(); const sm = ar.sm; if (!sm) return;
                ctx.imageSmoothingEnabled = false;
                ctx.translate(-x, -y);
                canvas.drawFighter(ctx, sm.f[idx]);
            }
            onImageLoaded: { key = ""; requestPaint(); }
        }
        // pickups: three sprite slots, positioned on the GPU, repainted only when their look changes
        Repeater {
            id: itemRep
            model: 3
            Canvas {
                id: icv
                required property int index
                property string key: ""
                width: 260; height: 100; visible: false
                smooth: false
                renderStrategy: Canvas.Threaded
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset(); const sm = ar.sm; if (!sm) return;
                    const it = sm.items.find(q => q.slot === index);
                    if (it) canvas.drawItem(ctx, it, sm.frame);
                }
            }
        }
        FCv { id: fCv0; idx: 0 }
        FCv { id: fCv1; idx: 1 }
        Lyr {
            id: frontCv
            onPaint: {
                const ctx = getContext("2d"); ctx.reset(); const sm = ar.sm; if (!sm) return;
                if (sm.phase === "break" && sm.rw >= 0 && sm.phT < 45) canvas.drawRoundGlow(ctx, sm.f[sm.rw], sm.phT, sm.frame, false);
                if (sm.phase === "win" && sm.pod) canvas.drawPodiumFx(ctx, sm.winner, sm.loser, sm.pod, sm.frame);
                if (sm.phase === "card") {
                    ctx.globalAlpha = Math.max(0, Math.min(1, (sm.cardX - 200) / 40, (700 - sm.cardX) / 40));
                    canvas.drawGirl(ctx, sm.cardX, sm.round, sm.cardHold === 0 && Math.floor(sm.frame / 4) % 2 === 1);
                    ctx.globalAlpha = 1;
                }
            }
        }
        Lyr {
            id: ropeFront
            onPaint: { const ctx = getContext("2d"); ctx.reset(); if (ar.sm) canvas.drawRope(ctx, 44, "#3a7bd5", true); }
        }
        // ring smoke: plain rectangles, positions bound to the frame counter
        Item {
            id: smokeLayer
            anchors.fill: parent
            property real fr: 0
            property bool boost: false
            Repeater {
                model: 9
                Rectangle {
                    required property int index
                    color: "#d8d8e0"
                    opacity: 0.07 + (smokeLayer.boost ? 0.06 : 0)
                    width: 90 + (index % 3) * 30; height: 26
                    x: Math.round(((index * 113 + smokeLayer.fr * (0.6 + (index % 3) * 0.3)) % 1100) - 100)
                    y: Math.round(ar.fy - 22 + Math.sin(smokeLayer.fr / 9 + index) * 4)
                }
            }
        }
        Canvas {
            id: annCv
            x: 0; y: ar.fy - 180; width: 120; height: 190
            smooth: false
            property var talk: null
            onPaint: { const ctx = getContext("2d"); ctx.reset(); ctx.translate(0, -y); canvas.drawAnnouncer(ctx, 48, !!talk); }
        }
        Canvas {
            id: canvas
            property bool was: false
            anchors.fill: parent
            smooth: false
            renderStrategy: Canvas.Threaded
            readonly property string dk: "#2b2433"
            readonly property string skin: "#f4c9a8"

            function px(ctx, c, x, y, w, h) { ctx.fillStyle = c; ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); }
            function drawBmp(ctx, bmp, x, y, face, ang, p) {
                ctx.save();
                ctx.translate(x, y); ctx.scale(face, 1); ctx.rotate(ang);
                const w = bmp[0].length;
                for (let r = 0; r < bmp.length; r++)
                    for (let c = 0; c < w; c++) {
                        const ch = bmp[r][c];
                        if (ch === ".") continue;
                        ctx.fillStyle = ar.g.wcol(ch);
                        ctx.fillRect(Math.round((c - w / 2) * p), Math.round((r - bmp.length) * p), p, p);
                    }
                ctx.restore();
            }
            function weaponAngle(f) {
                const mv = f.mv, t = f.t;
                if (f.st === "win") return -0.3;
                if (f.st === "hurt") return -0.6;
                if (f.st === "sit" || f.st === "walk") return 0.9;
                if (f.st === "jatk") return f.vy > 0 ? -1.3 : 1.7;
                if (f.st !== "atk" || !mv) return 0.35;
                switch (mv.k) {
                case "overhead": case "spacebar": return t > 6 ? -2.6 : 1.9;
                case "homerun": return t > 6 ? 2.6 : -1.1;
                case "flurry": return Math.floor(t / 1.5) % 2 ? -0.9 : 1.5;
                case "wave": case "beam": case "eyeblast": case "spray": return 1.57;
                case "eat": return -0.15;
                case "flop": case "throw": return t > 6 ? -1.4 : 1.2;
                default: return t > 6 ? -1.1 : 1.5;
                }
            }
            function drawFighter(ctx, f) {
                const sm = ar.sm, p = 3, fy = ar.fy, DK = dk;
                const sitting = f.st === "sit";
                const sq = f.squash > 0 ? f.squash : 0;
                const w = 18 * p + sq * 2, h = 32 * p - sq * 2 - (sitting ? 4 * p : 0);
                const bx = Math.round(f.x - w / 2), by = Math.round(fy - f.y - h - (sitting ? 6 : 0));
                const white = f.flash > 0 && Math.floor(f.flash) % 2 === 0;
                const coat = white ? "#ffffff" : f.coat;
                ctx.save();
                ctx.globalAlpha = f.fade ? (Math.floor(sm.frame / 2) % 2 ? f.alpha : f.alpha * 0.5) : 1;
                if (f.st === "ko" && f.y === 0 && Math.abs(f.vx) < 2) { ctx.translate(f.x, fy); ctx.rotate(f.face > 0 ? Math.PI / 2 : -Math.PI / 2); ctx.translate(-f.x, -fy); }
                else if (f.st === "ko" || f.st === "jatk") { ctx.translate(f.x, by + h / 2); ctx.rotate((f.st === "ko" ? -1 : 1) * f.face * Math.min(1.2, (sm.frame % 40) / 12)); ctx.translate(-f.x, -(by + h / 2)); }
                const ga = ctx.globalAlpha;
                ctx.globalAlpha = ga * 0.25; px(ctx, "#000000", f.x - 22 + f.y / 8, fy - 4, Math.max(4, 44 - f.y / 4), 4); ctx.globalAlpha = ga;
                if (f.spd > 0 && f.st !== "ko") for (let k = 0; k < 3; k++) { ctx.globalAlpha = 0.7 - k * 0.15; px(ctx, k % 2 ? "#6ec3e8" : "#ffe066", f.x - f.face * (28 + k * 10 + (Math.floor(sm.frame / 3) % 2) * 6), fy - f.y - 18 - k * 20, 22, 3); } ctx.globalAlpha = ga;
                if (ar.g.superOn && f.st !== "ko" && (f.sp >= 100 || (f.st === "atk" && f.mv && f.mv.k === "super" && f.t > 12))) drawSuperAura(ctx, f);
                if (sitting) { px(ctx, "#8a5a2b", f.x - 22, fy - 22, 44, 6); px(ctx, "#5a3a1b", f.x - 20, fy - 16, 5, 16); px(ctx, "#5a3a1b", f.x + 15, fy - 16, 5, 16); }
                const walk = ((f.st === "dash" || f.st === "walk") && Math.floor(sm.frame / 3) % 2) ? p : 0;
                if (sitting) { px(ctx, DK, bx + 5 * p + f.face * 2 * p, by + h - 2 * p, 3 * p, 2 * p); px(ctx, DK, bx + 10 * p + f.face * 2 * p, by + h - 2 * p, 3 * p, 2 * p); }
                else { px(ctx, DK, bx + 5 * p - walk, by + h - 5 * p, 3 * p, 5 * p); px(ctx, DK, bx + 10 * p + walk, by + h - 5 * p, 3 * p, 5 * p); }
                px(ctx, Qt.darker(f.coat, 1.6).toString(), bx + 4 * p, by + h - 13 * p, 10 * p, 8 * p);
                px(ctx, coat, bx + 5 * p, by + h - 12 * p, 8 * p, 6 * p);
                const arm = Qt.darker(f.coat, 1.25).toString();
                const front = f.face > 0 ? bx + 14 * p : bx + 2 * p, back = f.face > 0 ? bx + 2 * p : bx + 14 * p;
                const hasW = f.wep.id !== "fists" && !f.noWep;
                if (f.st === "win") { px(ctx, arm, bx + p, by + h - 19 * p, 2 * p, 7 * p); px(ctx, arm, bx + 15 * p, by + h - 19 * p, 2 * p, 7 * p); }
                else {
                    px(ctx, arm, back, by + h - 12 * p, 2 * p, 6 * p);
                    const punching = !hasW && ((f.st === "atk" && f.t <= 6) || (f.st === "jatk" && f.vy < 0));
                    if (punching) {
                        const ax = f.face > 0 ? bx + 14 * p : bx - 6 * p;
                        px(ctx, arm, ax, by + h - 11 * p, 10 * p, 2 * p);
                        px(ctx, "#e04848", f.face > 0 ? ax + 9 * p : ax - 2 * p, by + h - 12 * p, 4 * p, 4 * p);
                    } else {
                        px(ctx, arm, front, by + h - 12 * p, 2 * p, 4 * p);
                        if (!hasW) px(ctx, "#e04848", front - p / 2, by + h - 9 * p, 3 * p, 3 * p);
                    }
                }
                if (hasW && f.st !== "ko") {
                    const eat = f.st === "atk" && f.mv && f.mv.k === "eat";
                    const hxp = f.st === "win" ? (f.face > 0 ? bx + 16 * p : bx + 2 * p) : eat ? f.x + f.face * 4 * p : (f.face > 0 ? bx + 15 * p : bx + 3 * p);
                    const hyp = f.st === "win" ? by + h - 19 * p : eat ? by + h - 16 * p : by + h - 8 * p;
                    if (f.st === "atk" && f.mv && f.mv.k === "beam" && f.t > 8) { ctx.globalAlpha = 0.5; px(ctx, "#ff4f6d", f.x + f.face * 40 - 14, fy - f.y - 94, 28, 28); ctx.globalAlpha = ga; }
                    drawBmp(ctx, f.wep.bmp, hxp, hyp, f.face, weaponAngle(f), 6);
                }
                const hs = 14 * p, hx = Math.round(f.x - hs / 2), hy = by + h - 13 * p - hs;
                px(ctx, DK, hx, hy, hs, hs);
                px(ctx, coat, hx + p, hy + p, hs - 2 * p, hs - 2 * p);
                if (f.img && ctx.canvas.isImageLoaded(f.img) && !white) {
                    ctx.save();
                    if (f.face < 0) { ctx.translate(hx + hs, 0); ctx.scale(-1, 1); ctx.drawImage(f.img, p, hy + p, hs - 2 * p, hs - 2 * p); }
                    else ctx.drawImage(f.img, hx + p, hy + p, hs - 2 * p, hs - 2 * p);
                    ctx.restore();
                } else if (!white) {
                    ctx.fillStyle = DK; ctx.font = "bold 22px \"" + Theme.fontTitle + "\""; ctx.textAlign = "center";
                    ctx.fillText(String(f.who.name).charAt(0).toUpperCase(), f.x, hy + hs / 2 + 8);
                }
                if (f.st === "atk" && f.mv && f.mv.k === "eyeblast") { px(ctx, "#ff4f6d", f.x - 10, hy + 14, 8, 8); px(ctx, "#ff4f6d", f.x + 4, hy + 14, 8, 8); }
                if (f.stun > 0 && f.st !== "ko") for (let k = 0; k < 3; k++) { const a = sm.frame / 4 + k * 2.1; px(ctx, "#ffe066", f.x + Math.cos(a) * 22 - 3, hy - 8 + Math.sin(a) * 5, 6, 6); }
                if (f.st === "ko") { ctx.fillStyle = "#e04848"; ctx.font = "bold 16px \"" + Theme.fontTitle + "\""; ctx.textAlign = "center"; ctx.fillText("x_x", f.x, hy + hs / 2 + 6); }
                if (f.st === "block") drawShield(ctx, f, front, arm, by, h, p);
                ctx.restore();
            }
            // pickup sprite: drawn about (130, 84) = the spot on the floor under it
            function drawItem(ctx, it, fr) {
                const ox = 130, oy = 84, DK = dk;
                const lit = it.st === "fuse" && Math.floor(it.fuse / (it.fuse > 30 ? 6 : 3)) % 2 === 0;
                ctx.globalAlpha = 0.25; px(ctx, "#000000", ox - 14, oy - 3, 28, 4); ctx.globalAlpha = 1;
                if (it.k === "heal") {
                    ctx.globalAlpha = 0.22; ctx.fillStyle = "#3ddc84"; ctx.beginPath(); ctx.ellipse(ox - 26, oy - 52, 52, 48); ctx.fill(); ctx.globalAlpha = 1;
                    px(ctx, DK, ox - 15, oy - 42, 30, 28); px(ctx, "#f4f4f8", ox - 13, oy - 40, 26, 24); px(ctx, "#d6d6e0", ox - 13, oy - 20, 26, 4);
                    px(ctx, "#3ddc84", ox - 3, oy - 37, 6, 18); px(ctx, "#3ddc84", ox - 9, oy - 31, 18, 6);
                    px(ctx, DK, ox - 8, oy - 46, 16, 4);
                } else if (it.k === "speed") {
                    ctx.globalAlpha = 0.22; ctx.fillStyle = "#ffe066"; ctx.beginPath(); ctx.ellipse(ox - 26, oy - 52, 52, 48); ctx.fill(); ctx.globalAlpha = 1;
                    px(ctx, DK, ox - 15, oy - 42, 30, 30); px(ctx, "#2f4fbf", ox - 13, oy - 40, 26, 26);
                    const bolt = [[4, -38], [-4, -28], [1, -28], [-5, -16], [7, -30], [1, -30]];
                    ctx.fillStyle = "#ffe066"; ctx.beginPath(); ctx.moveTo(ox + bolt[0][0], oy + bolt[0][1]); for (let k = 1; k < bolt.length; k++) ctx.lineTo(ox + bolt[k][0], oy + bolt[k][1]); ctx.closePath(); ctx.fill();
                    px(ctx, "#ffffff", ox - 12, oy - 39, 4, 4);
                } else {
                    if (it.st === "fuse") {   // blast radius warning on the floor
                        ctx.globalAlpha = lit ? 0.5 : 0.2; ctx.strokeStyle = "#ff4f6d"; ctx.lineWidth = 3;
                        ctx.beginPath(); ctx.ellipse(ox - 110, oy - 12, 220, 22); ctx.stroke();
                        ctx.fillStyle = "#ff4f6d"; ctx.globalAlpha = lit ? 0.16 : 0.06; ctx.beginPath(); ctx.ellipse(ox - 110, oy - 12, 220, 22); ctx.fill(); ctx.globalAlpha = 1;
                    }
                    const body = lit ? "#c0392b" : "#1a1a20";
                    ctx.fillStyle = DK; ctx.beginPath(); ctx.ellipse(ox - 17, oy - 38, 34, 34); ctx.fill();
                    ctx.fillStyle = body; ctx.beginPath(); ctx.ellipse(ox - 15, oy - 36, 30, 30); ctx.fill();
                    px(ctx, lit ? "#ff8a7a" : "#5a5a6a", ox - 9, oy - 31, 6, 6);
                    px(ctx, "#8a5a2b", ox - 2, oy - 46, 4, 8); px(ctx, "#8a5a2b", ox + 2, oy - 50, 4, 4);
                    const sp = (Math.floor(fr / 2) % 2) || it.st === "fuse";
                    if (sp) { px(ctx, "#ffd34d", ox + 4, oy - 56, 6, 6); px(ctx, "#ff8a3d", ox + 2, oy - 58, 2, 2); px(ctx, "#ffffff", ox + 7, oy - 59, 2, 2); }
                    if (it.st === "fuse" && it.fuse < 40) { ctx.fillStyle = "#ffffff"; ctx.font = "bold 16px \"" + Theme.fontTitle + "\""; ctx.textAlign = "center"; ctx.fillText("!", ox, oy - 62); }
                }
            }
            // super ready / charging: a pulsing golden glow behind the body and a ring on the floor
            function drawSuperAura(ctx, f) {
                const sm = ar.sm, fy = ar.fy, ch = f.st === "atk", ph = Math.floor(sm.frame / 5) % 2;
                ctx.save();
                ctx.globalAlpha = ch ? 0.4 : 0.18 + ph * 0.08; ctx.fillStyle = "#ffd34d";
                ctx.beginPath(); ctx.ellipse(f.x - (ch ? 54 : 40), fy - f.y - (ch ? 120 : 108), ch ? 108 : 80, ch ? 124 : 112); ctx.fill();
                ctx.globalAlpha = ch ? 0.6 : 0.4; ctx.fillStyle = "#fff2a8";
                ctx.beginPath(); ctx.ellipse(f.x - 34, fy - f.y - 8, 68, 12); ctx.fill();
                ctx.restore();
            }
            // block: forearms crossed in front, a glowing bubble round the whole body (flashes white when a hit lands)
            function drawShield(ctx, f, front, arm, by, h, p) {
                const sm = ar.sm, fy = ar.fy, fl = f.bflash > 0, ph = Math.floor(sm.frame / 3) % 2;
                px(ctx, arm, front - p, by + h - 19 * p, 3 * p, 8 * p);
                px(ctx, "#e04848", front - p, by + h - 21 * p, 3 * p, 3 * p);
                const cx = f.x + f.face * 8, cy = fy - f.y - 52, rx = 46, ry = 64;
                ctx.save();
                ctx.globalAlpha = fl ? 0.55 : 0.2 + ph * 0.06; ctx.fillStyle = fl ? "#ffffff" : "#7fe0ff";
                ctx.beginPath(); ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2); ctx.fill();
                ctx.globalAlpha = 0.95; ctx.strokeStyle = fl ? "#ffffff" : "#bff3ff"; ctx.lineWidth = 4;
                ctx.beginPath(); ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2); ctx.stroke();
                ctx.globalAlpha = 0.9;
                for (let k = 0; k < 10; k++) {                 // pixel facets drifting round the rim
                    const a2 = (k / 10) * Math.PI * 2 + ph * 0.15;
                    px(ctx, k % 2 ? "#ffffff" : "#7fe0ff", cx + Math.cos(a2) * (rx + 2) - 3, cy + Math.sin(a2) * (ry + 2) - 3, 6, 6);
                }
                ctx.globalAlpha = 0.5; px(ctx, "#ffffff", cx + f.face * 24, cy - 40, 6, 22); px(ctx, "#ffffff", cx + f.face * 24, cy - 14, 6, 6);
                ctx.restore();
            }
            function drawRope(ctx, yOff, col, front) {
                const sm = ar.sm, pl = ar.pl, pr = ar.pr, fy = ar.fy;
                for (let x = pl; x < pr + 8; x += 4) {
                    const t = (x - pl) / (pr - pl);
                    const w = (sm.ropeW[0] * Math.max(0, 1 - t * 2) + sm.ropeW[1] * Math.max(0, t * 2 - 1)) * Math.sin(sm.frame * 1.3) * Math.sin(Math.PI * t);
                    px(ctx, col, x, fy - yOff + Math.round(w * (front ? 1 : 0.6)), 4, 4);
                }
            }
            function drawTrainer(ctx, x, side, act, t, coat, fx) {
                const p = 3, fy = ar.fy, face = side === 0 ? 1 : -1, DK = dk, SKIN = skin;
                const bx = x - 9 * p, by = fy - 30 * p;
                px(ctx, DK, bx + 5 * p, by + 25 * p, 3 * p, 5 * p); px(ctx, DK, bx + 10 * p, by + 25 * p, 3 * p, 5 * p);
                px(ctx, "#f0f0f0", bx + 4 * p, by + 15 * p, 10 * p, 10 * p);
                px(ctx, coat, bx + 4 * p, by + 15 * p, 10 * p, 2 * p);
                px(ctx, "#ffffff", bx + (face > 0 ? 4 : 11) * p, by + 15 * p, 3 * p, 8 * p);
                px(ctx, DK, bx + 4 * p, by + 3 * p, 10 * p, 12 * p);
                px(ctx, SKIN, bx + 5 * p, by + 4 * p, 8 * p, 10 * p);
                px(ctx, coat, bx + 3 * p, by + 2 * p, 12 * p, 3 * p); px(ctx, coat, bx + (face > 0 ? 12 : 0) * p, by + 4 * p, 6 * p, p);
                px(ctx, DK, bx + (face > 0 ? 9 : 6) * p, by + 8 * p, p, p);
                const hx = x + face * 30, hy = fy - 70;
                const arm = (x2, y2) => { const x1 = x + face * 10, y1 = fy - 76; const n = 6; for (let i = 0; i <= n; i++) px(ctx, "#f0f0f0", x1 + (x2 - x1) * i / n - 3, y1 + (y2 - y1) * i / n - 3, 6, 6); px(ctx, SKIN, x2 - 3, y2 - 3, 6, 6); };
                if (act === "water") {
                    // clear plastic bottle, blue water, squirting droplets at the fighter's mouth
                    const hx2 = x + face * 30, hy2 = fy - 96;
                    arm(hx2, hy2);
                    ctx.save(); ctx.translate(hx2, hy2); ctx.rotate(face * (1.0 + Math.sin(t / 4) * 0.12)); ctx.scale(1.4, 1.4);
                    ctx.globalAlpha = 0.45; px(ctx, "#e8f6ff", -6, -26, 12, 30); ctx.globalAlpha = 1;
                    px(ctx, "#bfe6ff", -6, -26, 1, 30); px(ctx, "#bfe6ff", 5, -26, 1, 30); px(ctx, "#bfe6ff", -6, 3, 12, 1);
                    px(ctx, "#2f8fe0", -5, -14, 10, 17); px(ctx, "#7cc8ff", -5, -14, 10, 2);
                    px(ctx, "#ffffff", -3, -22, 2, 18);
                    px(ctx, "#ff8a3d", -5, -8, 10, 4);
                    px(ctx, "#bfe6ff", -3, -32, 6, 6); px(ctx, "#2f8fe0", -2, -36, 4, 4);
                    ctx.restore();
                    for (let i = 0; i < 6; i++) {
                        const k = ((t * 1.6 + i * 5) % 30) / 30, dx = face * (14 + k * (Math.abs(fx - hx2) + 6)), dy = -20 + k * 26 - Math.sin(k * Math.PI) * 14;
                        px(ctx, i % 2 ? "#7cc8ff" : "#2f8fe0", hx2 + dx, hy2 + dy, 4, 4);
                    }
                } else if (act === "towel") {
                    // long soft striped towel hanging from the hand, wiping across the face
                    const hx2 = fx - face * 6 + Math.sin(t / 2.2) * 10, hy2 = fy - 112;
                    arm(hx2, hy2);
                    drawCloth(ctx, hx2 - 10, hy2 - 2, t, 24, Math.sin(t / 2.2) * 0.6);
                } else if (act === "fan") {
                    // big folding fan: pleated wedge with ribs, swinging
                    const hx2 = x + face * 34, hy2 = fy - 92;
                    arm(hx2, hy2);
                    const base = -Math.PI / 2 + face * (0.5 + Math.sin(t / 1.5) * 0.45), N = 8, R = 40, spread = 1.7;
                    for (let i = 0; i < N; i++) {
                        const a0 = base - spread / 2 + spread * i / N, a1 = a0 + spread / N;
                        ctx.fillStyle = i % 2 ? ar.cAccent.toString() : ar.cAccent2.toString();
                        ctx.beginPath(); ctx.moveTo(hx2, hy2); ctx.arc(hx2, hy2, R, a0, a1, false); ctx.closePath(); ctx.fill();
                    }
                    ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(hx2, hy2, R - 4, base - spread / 2, base + spread / 2, false); ctx.stroke();
                    ctx.strokeStyle = DK; ctx.lineWidth = 1;
                    for (let i = 0; i <= N; i++) { const a = base - spread / 2 + spread * i / N; ctx.beginPath(); ctx.moveTo(hx2, hy2); ctx.lineTo(hx2 + Math.cos(a) * R, hy2 + Math.sin(a) * R); ctx.stroke(); }
                    ctx.globalAlpha = 0.5; for (let i = 0; i < 4; i++) px(ctx, "#ffffff", hx2 + face * (40 + ((t * 3 + i * 9) % 30)), hy2 - 30 + i * 9, 10, 2); ctx.globalAlpha = 1;
                } else {
                    px(ctx, "#f0f0f0", bx + (face > 0 ? 2 : 14) * p, by + 15 * p, 2 * p, 7 * p);
                }
            }
            // a long soft cloth: rows sway progressively more towards the free end; stripes + fringe
            function drawCloth(ctx, x, y, t, rows, swing) {
                const w = 20, A = ar.cAccent.toString();
                for (let r = 0; r < rows; r++) {
                    const off = Math.sin(t / 1.6 + r * 0.45) * r * 0.35 + swing * r * 1.2;
                    const wv = Math.round(Math.sin(t / 2 + r * 0.8) * 1.5);
                    const col = (r === 3 || r === 4) ? A : (r === rows - 5 || r === rows - 4) ? "#3a7bd5" : (r % 2 ? "#f4f4f8" : "#e6e6ee");
                    px(ctx, col, x + off - wv, y + r * 3, w + 2 * wv, 3);
                    if (r === rows - 1) for (let k = 0; k < w; k += 4) px(ctx, "#f4f4f8", x + off + k, y + rows * 3, 2, 4);
                }
                ctx.globalAlpha = 0.35; for (let r = 2; r < rows; r += 3) px(ctx, "#a8a8b8", x + Math.sin(t / 1.6 + r * 0.45) * r * 0.35 + swing * r * 1.2 + 7, y + r * 3, 2, 3); ctx.globalAlpha = 1;
            }
            function drawAnnouncer(ctx, x, talking) {
                const p = 3, fy = ar.fy, bx = x - 9 * p, by = fy - 34 * p, DK = dk, SKIN = skin;
                px(ctx, "#1a1a20", bx + 5 * p, by + 28 * p, 3 * p, 6 * p); px(ctx, "#1a1a20", bx + 10 * p, by + 28 * p, 3 * p, 6 * p);
                px(ctx, "#1a1a20", bx + 3 * p, by + 15 * p, 12 * p, 14 * p);
                px(ctx, "#ffffff", bx + 7 * p, by + 15 * p, 4 * p, 7 * p);
                px(ctx, "#e04848", bx + 6 * p, by + 15 * p, 6 * p, 2 * p); px(ctx, "#b02020", bx + 8 * p, by + 15 * p, 2 * p, 2 * p);
                px(ctx, "#1a1a20", bx + 13 * p, by + 10 * p, 2 * p, 7 * p);
                px(ctx, "#7a7a88", bx + 12 * p, by + 7 * p, 3 * p, 4 * p); px(ctx, "#1a1a20", bx + 13 * p, by + 11 * p, p, 3 * p);
                px(ctx, DK, bx + 4 * p, by + 1 * p, 10 * p, 14 * p);
                px(ctx, SKIN, bx + 5 * p, by + 3 * p, 8 * p, 11 * p);
                px(ctx, "#1a1a20", bx + 4 * p, by, 10 * p, 3 * p);
                px(ctx, DK, bx + 7 * p, by + 7 * p, p, p); px(ctx, DK, bx + 10 * p, by + 7 * p, p, p);
                px(ctx, "#5a3a1b", bx + 7 * p, by + 10 * p, 4 * p, p);
                px(ctx, talking ? "#b02020" : DK, bx + 8 * p, by + 11 * p, 2 * p, talking ? 2 * p : p);
            }
            function drawGirl(ctx, x, n, step) {
                const p = 3, fy = ar.fy, bx = x - 9 * p, by = fy - 30 * p, DK = dk, SKIN = skin;
                const legA = step ? p : 0;
                const ac = ar.cAccent.toString(), hc = ar.cAccent2.toString();
                px(ctx, "#ffffff", bx + 6 * p - legA, by + 25 * p, 2 * p, 5 * p); px(ctx, "#ffffff", bx + 10 * p + legA, by + 25 * p, 2 * p, 5 * p);
                px(ctx, SKIN, bx + 6 * p - legA, by + 22 * p, 2 * p, 3 * p); px(ctx, SKIN, bx + 10 * p + legA, by + 22 * p, 2 * p, 3 * p);
                px(ctx, ac, bx + 3 * p, by + 18 * p, 12 * p, 5 * p);
                px(ctx, "#ffffff", bx + 3 * p, by + 22 * p, 12 * p, p);
                // torso from the neck down to the skirt: no gap under the head
                px(ctx, ac, bx + 5 * p, by + 5 * p, 8 * p, 14 * p);
                px(ctx, "#ffffff", bx + 7 * p, by + 5 * p, 4 * p, 2 * p);          // collar
                px(ctx, "#ffffff", bx + 8 * p, by + 7 * p, 2 * p, 4 * p);
                px(ctx, SKIN, bx + 8 * p, by + 3 * p, 2 * p, 2 * p);                // neck
                // chibi head: a face a bit wider than the shoulders, hair framing it, ponytail
                px(ctx, hc, bx + 14 * p, by - 6 * p, 3 * p, 3 * p);                  // ponytail
                px(ctx, hc, bx + 15 * p, by - 3 * p, 2 * p, 4 * p);
                px(ctx, hc, bx + 14 * p, by + p, 2 * p, 2 * p);
                px(ctx, SKIN, bx + 4 * p, by - 6 * p, 10 * p, 9 * p);                // face
                px(ctx, SKIN, bx + 5 * p, by + 3 * p, 8 * p, p);                     // chin
                px(ctx, hc, bx + 5 * p, by - 9 * p, 8 * p, p);                       // crown
                px(ctx, hc, bx + 4 * p, by - 8 * p, 10 * p, 2 * p);
                px(ctx, hc, bx + 4 * p, by - 6 * p, 3 * p, p); px(ctx, hc, bx + 8 * p, by - 6 * p, 2 * p, p); px(ctx, hc, bx + 11 * p, by - 6 * p, 3 * p, p); // bangs
                px(ctx, hc, bx + 3 * p, by - 7 * p, p, 9 * p); px(ctx, hc, bx + 14 * p, by - 7 * p, p, 5 * p);   // side strands
                px(ctx, DK, bx + 6 * p, by - 3 * p, 2 * p, 2 * p); px(ctx, DK, bx + 10 * p, by - 3 * p, 2 * p, 2 * p);  // eyes
                px(ctx, "#ffffff", bx + 6 * p, by - 3 * p, p, p); px(ctx, "#ffffff", bx + 10 * p, by - 3 * p, p, p);
                px(ctx, "#f29bb0", bx + 5 * p, by, 2 * p, p); px(ctx, "#f29bb0", bx + 11 * p, by, 2 * p, p);        // blush
                px(ctx, "#b02020", bx + 8 * p, by + p, 2 * p, p);                   // mouth
                px(ctx, "#ffffff", bx + 12 * p, by - 9 * p, 3 * p, 2 * p);           // a bow at the side
                const sx = x - 70, sy = by - 92;
                px(ctx, DK, sx - 4, sy - 4, 148, 58);
                px(ctx, "#ffffff", sx, sy, 140, 50);
                px(ctx, ac, sx, sy, 140, 6); px(ctx, ac, sx, sy + 44, 140, 6);
                ctx.fillStyle = DK; ctx.font = "bold 26px \"" + Theme.fontTitle + "\""; ctx.textAlign = "center";
                ctx.fillText(ar.tl("РАУНД ", "ROUND ") + n, x, sy + 35);
                // arms: from the shoulders up to the sign's bottom edge
                px(ctx, SKIN, bx - 2 * p, sy + 50, 2 * p, by + 7 * p - (sy + 50)); px(ctx, SKIN, bx + 18 * p, sy + 50, 2 * p, by + 7 * p - (sy + 50));
                px(ctx, ac, bx - 2 * p, by + 5 * p, 7 * p, 3 * p); px(ctx, ac, bx + 13 * p, by + 5 * p, 7 * p, 3 * p);   // shoulders + sleeves
            }

            onPaint: {
                const sm = ar.sm;
                if (!sm) return;
                const ctx = getContext("2d");
                ctx.reset();
                ctx.imageSmoothingEnabled = false;
                const ww = width, H = height, fy = ar.fy, pl = ar.pl, pr = ar.pr;
                const A = ar.cAccent.toString(), A2 = ar.cAccent2.toString(), FACE = ar.cFace.toString(), SUNK = ar.cSunken.toString();
                const t0 = Date.now();
                const rope = (yOff, col, front) => {   // (unused here: ropes have their own layers)
                    for (let x = pl; x < pr + 8; x += 4) {
                        const t = (x - pl) / (pr - pl);
                        const w = (sm.ropeW[0] * Math.max(0, 1 - t * 2) + sm.ropeW[1] * Math.max(0, t * 2 - 1)) * Math.sin(sm.frame * 1.3) * Math.sin(Math.PI * t);
                        px(ctx, col, x, fy - yOff + Math.round(w * (front ? 1 : 0.6)), 4, 4);
                    }
                };
                for (const q of sm.proj) {
                    if (q.k === "wave") {
                        for (let k = 0; k < 3; k++) { const hh = (10 + k * 8) * q.size; ctx.globalAlpha = 1 - k * 0.25; px(ctx, A2, q.x - (q.vx > 0 ? k * 10 : -k * 10), q.y - hh, 4, hh * 2); }
                        ctx.globalAlpha = 1;
                    } else if (q.k === "throw") drawBmp(ctx, q.bmp, q.x, q.y + 20, 1, q.rot, 5);
                    else if (q.k === "flop") drawBmp(ctx, q.bmp, q.x, q.y, 1, Math.PI / 2 + Math.sin(sm.frame) * 0.5, 4);
                    else if (q.k === "mic") drawBmp(ctx, q.bmp, q.x, q.y, 1, 0, 6);
                    else if (q.k === "key") { px(ctx, "#1a1a20", q.x - 9, q.y - 9, 18, 18); ctx.fillStyle = "#ffffff"; ctx.font = "bold 12px \"" + Theme.fontTitle + "\""; ctx.textAlign = "center"; ctx.fillText(q.ch, q.x, q.y + 4); }
                }
                for (const bm of sm.beams) {
                    const x0 = Math.min(bm.x1, bm.x2), x1 = Math.max(bm.x1, bm.x2);
                    ctx.globalAlpha = bm.life / 8;
                    px(ctx, "#e04848", x0, bm.y - bm.w / 2, x1 - x0, bm.w); px(ctx, "#ffffff", x0, bm.y - bm.w / 6, x1 - x0, bm.w / 3);
                    ctx.globalAlpha = 1;
                }
                if (sm.maxBeam > 0) { ctx.globalAlpha = sm.maxBeam / 18; px(ctx, "#ff4f6d", 0, fy - 120, ww, 60); px(ctx, "#ffffff", 0, fy - 104, ww, 28); ctx.globalAlpha = 1; }
                for (const r of sm.rings) {
                    ctx.globalAlpha = Math.min(1, r.life / 14); ctx.strokeStyle = r.c || "#ffffff"; ctx.lineWidth = 4;
                    ctx.beginPath();
                    if (r.round) ctx.ellipse(r.x - r.r, r.y - r.r, r.r * 2, r.r * 2); else ctx.ellipse(r.x - r.r, r.y - r.r / 3, r.r * 2, r.r / 1.5);
                    ctx.stroke(); ctx.globalAlpha = 1;
                }
                for (const p of sm.parts) {
                    if (p.bmp) { drawBmp(ctx, p.bmp, p.x, p.y, 1, p.rot, 3); continue; }
                    ctx.globalAlpha = Math.min(1, p.life / 10); px(ctx, p.c, p.x, p.y, p.s, p.s);
                }
                ctx.globalAlpha = 1;
                for (const t of sm.floats) {
                    ctx.font = "bold " + (t.big ? 22 : 13) + "px \"" + Theme.fontTitle + "\"";
                    ctx.textAlign = "center";
                    ctx.globalAlpha = Math.min(1, t.life / 10);
                    ctx.fillStyle = dk; ctx.fillText(t.t, t.x + 2, t.y + 2);
                    ctx.fillStyle = t.c; ctx.fillText(t.t, t.x, t.y);
                }
                ctx.globalAlpha = 1;
                ctx.globalAlpha = 1;
                const pt = Date.now() - t0;
                const P = ar.perf; P.pn++; P.psum += pt; if (pt > P.pmax) P.pmax = pt;
            }
            function drawPodium(ctx, rise, fr) {
                const fy = ar.fy, h = Math.round(64 * rise), x = 390, w = 120, A = ar.cAccent.toString(), A2 = ar.cAccent2.toString(), G = "#ffd34d";
                // spotlight on the podium
                ctx.globalAlpha = (0.1 + 0.04 * Math.sin(fr / 5)) * rise; ctx.fillStyle = "#fff6c8";
                ctx.beginPath(); ctx.moveTo(436, 90); ctx.lineTo(464, 90); ctx.lineTo(530, fy); ctx.lineTo(370, fy); ctx.closePath(); ctx.fill();
                ctx.globalAlpha = 0.25 * rise; ctx.beginPath(); ctx.ellipse(360, fy - 10, 180, 22); ctx.fill(); ctx.globalAlpha = 1;
                if (h <= 0) return;
                const y = fy - h;
                px(ctx, dk, x - 4, y - 4, w + 8, h + 4);
                px(ctx, A, x, y, w, h);
                px(ctx, G, x - 4, y - 4, w + 8, 6);          // gold trim
                px(ctx, G, x, fy - 6, w, 6);
                ctx.globalAlpha = 0.3; px(ctx, "#ffffff", x + 4, y + 4, 8, h - 12); ctx.globalAlpha = 1;
                if (h > 40) {
                    ctx.fillStyle = dk; ctx.font = "bold 34px \"" + Theme.fontTitle + "\""; ctx.textAlign = "center"; ctx.fillText("1", 452, y + 46);
                    ctx.fillStyle = G; ctx.fillText("1", 450, y + 44);
                    for (const sx of [x + 22, x + w - 22]) { const tw = Math.floor(fr / 6) % 2; px(ctx, G, sx - 2, y + 22 - 6, 4, 12); px(ctx, G, sx - 6, y + 20, 12, 4); if (tw) { px(ctx, "#ffffff", sx - 1, y + 21, 2, 2); } }
                    ctx.fillStyle = A2; ctx.font = "bold 9px \"" + Theme.fontTitle + "\""; ctx.fillText(ar.g.tourFinal ? "TOURNAMENT" : "CHAMPION", 450, y + 58);
                }
            }
            function drawPodiumFx(ctx, w, l, P, fr) {
                const fy = ar.fy, G = "#ffd34d";
                if (P.st === 2) {
                    const by = fy - w.y - 34;                  // belt round the waist
                    px(ctx, G, w.x - 17, by, 34, 7); px(ctx, "#b8860b", w.x - 17, by + 7, 34, 2);
                    px(ctx, "#fff2a8", w.x - 7, by - 3, 14, 12); px(ctx, G, w.x - 5, by - 1, 10, 8);
                    ctx.globalAlpha = 0.6 + 0.4 * Math.sin(fr / 3); px(ctx, "#ffffff", w.x - 3, by + 1, 3, 3); ctx.globalAlpha = 1;
                    // crown over the head
                    const cy = fy - w.y - 128 + Math.round(Math.sin(fr / 6) * 2);
                    px(ctx, G, w.x - 12, cy + 6, 24, 8); px(ctx, G, w.x - 12, cy, 4, 6); px(ctx, G, w.x - 2, cy - 3, 4, 9); px(ctx, G, w.x + 8, cy, 4, 6);
                    px(ctx, "#ff4f6d", w.x - 1, cy + 8, 3, 3);
                }
                if (l.sit) {                                   // dazed stars over the loser
                    for (let k = 0; k < 3; k++) {
                        const a = fr / 6 + k * 2.1, sx = l.x + Math.cos(a) * 18, sy = fy - l.y - 92 + Math.sin(a) * 5;
                        px(ctx, G, sx - 1, sy - 4, 3, 9); px(ctx, G, sx - 4, sy - 1, 9, 3);
                    }
                }
            }
            function drawRoundGlow(ctx, f, t, fr, back) {
                const fy = ar.fy, k = Math.min(1, t / 6), out = Math.max(0, Math.min(1, (45 - t) / 10)), G = "#ffd34d";
                if (back) {
                    ctx.globalAlpha = 0.35 * k * out; ctx.fillStyle = G;
                    ctx.beginPath(); ctx.ellipse(f.x - 40, fy - 10, 80, 18); ctx.fill();
                    const sh = Math.round(10 * k);           // mini step pops up under the feet
                    ctx.globalAlpha = out; px(ctx, G, f.x - 26, fy - sh, 52, sh); px(ctx, dk, f.x - 26, fy - sh, 52, 2);
                    ctx.globalAlpha = 0.18 * out; for (let r = 0; r < 6; r++) { const a = r / 6 * Math.PI + fr / 20; px(ctx, G, f.x + Math.cos(a) * 46 - 2, fy - 70 - Math.sin(a) * 46, 4, 4); }
                    ctx.globalAlpha = 1; return;
                }
                const ty = fy - f.y - 150 - 10 * k;
                ctx.globalAlpha = out; ctx.font = "bold 14px \"" + Theme.fontTitle + "\""; ctx.textAlign = "center";
                const s = ar.tl("РАУНД ЗА ", "ROUND TO ") + String(f.who.name).toUpperCase().slice(0, 12);
                const tx = Math.max(90, Math.min(810, f.x));
                ctx.fillStyle = dk; ctx.fillText(s, tx + 2, ty + 2); ctx.fillStyle = G; ctx.fillText(s, tx, ty);
                ctx.globalAlpha = 1;
            }
            onImageLoaded: requestPaint()
        }
        }
        // ── fixed overlays (scene graph, no repaint): jumbotron, flash, scanlines, vignette, frame
        Rectangle {
            x: 330; y: 76; width: 240; height: 62
            color: "#1a1a20"; border.width: 3; border.color: ar.cAccent
            Column {
                anchors.centerIn: parent; spacing: 1
                PxText { anchors.horizontalCenter: parent.horizontalCenter; text: ar.jName; color: "#ffe066"; font.bold: true; font.pixelSize: 13 }
                PxText { anchors.horizontalCenter: parent.horizontalCenter; text: ar.jScore; color: "#ff6b6b"; font.bold: true; font.pixelSize: 20 }
                PxText { anchors.horizontalCenter: parent.horizontalCenter; text: ar.jRound; color: ar.cAccent2; font.bold: true; font.pixelSize: 11 }
            }
        }
        Rectangle { anchors.fill: parent; color: ar.flashC; opacity: ar.flashO; visible: opacity > 0 }
        Canvas {
            id: scanCv
            anchors.fill: parent
            opacity: ar.scanO; visible: opacity > 0
            onPaint: {
                const ctx = getContext("2d"); ctx.reset();
                ctx.globalAlpha = 0.1; ctx.fillStyle = "#000000"; for (let y = 6; y < height - 6; y += 3) ctx.fillRect(6, y, width - 12, 1);
                ctx.globalAlpha = 0.12; ctx.fillStyle = "#ff3050"; ctx.fillRect(6, 6, 6, height - 12); ctx.fillStyle = "#30c0ff"; ctx.fillRect(width - 12, 6, 6, height - 12);
            }
        }
        Canvas {
            id: vigCv
            anchors.fill: parent
            opacity: ar.vigO; visible: opacity > 0
            onPaint: {
                const ctx = getContext("2d"); ctx.reset(); ctx.fillStyle = "#000000";
                for (let k = 0; k < 6; k++) {
                    ctx.globalAlpha = 0.09; const m = 6 + k * 8, W = width, H = height;
                    ctx.fillRect(6, 6, W - 12, m); ctx.fillRect(6, H - 6 - m, W - 12, m); ctx.fillRect(6, 6, m, H - 12); ctx.fillRect(W - 6 - m, 6, m, H - 12);
                }
            }
        }
        Rectangle { anchors.fill: parent; anchors.margins: 4; color: "transparent"; border.width: 4; border.color: ar.cAccent }

        Repeater {
            model: 2
            Item {
                id: hud
                required property int index
                readonly property var who: index === 0 ? ar.g.a : ar.g.b
                readonly property real hp: index === 0 ? ar.g.hpA : ar.g.hpB
                readonly property var wp: index === 0 ? ar.g.wa : ar.g.wb
                readonly property real sp: index === 0 ? ar.g.spA : ar.g.spB
                readonly property real gd: index === 0 ? ar.g.gdA : ar.g.gdB
                readonly property bool sdOk: index === 0 ? ar.g.sdA : ar.g.sdB
                x: index === 0 ? 20 : 900 - width - 20
                y: 14
                width: 300; height: ar.g.superOn || ar.g.shieldOn ? 52 : 44
                Rectangle { anchors.fill: parent; color: ar.cFace; border.width: 3; border.color: ar.g.coat(hud.who ? hud.who.id : "") }
                PxText { x: 10; y: 5; text: hud.who ? hud.who.name : ""; color: ar.cText; elide: Text.ElideRight; width: 200 }
                PxText { x: hud.width - width - 10; y: 5; text: Math.round(hud.hp) + " HP"; color: ar.cText }
                Rectangle {
                    x: 10; y: 29; width: hud.width - 20; height: 8; color: ar.cSunken
                    Rectangle {
                        x: hud.index === 1 ? parent.width - width : 0
                        width: parent.width * hud.hp / 100; height: parent.height
                        color: hud.hp > 50 ? ar.cOk : hud.hp > 20 ? "#e0b040" : ar.cDanger
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
                // super meter (fills from hits dealt and taken; gold + pulsing when ready)
                Rectangle {
                    visible: ar.g.superOn
                    x: hud.index === 0 ? 10 : 10 + (ar.g.shieldOn ? 48 : 0); y: 40
                    width: hud.width - 20 - (ar.g.shieldOn ? 48 : 0); height: 5; color: ar.cSunken
                    Rectangle {
                        x: hud.index === 1 ? parent.width - width : 0
                        width: parent.width * hud.sp / 100; height: parent.height
                        color: hud.sp >= 100 ? "#ffd34d" : ar.cAccent2
                        Behavior on width { NumberAnimation { duration: 200 } }
                        SequentialAnimation on opacity { running: hud.sp >= 100; loops: Animation.Infinite; NumberAnimation { to: 0.45; duration: 250 } NumberAnimation { to: 1; duration: 250 } }
                    }
                }
                // shield meter (cyan; bright when ready to block, dim on cooldown / low guard)
                Rectangle {
                    visible: ar.g.shieldOn
                    x: hud.index === 0 ? hud.width - 10 - width : 10; y: 40
                    width: 40; height: 5; color: ar.cSunken
                    border.width: 1; border.color: hud.sdOk ? "#7fe0ff" : "#3a6070"
                    Rectangle {
                        x: hud.index === 1 ? parent.width - width : 0
                        width: parent.width * Math.max(0, Math.min(1, hud.gd / 100)); height: parent.height
                        color: hud.gd < 30 ? "#ff8a3d" : "#7fe0ff"
                        opacity: hud.sdOk ? 1 : 0.45
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }
                Rectangle {
                    x: hud.index === 0 ? 0 : hud.width - width; y: hud.height + 3
                    width: wpT.implicitWidth + 32; height: 22; color: ar.cFace; border.width: 2; border.color: ar.cAccent
                    Rectangle { x: 3; y: 3; width: 16; height: 16; color: "#2b2433" }
                    PxIcon { x: 4; anchors.verticalCenter: parent.verticalCenter; bitmap: hud.wp ? hud.wp.bmp : null; exactPixel: 14 / Math.max(5, hud.wp ? hud.wp.bmp.length : 5); palette: ar.g.wpal }
                    PxText { id: wpT; x: 25; anchors.verticalCenter: parent.verticalCenter; text: hud.wp ? hud.wp.name : ""; color: ar.cText; font.pixelSize: 11 }
                }
            }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter; y: 14
            spacing: 2
            PxText { anchors.horizontalCenter: parent.horizontalCenter; text: ar.tl("РАУНД ", "ROUND ") + Math.max(1, ar.g.round) + (ar.g.rounds ? "/" + ar.g.rounds : ar.tl(" · до KO", " · to KO")); color: ar.cAccent; font.bold: true }
            PxText { anchors.horizontalCenter: parent.horizontalCenter; text: ar.g.timerTxt || (ar.g.phase === "break" ? ar.tl("перерыв", "break") : "—"); color: ar.cText; font.pixelSize: 18; font.bold: true }
            PxText { anchors.horizontalCenter: parent.horizontalCenter; visible: ar.g.rounds !== 1; text: ar.tl("очки ", "score ") + ar.g.scoreTxt; color: ar.cText; opacity: 0.8; font.pixelSize: 11 }
        }
        PxText {
            id: bannerT
            anchors.horizontalCenter: parent.horizontalCenter; y: ar.g.phase === "win" ? 146 : 170
            text: ar.g.banner; visible: text !== ""
            color: ar.g.ko ? ar.cDanger : ar.cText
            font.bold: true; font.pixelSize: ar.g.ko ? 46 : 36
            style: Text.Outline; styleColor: "#2b2433"
            onTextChanged: if (bannerT.text !== "") pulse.restart()
            SequentialAnimation { id: pulse; NumberAnimation { target: bannerT; property: "scale"; from: 2.4; to: 0.9; duration: 220; easing.type: Easing.OutQuad } NumberAnimation { target: bannerT; property: "scale"; to: 1; duration: 120 } }
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter; y: 222
            text: ar.g.finText; visible: text !== "" && (ar.g.phase === "ko" || ar.g.phase === "decision")
            color: ar.cAccent2; font.bold: true; font.pixelSize: 24
            style: Text.Outline; styleColor: "#2b2433"
        }
        PxText {
            visible: ar.g.combo >= 2 && !ar.g.ko && ar.g.phase === "fight"
            x: 700; y: 150
            text: ar.g.combo + ar.tl("× КОМБО", "× COMBO")
            color: ar.cAccent2; font.bold: true; font.pixelSize: 18
            style: Text.Outline; styleColor: "#2b2433"
        }
        component Bubble: Rectangle {
            id: bub
            property string text: ""
            property real tailX: 20
            visible: text !== ""
            width: Math.min(340, bt.implicitWidth + 20)
            height: bt.implicitHeight + 14
            color: "#ffffff"; border.width: 3; border.color: "#2b2433"
            PxText { id: bt; x: 10; y: 7; width: Math.min(320, implicitWidth); text: bub.text; wrapMode: Text.Wrap; color: "#2b2433"; font.pixelSize: 12 }
            Rectangle { x: bub.tailX; y: bub.height - 6; width: 10; height: 10; color: "#ffffff"; rotation: 45 }
        }
        Bubble { x: 16; y: ar.fy - 102 - height - 16; text: ar.g.say; tailX: 26 }
        Bubble { id: bl; x: 70; y: ar.fy - 290 - height; text: ar.g.phase === "break" ? ar.g.sayL : ""; tailX: 40 }
        Bubble { id: brb; x: 900 - width - 70; y: ar.fy - 290 - height; text: ar.g.phase === "break" ? ar.g.sayR : ""; tailX: brb.width - 50 }
        Rectangle {
            visible: ar.g.caption !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: ar.g.phase === "win" ? 512 : 262
            width: Math.min(820, capT.implicitWidth + 24); height: capT.implicitHeight + 12
            color: ar.cFace; border.width: 3; border.color: ar.cDanger
            PxText { id: capT; anchors.centerIn: parent; width: Math.min(796, implicitWidth); wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; text: "♡ " + ar.g.caption + " ♡"; color: ar.cText }
        }
    }
}
