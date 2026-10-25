pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import QtMultimedia
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Crew Fight: two people from the Discord call box in a pixel ring in the middle of the focused
// screen. Fighters come from AngelOS's own Discord crew data (services/DiscordVoice: stock Discord
// via local RPC, Vesktop & co. via the opt-in DevTools bridge, see README); their walking copies are
// hidden meanwhile via Config.discord.crewHidden (ids we add are kept in a state file and taken back
// out on load). Without a call: demo fighters. Everything heavy exists only while a fight is on.
Item {
    id: root
    property var plugin

    // ── one live copy: the newest instance owns the IPC; stale ones (plugin reload) go inert
    readonly property string stateDir: Config.cacheDir + "/crew-fight"
    readonly property string token: String(Date.now()) + "-" + Math.floor(Math.random() * 1e9)
    property bool live: false
    FileView {
        id: ownerFile
        path: root.stateDir + "/owner"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.live = text().trim() === root.token
        onLoadFailed: root.live = false
    }
    onLiveChanged: if (!live) stop()
    function sh(script, args) { Quickshell.execDetached(["sh", "-c", script, "sh"].concat(args)); }
    Component.onCompleted: {
        sh('mkdir -p "$1" && printf %s "$2" > "$1/owner"', [stateDir, token]);
        restoreProc.running = true;
        ownerRecheck.start();
    }
    Timer { id: ownerRecheck; interval: 700; onTriggered: ownerFile.reload() }
    Component.onDestruction: unhide()

    // ── sound: synthesised CC0 one-shots (sounds/, see LICENSES.txt), pooled SoundEffects (low latency)
    // ── settings (Settings → Plugins → Crew Fight, or IPC; stored by AngelOS in settings.json)
    function cfg(k, d) { const v = plugin ? plugin.get(k, d) : d; return v === undefined || v === null ? d : v; }
    readonly property bool soundOn: cfg("sound", true)
    readonly property int soundVol: Math.max(0, Math.min(100, Number(cfg("volume", 50))))
    readonly property string arenaName: String(cfg("arenaName", "") || "").trim() || "CREW ARENA"
    readonly property string scaleSetting: String(cfg("scale", "auto"))
    readonly property bool eco: cfg("eco", false) === true
    readonly property string langSetting: String(cfg("language", "auto"))
    readonly property int defRounds: parseRounds(String(cfg("rounds", 1)))
    readonly property bool crowdShader: cfg("crowdShader", true) !== false
    // gameplay mechanics (Settings → Gameplay): block, super move, arena pickups
    readonly property bool shieldOn: cfg("gpShield", true) !== false
    readonly property bool superOn: cfg("gpSuper", true) !== false
    readonly property bool pickupsOn: cfg("gpPickups", true) !== false
    readonly property string pickupRate: ["rare", "normal", "often"].indexOf(String(cfg("gpPickupRate", "normal"))) >= 0 ? String(cfg("gpPickupRate", "normal")) : "normal"
    // which arena the next fight uses: a culture id, or "random" (rolled once in start)
    readonly property string arenaPick: ["dojo", "desert", "fjord", "plaza", "terem"].indexOf(String(cfg("gpArena", "random"))) >= 0 ? String(cfg("gpArena", "random")) : "random"
    readonly property bool arenaFx: cfg("gpArenaFx", true) !== false
    property string arenaNow: ""
    property bool dbgCharge: false
    property string dbgSpawn: ""
    property string snapEv: ""            // test helper: save the arena (not the screen) as a PNG when these events fire
    property string snapDir: ""
    property int turbo: 1                 // test helper: N simulation steps per tick, no sound
    property string lastResult: ""
    property real spA: 0
    property real spB: 0
    property real gdA: 100
    property real gdB: 100
    property bool sdA: true
    property bool sdB: true
    readonly property string lang: langSetting === "ru" || langSetting === "en" ? langSetting : (Config.appearance.language === "en" ? "en" : "ru")
    readonly property bool en: lang === "en"
    function t(ru, en) { return root.en ? en : ru; }
    // arena size: "auto" fits the 900×560 ring to ~47% × 52% of the screen it opens on, or a percent
    function scaleFor(scr) {
        if (scaleSetting !== "auto" && parseInt(scaleSetting) > 0) return Math.max(0.5, Math.min(3, parseInt(scaleSetting) / 100));
        const w = scr ? scr.width : 1920, h = scr ? scr.height : 1080;
        return Math.max(0.5, Math.min(3, Math.round(Math.min(w * 0.47 / 900, h * 0.52 / 560) * 20) / 20));   // 5% steps
    }
    readonly property real master: soundOn ? Math.pow(soundVol / 100, 2) : 0
    readonly property var sfxNames: ["punch", "slap", "crack", "homerun", "splat", "feedback", "boom", "clack", "keys", "thud", "zap", "whoosh", "crit", "ko", "gong", "bell", "cheer", "sting", "fanfare", "swoosh", "blip", "block", "parry", "supercharge", "super", "heal", "boost", "fuse", "drop"]
    property var sfxLast: ({})
    function sfx(name, gain) {
        if (!soundOn || soundVol <= 0 || turbo > 1) return;
        const it = sfxRep.itemAt(sfxNames.indexOf(name));
        if (!it) return;
        const now = Date.now();
        if (now - (sfxLast[name] || 0) < 45) return;
        sfxLast[name] = now;
        const e = it.next();
        e.volume = Math.min(1, master * (gain === undefined ? 1 : gain));
        e.play();
    }
    function setCfg(k, v) { if (plugin) plugin.set(k, v); return v; }
    function setSound(on, vol) {
        const o = on === undefined ? soundOn : on, v = vol === undefined ? soundVol : Math.max(0, Math.min(100, vol));
        if (on !== undefined) setCfg("sound", o);
        if (vol !== undefined) setCfg("volume", v);
        return "sound " + (o ? "on" : "off") + ", volume " + v;
    }
    Repeater {
        id: sfxRep
        model: root.sfxNames
        Item {
            id: pool
            required property string modelData
            property int k: 0
            function next() { k = (k + 1) % 3; return [e0, e1, e2][k]; }
            SoundEffect { id: e0; source: Qt.resolvedUrl("sounds/" + pool.modelData + ".wav") }
            SoundEffect { id: e1; source: Qt.resolvedUrl("sounds/" + pool.modelData + ".wav") }
            SoundEffect { id: e2; source: Qt.resolvedUrl("sounds/" + pool.modelData + ".wav") }
        }
    }
    // crowd ambience while the arena is up; louder with the hype
    property real crowdLvl: 0.5
    SoundEffect {
        source: Qt.resolvedUrl("sounds/crowd.wav")
        loops: SoundEffect.Infinite
        volume: Math.min(1, root.master * (0.35 + 0.45 * root.crowdLvl))
        readonly property bool want: root.on && root.soundOn && root.soundVol > 0
        onWantChanged: want ? play() : stop()
    }

    // ── hiding the fighters' walking copies
    property var added: []           // ids we put into crewHidden
    function hideFighters(ids) {
        const list = (Config.discord.crewHidden || []).slice();
        const add = ids.filter(id => /^\d+$/.test(id) && list.indexOf(id) < 0);
        if (!add.length) return;
        added = added.concat(add);
        Config.discord.crewHidden = list.concat(add);
        sh('mkdir -p "$1" && printf %s "$2" > "$1/hidden.json"', [stateDir, JSON.stringify({ "added": added })]);
    }
    function unhide() {
        dropIds(added);
        added = [];
        sh('rm -f "$1/hidden.json"', [stateDir]);
    }
    function dropIds(ids) {
        if (!ids || !ids.length) return;
        const list = (Config.discord.crewHidden || []).filter(x => ids.indexOf(x) < 0);
        if (list.length !== (Config.discord.crewHidden || []).length)
            Config.discord.crewHidden = list;
    }
    // a crash / reload mid-fight left ids in crewHidden: take them back out
    Process {
        id: restoreProc
        command: ["cat", root.stateDir + "/hidden.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (!root.on) {
                        root.dropIds(j.added || []);
                        root.sh('rm -f "$1/hidden.json"', [root.stateDir]);
                    }
                } catch (e) {}
            }
        }
    }

    // ── people
    readonly property var coats: ["#e8668b", "#6ec3e8", "#f0b44c", "#8bd17c", "#b48cf0", "#f08a5d", "#5dd6c0", "#e0e070"]
    function coat(id) {
        let h = 0;
        for (const c of String(id))
            h = (h * 31 + c.charCodeAt(0)) >>> 0;
        return coats[h % coats.length];
    }
    readonly property var fakeNames: en ? ["Kitty", "Floppa", "Dumpling", "Toaster", "Penguin"] : ["Котик", "Шлёпа", "Пельмень", "Тостер", "Пингвин"]
    readonly property var fakes: fakeNames.map((n, i) => ({ "id": "f" + (i + 1), "name": n, "avatar": "" }))
    // the crew feature (Settings → Discord → crew) runs AngelOS's Discord reader; without it no call data
    readonly property bool crewOn: !!Config.discord.crew
    readonly property string crewHint: !crewOn ? t("«Человечки из звонка Discord» в AngelOS выключены (ПКМ по рабочему столу → виджеты) — демо-бойцы.", "AngelOS “Little People from the Discord Call” is off (desktop right-click → widgets) — demo fighters.")
        : DiscordVoice.state === "call" ? ""
        : DiscordVoice.state === "rpc-only" ? t("Vesktop/arRPC: звонок не виден — включи мост AngelOS (порт DevTools в ~/.config/angelos/discord-voice.json). Пока демо.", "Vesktop/arRPC: call not visible — enable the AngelOS voice bridge (DevTools port in ~/.config/angelos/discord-voice.json). Demo for now.")
        : DiscordVoice.state === "auth" || DiscordVoice.state === "authorizing" ? t("Разреши доступ angelOS в окне Discord. Пока демо.", "Allow AngelOS in the Discord prompt. Demo for now.")
        : DiscordVoice.state === "no-discord" ? t("Discord не запущен — демо-бойцы.", "Discord isn't running — demo fighters.")
        : t("Ты не в голосовом канале — демо-бойцы.", "You're not in a voice channel — demo fighters.")
    readonly property var people: (DiscordVoice.state === "call" ? DiscordVoice.users || [] : []).filter(u => (Config.discord.crewHidden || []).indexOf(u.id) < 0 || added.indexOf(u.id) >= 0)

    readonly property var endingsEn: [
        "%W won. %L left the voice chat in shame",
        "%L was disconnected from the server. Reason: %W",
        "%W: GG EZ. %L: “I was lagging”",
        "%L went AFK forever",
        "Moderators approve: %W",
        "%L is now morally muted",
        "%W carried it %WI. %L is shocked",
        "%L couldn't handle %WI",
        "Victory sponsored by: %WN"
    ]
    readonly property var endings: en ? endingsEn : endingsRu
    readonly property var endingsRu: [
        "%W победил(а). %L вышел из голосового с позором",
        "%L отключён(а) от сервера. Причина: %W",
        "%W: GG EZ. %L: «у меня лагало»",
        "%L ушёл(ла) в AFK навсегда",
        "Модераторы одобряют: %W",
        "%L теперь мьютнут(а) морально",
        "%W затащил(а) %WI. %L в шоке",
        "%L не выдержал(а) %WI",
        "Спонсор победы: %WN"
    ]
    // weapons: cd = cooldown factor, dmg = [min,max], kb = knockback, crit = chance, range in px,
    // w = weight for random rolls. Bitmaps: handle at the bottom, colour letters see wcol().
    // English strings per weapon: name, ins ("with …"), words, fin, moves {id: [name, words]}
    readonly property var weaponsEnText: ({
        "fists": { "name": "fists", "ins": "with fists", "fin": "HOOK KNOCKOUT", "words": ["bam!", "pow!", "hook!", "uppercut!"],
                   "moves": { "jab": ["jab", ["bam!", "pow!"]], "uppercut": ["uppercut", ["UPPERCUT!", "on the chin!"]], "flurry": ["flurry", ["ta-ta-ta!"]] } },
        "slipper": { "name": "slipper", "ins": "with a slipper", "fin": "SLIPPER VERDICT", "words": ["SLAP!", "SMACK!", "slipper to the face!", "mom's strike!"],
                   "moves": { "slap": ["slap", ["SLAP!", "SMACK!"]], "flurry": ["slipper storm", ["slap-slap-slap!", "right in the butt!"]], "boomerang": ["slipper boomerang", ["FLYING SLIPPER!", "mom's throw!"]] } },
        "bat": { "name": "bat", "ins": "with a bat", "fin": "HOME RUN! GONE!", "words": ["BONK!", "HOME RUN!", "THWACK!", "out!"],
                   "moves": { "swing": ["swing", ["THWACK!", "BONK!"]], "smash": ["overhead smash", ["BONK FROM ABOVE!", "on the head!"]], "homerun": ["home run", ["HOME RUN!", "out of the park!"]] } },
        "fish": { "name": "fish", "ins": "with a fish", "fin": "FISH DAY", "words": ["SPLOSH!", "fish to the face!", "smells...", "fresh!"],
                   "moves": { "slap": ["fish slap", ["SPLOSH!", "in the face!"]], "flop": ["flopping fish", ["FLOP!", "fish at your feet!"]], "whack": ["fish overhead", ["fresh!", "smells..."]] } },
        "mic": { "name": "microphone", "ins": "with a microphone", "fin": "MIC DROP", "words": ["*FEEDBACK*", "EEEEEH!", "one-two!", "ASMR attack!"],
                   "moves": { "wave": ["sound wave", ["*FEEDBACK*", "EEEEEH!"]], "feedback": ["feedback", ["SKREEEEE!", "ASMR attack!"]], "bonk": ["mic to the forehead", ["one-two!", "mic check!"]] } },
        "keyboard": { "name": "keyboard", "ins": "with a keyboard", "fin": "ALT+F4", "words": ["CTRL+ALT+DEL!", "WASD!", "ALT+F4!", "caps lock!"],
                   "moves": { "whack": ["keyboard to the head", ["CTRL+ALT+DEL!", "ALT+F4!"]], "spray": ["key rain", ["clack!"]], "space": ["spacebar smash", ["SPACE!", "[    SPACE    ]"]] } },
        "bread": { "name": "baguette", "ins": "with a baguette", "fin": "TOASTED", "words": ["CRUNCH!", "sliced strike!", "crumbs!", "bread is life!"],
                   "moves": { "whack": ["baguette whack", ["CRUNCH!", "sliced strike!"]], "eat": ["snack", ["nom"]], "throw": ["baguette boomerang", ["FLYING BREAD!", "bread is life!"]] } },
        "laser": { "name": "laser pointer", "ins": "with a laser pointer", "fin": "LASER MAX", "words": ["PEW-PEW!", "LASER!", "VZZZT!", "certified laser!"],
                   "moves": { "beam": ["charged beam", ["PEW-PEW!", "VZZZT!"]], "eyes": ["laser eyes", ["LASER EYES!", "PEW!"]], "whip": ["handle jab", ["laser poke!"]] } }
    })
    function localizeWeapon(w) {
        const e = weaponsEnText[w.id];
        if (!e) return w;
        const o = Object.assign({}, w);
        o.name = e.name; o.ins = e.ins; o.words = e.words;
        o.fin = Object.assign({}, w.fin, { "t": e.fin });
        o.moves = w.moves.map(m => { const t = e.moves[m.id]; return t ? Object.assign({}, m, { "n": t[0], "w": t[1] }) : m; });
        return o;
    }
    readonly property var weapons: en ? weaponsRu.map(w => localizeWeapon(w)) : weaponsRu
    readonly property var weaponsRu: [
        { "id": "fists", "moves": [{"id": "jab", "n": "джеб", "k": "swing", "w": ["бам!", "пум!"]}, {"id": "uppercut", "n": "апперкот", "k": "overhead", "dm": 1.3, "kb": 1.2, "vy": 12, "w": ["АППЕРКОТ!", "в челюсть!"]}, {"id": "flurry", "n": "серия", "k": "flurry", "dm": 0.45, "kb": 0.4, "w": ["тыщ-тыщ-тыщ!"], "nh": 4}], "fin": {"t":"НОКАУТ ХУКОМ","fx":"stars"}, "name": "кулаки", "ins": "кулаками", "cd": 1, "dmg": [6, 14], "kb": 1, "crit": 0.18, "range": 86, "w": 3,
          "words": ["бам!", "пум!", "хук!", "апперкот!"], "cols": ["#ffe066", "#ffffff"],
          "bmp": [".rrr.", "rrrrr", "rrrrr", "rwrrr", ".rrr.", ".ddd."] },
        { "id": "slipper", "moves": [{"id": "slap", "n": "шлепок", "k": "swing", "w": ["ШЛЁП!", "ШМЯК!"]}, {"id": "flurry", "n": "тапочный шквал", "k": "flurry", "dm": 0.5, "kb": 0.35, "w": ["шлёп-шлёп-шлёп!", "по жопе!"], "nh": 4}, {"id": "boomerang", "n": "тапок-бумеранг", "k": "throw", "r": 300, "dm": 1.1, "w": ["ЛЕТИТ ТАПОК!", "мамин бросок!"]}], "fin": {"t":"ТАПОЧНЫЙ ПРИГОВОР","fx":"rain"}, "name": "тапок", "ins": "тапком", "cd": 0.55, "dmg": [4, 9], "kb": 0.7, "crit": 0.15, "range": 90, "w": 3,
          "words": ["ШЛЁП!", "ШМЯК!", "тапком по лбу!", "мамин удар!"], "cols": ["#ffffff", "a"],
          "bmp": [".aaa.", "aaaaa", "awwwa", "aaaaa", "aaaaa", ".aaa.", ".aaa.", ".aaa.", ".aaa."] },
        { "id": "bat", "moves": [{"id": "swing", "n": "замах", "k": "swing", "w": ["ТУЦ!", "БОНК!"]}, {"id": "smash", "n": "удар сверху", "k": "overhead", "dm": 1.25, "kb": 0.6, "shake": 6, "w": ["БОНК СВЕРХУ!", "в темечко!"]}, {"id": "homerun", "n": "хоумран", "k": "homerun", "dm": 1.1, "kb": 2.2, "vy": 10, "t": 12, "w": ["ХОУМРАН!", "в аут!"]}], "fin": {"t":"ХОУМРАН! УЛЕТЕЛ!","fx":"launch"}, "name": "бита", "ins": "битой", "cd": 1.7, "dmg": [11, 21], "kb": 1.9, "crit": 0.12, "range": 104, "w": 3,
          "words": ["БОНК!", "ХОУМРАН!", "ТУЦ!", "в аут!"], "cols": ["#c98a4b", "#ffffff"],
          "bmp": [".n.", "nnn", "nnn", "nnn", "nnn", "nnn", ".n.", ".n.", ".n.", ".n.", ".d.", ".d.", ".d."] },
        { "id": "fish", "moves": [{"id": "slap", "n": "рыбья пощёчина", "k": "swing", "w": ["ХЛЮП!", "по щам!"]}, {"id": "flop", "n": "рыба-попрыгунья", "k": "flop", "r": 260, "dm": 0.9, "w": ["ПЛЮХ!", "рыба в ногах!"]}, {"id": "whack", "n": "рыбный удар сверху", "k": "overhead", "dm": 1.2, "w": ["свежак!", "пахнет..."]}], "fin": {"t":"РЫБНЫЙ ДЕНЬ","fx":"rain"}, "name": "рыба", "ins": "рыбой", "cd": 1, "dmg": [5, 12], "kb": 0.9, "crit": 0.15, "range": 92, "w": 3, "stun": 0.3,
          "words": ["ХЛЮП!", "рыбой по щам!", "пахнет...", "свежак!"], "cols": ["#6ec3e8", "#ffffff"],
          "bmp": ["..c..", ".ccc.", "ckccc", "ccccc", "cwccc", "ccccc", ".ccc.", "..c..", ".ccc.", "c.c.c"] },
        { "id": "mic", "moves": [{"id": "wave", "n": "звуковая волна", "k": "wave", "r": 280, "w": ["*ФОНИТ*", "ЭЭЭЭЭ!"]}, {"id": "feedback", "n": "фидбэк", "k": "wave", "r": 280, "big": true, "dm": 1.4, "t": 14, "w": ["ПИИИИИИ!", "ASMR-атака!"]}, {"id": "bonk", "n": "микрофоном по лбу", "k": "swing", "w": ["раз-раз!", "проверка связи!"]}], "fin": {"t":"MIC DROP","fx":"micdrop"}, "name": "микрофон", "ins": "микрофоном", "cd": 1.25, "dmg": [5, 11], "kb": 0.8, "crit": 0.15, "range": 240, "w": 3, "ranged": true,
          "words": ["*ФОНИТ*", "ЭЭЭЭЭ!", "раз-раз!", "ASMR-атака!"], "cols": ["b", "#ffffff"],
          "bmp": ["sss", "sgs", "sss", "sgs", "sss", ".k.", ".k.", ".k.", ".k."] },
        { "id": "keyboard", "moves": [{"id": "whack", "n": "клавой по голове", "k": "swing", "w": ["CTRL+ALT+DEL!", "ALT+F4!"]}, {"id": "spray", "n": "дождь клавиш", "k": "spray", "r": 250, "w": ["клац!"]}, {"id": "space", "n": "удар пробелом", "k": "spacebar", "dm": 1.3, "kb": 1.2, "w": ["ПРОБЕЛ!", "[    SPACE    ]"]}], "fin": {"t":"ALT+F4","fx":"altf4"}, "name": "клавиатура", "ins": "клавиатурой", "cd": 1.15, "dmg": [3, 6], "hits": [2, 3], "kb": 0.8, "crit": 0.12, "range": 96, "w": 3, "keys": true,
          "words": ["CTRL+ALT+DEL!", "WASD!", "ALT+F4!", "капслок!"], "cols": ["#ffffff", "b"],
          "bmp": ["kkk", "wkw", "kwk", "wkw", "kwk", "wkw", "kwk", "wkw", "kak", "kkk"] },
        { "id": "bread", "moves": [{"id": "whack", "n": "батоном", "k": "swing", "w": ["ХРУСТ!", "нарезной удар!"]}, {"id": "eat", "n": "перекус", "k": "eat", "t": 16, "w": ["ням"]}, {"id": "throw", "n": "батон-бумеранг", "k": "throw", "r": 290, "w": ["ЛЕТИТ БАТОН!", "хлеб всему голова!"]}], "fin": {"t":"ХЛЕБНУЛ ГОРЯ","fx":"crumbs"}, "name": "батон", "ins": "батоном", "cd": 1, "dmg": [6, 12], "kb": 1, "crit": 0.15, "range": 98, "w": 3, "heal": 3,
          "words": ["ХРУСТ!", "нарезной удар!", "крошки!", "хлеб всему голова!"], "cols": ["#e0b060", "#8a5a2b"],
          "bmp": [".y.", "yny", "yyy", "yny", "yyy", "yny", "yyy", "yny", "yyy", ".y."] },
        { "id": "laser", "moves": [{"id": "beam", "n": "заряженный луч", "k": "beam", "r": 320, "t": 26, "dm": 1.3, "w": ["ПИУУУУ!", "ВЖЖЖ!"]}, {"id": "eyes", "n": "глаза-лазеры", "k": "eyeblast", "r": 320, "t": 14, "w": ["ГЛАЗА-ЛАЗЕРЫ!", "ПИУ!"]}, {"id": "whip", "n": "рукояткой", "k": "swing", "w": ["тык лазером!"]}], "fin": {"t":"ЛАЗЕР НА МАКСИМУМ","fx":"maxbeam"}, "name": "лазер-указка", "ins": "лазером-указкой", "cd": 1.35, "dmg": [4, 9], "kb": 1.1, "crit": 0.45, "critMul": 2.3, "range": 300, "w": 1, "beam": true,
          "words": ["ПИУ-ПИУ!", "ЛАЗЕР!", "ВЖЖЖ!", "сертифицированный лазер!"], "cols": ["#ff4f6d", "a"],
          "bmp": ["..r..", "..r..", ".rar.", ".aaa.", "aabaa", "aaaaa", ".dd..", ".dd.."] }
    ]
    function wcol(ch) {
        return ({ "a": String(Theme.accent), "b": String(Theme.accent2), "d": "#2b2433", "k": "#1a1a20", "w": "#ffffff", "r": "#e04848",
                  "y": "#e0b060", "n": "#8a5a2b", "g": "#7a7a88", "s": "#c8c8d4", "c": "#6ec3e8" })[ch] || "#ff00ff";
    }
    function weapon(id) {
        id = String(id || "").toLowerCase();
        const w = weapons.find(x => x.id === id || x.name === id);
        if (w) return w;
        let t = Math.random() * weapons.reduce((a, x) => a + x.w, 0);
        for (const x of weapons) { t -= x.w; if (t <= 0) return x; }
        return weapons[0];
    }
    readonly property var wpal: ({ "a": Theme.accent, "b": Theme.accent2, "d": "#2b2433", "k": "#1a1a20", "w": "#ffffff", "r": "#e04848",
                                    "y": "#e0b060", "n": "#8a5a2b", "g": "#7a7a88", "s": "#c8c8d4", "c": "#6ec3e8" })
    property var wa: null
    property var wb: null
    function rnd(xs) { return xs[Math.floor(Math.random() * xs.length)]; }

    // ── fight state (QML-visible bits; the rest lives in `sim`)
    property bool on: false
    property var a: null
    property var b: null
    property real hpA: 100
    property real hpB: 100
    property string banner: ""
    property string caption: ""
    property int combo: 0
    property string lastHit: ""
    property string comboWho: ""
    property bool ko: false
    property var sim: null
    // rounds: 1 / 3 / 5, 0 = до нокаута
    property int rounds: 3
    property int round: 0
    property string phase: ""
    property string timerTxt: ""
    property string scoreTxt: "0 : 0"
    property string finText: ""
    property string perf: ""
    property string moveStat: ""
    property string say: ""
    property real sayT: 0
    property string sayL: ""
    property string sayR: ""
    function parseRounds(r) {
        r = String(r === undefined ? "" : r).toLowerCase();
        if (r === "ko" || r === "0" || r.indexOf("нок") >= 0) return 0;
        const n = parseInt(r);
        return n > 0 ? Math.min(12, n) : 1;
    }

    function rollArena() {
        const ids = ["dojo", "desert", "fjord", "plaza", "terem"];
        const want = String(arenaPick || "random");
        arenaNow = ids.indexOf(want) >= 0 ? want : ids[Math.floor(Math.random() * ids.length)];
        console.info("crew-fight arena " + arenaNow + (arenaFx ? " fx" : " visual"));
        return arenaNow;
    }
    function start(x, y, ka, kb, rr, inTour) {
        if (!live) return "stale copy";
        if (!x || !y || x.id === y.id) return "need two different fighters";
        if (inTour) { on = false; sim = null; } else stop();
        wa = weapon(ka); wb = weapon(kb); lastHit = "";
        rounds = rr === undefined ? defRounds : parseRounds(rr);
        round = 0; phase = "intro"; timerTxt = ""; scoreTxt = "0 : 0"; finText = ""; say = ""; sayL = ""; sayR = "";
        a = x; b = y; hpA = 100; hpB = 100; spA = 0; spB = 0; gdA = 100; gdB = 100; sdA = true; sdB = true; lastResult = ""; caption = ""; combo = 0; ko = false;
        banner = "";
        picking = false;
        matchWinner = -1;
        const arena = rollArena();
        if (!inTour) hideFighters([x.id, y.id]);
        on = true;
        return "fight: " + x.name + " (" + wa.name + ") vs " + y.name + " (" + wb.name + "), " + (rounds ? rounds + " rounds" : "to KO") + ", arena " + arena;
    }
    function stop() {
        tourOn = false; tourBracket = false; tourFinal = false; tourStage = ""; tourNext = ""; bracketTimer.stop();
        picking = false;
        on = false;
        sim = null;
        unhide();
    }
    // the arena finished its fade-out: plain match → stop; tournament → record the winner, show the bracket
    function finishMatch() {
        if (!tourOn || !curMatch) { stop(); return; }
        on = false; sim = null;
        curMatch.w = matchWinner < 0 ? 0 : matchWinner;
        tour.last = curPos;
        tourAdvance();
        const last = tour.rounds[tour.rounds.length - 1][0];
        if (last.w >= 0) tour.champion = last.w === 0 ? last.a : last.b;
        curMatch = null; tourFinal = false; tourStage = "";
        showBracket();
    }

    // ── tournament: single elimination, random seeding, byes in the first round
    property bool tourOn: false
    property var tour: null
    property int tourRev: 0
    property bool tourBracket: false
    property bool tourFinal: false
    property string tourStage: ""
    property int tourMatchNo: 0
    property string tourNext: ""
    property var curMatch: null
    property var curPos: null
    property int matchWinner: -1
    property int tourMatchRounds: 1
    property int tourFinalRounds: 1
    readonly property var extraFakes: en ? ["Sigma", "Noob", "Lagger", "Moderator", "Schrödinger", "Glitch", "Pixel", "Muffin", "Turbo", "Captain", "Waffle"]
                                         : ["Сигма", "Кринжик", "Нубас", "Лагун", "Модератор", "Шрёдингер", "Глитч", "Пиксель", "Кексик", "Турбо", "Капитан"]
    function shuffle(a) { a = a.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); const t = a[i]; a[i] = a[j]; a[j] = t; } return a; }
    function fakePool(n) {
        const out = fakes.slice();
        for (let i = 0; out.length < n && i < extraFakes.length; i++) out.push({ "id": "x" + i, "name": extraFakes[i], "avatar": "" });
        return out.slice(0, Math.max(2, Math.min(16, n)));
    }
    function stageName(r) {
        const left = tour.rounds.length - r;
        return left === 1 ? t("ФИНАЛ", "FINAL") : left === 2 ? t("Полуфинал", "Semifinal") : left === 3 ? t("Четвертьфинал", "Quarterfinal") : t("1/" + Math.pow(2, left - 1) + " финала", "Round of " + Math.pow(2, left));
    }
    // rr: "<match rounds>/<final rounds>", e.g. "1/3", "3", "ko/5"
    function startTour(pool, rr, demo) {
        if (!live) return "stale copy";
        stop();
        const ps = shuffle(pool).slice(0, 16);
        if (ps.length < 2) return "need 2+ fighters";
        const parts = String(rr || "").split("/");
        tourMatchRounds = parts[0] !== "" && parts[0] !== undefined ? parseRounds(parts[0]) : 1;
        tourFinalRounds = parts.length > 1 && parts[1] !== "" ? parseRounds(parts[1]) : tourMatchRounds;
        const players = ps.map(p => ({ "id": p.id, "name": p.name, "avatar": p.avatar || "", "wep": weapon("random").id }));
        let P = 1; while (P < players.length) P *= 2;
        const r0 = []; let i = 0;
        for (let k = 0; k < P - players.length; k++) r0.push({ "a": players[i++], "b": null, "w": -1 });
        while (i < players.length) r0.push({ "a": players[i++], "b": players[i++], "w": -1 });
        const rounds = [shuffle(r0)];
        for (let m = r0.length; m > 1; ) { m /= 2; const rr2 = []; for (let k = 0; k < m; k++) rr2.push({ "a": null, "b": null, "w": -1 }); rounds.push(rr2); }
        tour = { "rounds": rounds, "players": players, "demo": !!demo, "champion": null, "last": null };
        tourMatchNo = 0;
        tourAdvance();
        hideFighters(players.map(p => p.id));
        tourOn = true;
        showBracket();
        return "tournament: " + players.length + " fighters (" + players.map(p => p.name + ":" + p.wep).join(", ") + "), bracket " + P + ", matches " + (tourMatchRounds || "KO") + " rounds, final " + (tourFinalRounds || "KO");
    }
    function tourAdvance() {
        const R = tour.rounds;
        for (let r = 0; r < R.length; r++)
            for (let i = 0; i < R[r].length; i++) {
                const m = R[r][i];
                if (r === 0 && m.w < 0 && m.a && !m.b) m.w = 0;          // bye
                if (m.w >= 0 && r + 1 < R.length) { const nx = R[r + 1][i >> 1]; if (i % 2) nx.b = m.w === 0 ? m.a : m.b; else nx.a = m.w === 0 ? m.a : m.b; }
            }
        tourRev++;
    }
    function nextMatch() {
        const R = tour.rounds;
        for (let r = 0; r < R.length; r++) for (let i = 0; i < R[r].length; i++) { const m = R[r][i]; if (m.w < 0 && m.a && m.b) return { "r": r, "i": i, "m": m }; }
        return null;
    }
    function showBracket() {
        const nm = nextMatch();
        tourNext = nm ? (nm.r === tour.rounds.length - 1 ? t("ФИНАЛ: ", "FINAL: ") : stageName(nm.r) + ": ") + nm.m.a.name + " vs " + nm.m.b.name : "";
        tourRev++;
        tourBracket = true;
        bracketTimer.interval = nm ? 5500 : 8000;
        bracketTimer.restart();
    }
    Timer {
        id: bracketTimer
        onTriggered: {
            if (!root.tourOn) return;
            const nm = root.nextMatch();
            if (!nm) { root.stop(); return; }
            root.tourBracket = false;
            root.tourFinal = nm.r === root.tour.rounds.length - 1;
            root.tourStage = root.stageName(nm.r);
            root.tourMatchNo++;
            root.curMatch = nm.m; root.curPos = { "r": nm.r, "i": nm.i };
            root.start(nm.m.a, nm.m.b, nm.m.a.wep, nm.m.b.wep, String(root.tourFinal ? root.tourFinalRounds : root.tourMatchRounds), true);
        }
    }
    function tourJson() {
        if (!tour) return null;
        return { "on": tourOn, "bracket": tourBracket, "stage": tourStage, "final": tourFinal, "next": tourNext, "match": tourMatchNo,
                 "champion": tour.champion ? tour.champion.name : "",
                 "rounds": tour.rounds.map((rd, r) => rd.map(m => (m.a ? m.a.name : "—") + (m.w === 0 ? "*" : "") + " vs " + (m.b ? m.b.name : (r === 0 && m.a ? "bye" : "—")) + (m.w === 1 ? "*" : ""))) };
    }

    function find(q, pool) {
        q = String(q).toLowerCase();
        return pool.find(p => p.id === q) || pool.find(p => String(p.name).toLowerCase() === q) || pool.find(p => String(p.name).toLowerCase().indexOf(q) >= 0);
    }
    function randomPair(pool) {
        if (pool.length < 2) return null;
        const i = Math.floor(Math.random() * pool.length);
        let j = Math.floor(Math.random() * (pool.length - 1));
        if (j >= i) j++;
        return [pool[i], pool[j]];
    }

    // ── picker
    property bool picking: false
    property bool pickDemo: false
    property var first: null
    property var second: null
    property string wpA: "random"
    property string wpB: "random"
    property int pickRounds: 1
    property string pickShot: ""
    Timer { running: root.picking; interval: 45000; onTriggered: root.picking = false }
    function openPicker() {
        if (!live) return "stale copy";
        first = null; second = null; wpA = "random"; wpB = "random";
        pickRounds = defRounds;
        pickDemo = people.length < 2;
        picking = true;
        return pickDemo ? "picker (demo: fewer than 2 in call)" : "picker";
    }

    IpcHandler {
        target: "crewfight"
        enabled: root.live
        function pick(): string { return root.openPicker(); }
        function demo(): string { const p = root.randomPair(root.fakes); return root.start(p[0], p[1]); }
        function random(): string {
            const p = root.randomPair(root.people);
            return p ? root.start(p[0], p[1]) : "fewer than 2 people in the call (try: demo)" + (root.crewHint ? " — " + root.crewHint : "");
        }
        // weapons: id from `weapons`, or "" / "random"
        function fight(x: string, y: string, weaponA: string, weaponB: string): string {
            const pool = root.people.concat(root.fakes);
            return root.start(root.find(x, pool), root.find(y, pool), weaponA, weaponB);
        }
        // two names, random weapons (qs ipc has no optional arguments)
        function brawl(x: string, y: string): string { return fight(x, y, "random", "random"); }
        // the picker with fighters / weapons already chosen (still needs «В бой!»)
        function pickWith(x: string, y: string, weaponA: string, weaponB: string): string {
            const r = root.openPicker();
            const pool = root.pickDemo ? root.fakes : root.people;
            root.first = root.find(x, pool) || null; root.second = root.find(y, pool) || null;
            root.wpA = weaponA || "random"; root.wpB = weaponB || "random";
            return r;
        }
        // rounds: 1 / 3 / 5 / ko
        function match(x: string, y: string, weaponA: string, weaponB: string, rounds: string): string {
            const pool = root.people.concat(root.fakes);
            return root.start(root.find(x, pool), root.find(y, pool), weaponA, weaponB, rounds);
        }
        function demoMatch(rounds: string): string { const p = root.randomPair(root.fakes); return root.start(p[0], p[1], "random", "random", rounds); }
        function pickMatch(x: string, y: string, weaponA: string, weaponB: string, rounds: string): string {
            const r = pickWith(x, y, weaponA, weaponB);
            root.pickRounds = root.parseRounds(rounds);
            return r;
        }
        function weapons(): string {
            return root.weapons.map(w => w.id + " — " + w.name + (w.w < 2 ? root.t(" (редкое)", " (rare)") : "")).join("\n");
        }
        function stop(): void { root.stop(); }
        // gameplay mechanics: on | off | toggle (persisted like the settings page)
        function shield(v: string): string { const o = v === "toggle" ? !root.shieldOn : v !== "off" && v !== "0"; root.setCfg("gpShield", o); return "shield " + (o ? "on" : "off"); }
        function superMove(v: string): string { const o = v === "toggle" ? !root.superOn : v !== "off" && v !== "0"; root.setCfg("gpSuper", o); return "super " + (o ? "on" : "off"); }
        function pickups(v: string): string { const o = v === "toggle" ? !root.pickupsOn : v !== "off" && v !== "0"; root.setCfg("gpPickups", o); return "pickups " + (o ? "on" : "off"); }
        function pickupRate(v: string): string { const r = v === "rare" || v === "often" ? v : "normal"; root.setCfg("gpPickupRate", r); return "pickup rate " + r; }
        function gameplay(v: string): string { const o = v !== "off" && v !== "0"; root.setCfg("gpShield", o); root.setCfg("gpSuper", o); root.setCfg("gpPickups", o); return "shield+super+pickups " + (o ? "on" : "off"); }
        // arena: random | dojo | desert | fjord | plaza | terem ; mechanics: on | off | toggle
        function arena(v: string): string { const ids = ["random", "dojo", "desert", "fjord", "plaza", "terem"]; const a = ids.indexOf(v) >= 0 ? v : "random"; root.setCfg("gpArena", a); return "arena " + a; }
        function arenaFx(v: string): string { const o = v === "toggle" ? !root.arenaFx : v !== "off" && v !== "0"; root.setCfg("gpArenaFx", o); return "arena fx " + (o ? "on" : "off"); }
        // test helpers (not in the README): turbo N = N sim steps per tick, silent
        function charge(): string { root.dbgCharge = true; return "super meters filled"; }
        function spawn(kind: string): string { root.dbgSpawn = kind || "heal"; return "spawn " + kind; }
        function snap(ev: string, dir: string): string { root.snapEv = ev; root.snapDir = dir; return "snap " + ev + " -> " + dir; }
        function turbo(n: string): string { root.turbo = Math.max(1, Math.min(60, parseInt(n) || 1)); return "turbo " + root.turbo; }
        // test helper (not in the README): open the picker on demo fighters and save the card
        function pickShot(path: string): string {
            const r = root.openPicker();
            root.pickDemo = true;
            root.first = root.fakes[0];
            root.second = root.fakes[1];
            root.wpA = "fists";
            root.wpB = "slipper";
            root.pickShot = String(path || "");
            return r + " shot";
        }
        // sound: on | off | toggle ; volume: 0-100 (persisted)
        function sound(state: string): string { return root.setSound(state === "toggle" ? !root.soundOn : state !== "off" && state !== "0"); }
        function volume(v: string): string { return root.setSound(undefined, parseInt(v) || 0); }
        // settings over IPC (persisted like the settings page): rounds 1|3|5|ko, arena name, scale auto|50-300, eco on|off, language auto|ru|en, shader on|off
        function rounds(v: string): string { root.setCfg("rounds", root.parseRounds(v)); return "rounds " + (root.parseRounds(v) || "ko"); }
        function arenaName(name: string): string { root.setCfg("arenaName", String(name).slice(0, 24)); return "arena " + (String(name).trim() || "CREW ARENA"); }
        function scale(v: string): string { const a = v === "auto" || !(parseInt(v) > 0) ? "auto" : String(Math.max(50, Math.min(300, parseInt(v)))); root.setCfg("scale", a); return "scale " + a; }
        function eco(v: string): string { const o = v === "toggle" ? !root.eco : v === "on" || v === "1" || v === "true"; root.setCfg("eco", o); return "eco " + (o ? "on (30 fps)" : "off (60 fps)"); }
        function language(v: string): string { const l = v === "ru" || v === "en" ? v : "auto"; root.setCfg("language", l); return "language " + l; }
        function shader(v: string): string { const o = v !== "off" && v !== "0"; root.setCfg("crowdShader", o); return "crowd shader " + (o ? "on" : "off (canvas)"); }
        // tournament of everybody in the call (fakes if fewer than 2); rounds: "1" (default, all matches incl. final), "3", "1/3" = matches/final, "ko"
        function tournament(rounds: string): string {
            const real = root.people.length >= 2;
            return root.startTour(real ? root.people : root.fakes, rounds, !real);
        }
        function tour(): string { return tournament("1"); }
        function demoTournament(): string { return root.startTour(root.fakes, "1", true); }
        function demoTournamentN(n: string, rounds: string): string { return root.startTour(root.fakePool(parseInt(n) || 5), rounds, true); }
        function status(): string {
            return JSON.stringify({ "live": root.live, "state": DiscordVoice.state, "people": root.people.map(p => p.name + ":" + p.id), "on": root.on, "hp": [root.hpA, root.hpB], "weapons": [root.wa ? root.wa.id : "", root.wb ? root.wb.id : ""], "lastHit": root.lastHit, "rounds": root.rounds, "round": root.round, "phase": root.phase, "score": root.scoreTxt, "say": root.say, "ko": root.ko, "combo": root.combo, "banner": root.banner, "caption": root.caption, "crewHidden": Config.discord.crewHidden, "added": root.added, "perf": root.perf, "moveStat": root.moveStat, "tour": root.tourJson(), "sound": { "on": root.soundOn, "volume": root.soundVol }, "meters": [root.spA, root.spB], "result": root.lastResult ? JSON.parse(root.lastResult) : null, "crew": root.crewOn, "hint": root.crewHint, "settings": { "rounds": root.defRounds, "arenaName": root.arenaName, "scale": root.scaleSetting, "eco": root.eco, "language": root.lang, "crowdShader": root.crowdShader, "shield": root.shieldOn, "super": root.superOn, "pickups": root.pickupsOn, "pickupRate": root.pickupRate, "arena": root.arenaPick, "arenaNow": root.arenaNow, "arenaFx": root.arenaFx } });
        }
    }

    // ── the ring (CrewArena.qml), only while a fight is on
    LazyLoader {
        active: root.on
        CrewArena { game: root }
    }
    // ── tournament bracket between matches
    LazyLoader {
        active: root.tourOn && root.tourBracket
        TourBracket { game: root }
    }

    // ── picker: fighters, weapons, arena (MatchSetup.qml)
    LazyLoader {
        active: root.picking
        MatchSetup { game: root }
    }
}
