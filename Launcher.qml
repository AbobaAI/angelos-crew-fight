import QtQuick
import Quickshell
import qs.config
import qs.services

// "fight" → pick two crew members · "fight demo" → fake fighters (Mod+Space; Spotlight in the macOS look)
QtObject {
    id: root
    property var plugin
    property string pluginId
    readonly property string prefix: "fight"
    readonly property bool global: true
    signal changed

    readonly property string langSetting: plugin ? String(plugin.get("language", "auto")) : "auto"
    readonly property bool en: langSetting === "en" || (langSetting !== "ru" && Config.appearance.language === "en")
    function t(ru, en) { return root.en ? en : ru; }

    function query(text, prefixed) {
        const q = text.toLowerCase();
        if (!prefixed && !(q.length >= 3 && ("драка человечков crew fight турнир tournament".indexOf(q) >= 0 || q.indexOf("турн") >= 0 || q.indexOf("tourn") >= 0)))
            return [];
        const tourQ = q.indexOf("тур") >= 0 || q.indexOf("tour") >= 0;
        return [
            { "id": "pick", "title": t("Драка человечков", "Crew Fight"), "subtitle": t("выбрать двух бойцов из звонка", "pick two fighters from the call"), "icon": "heart", "score": 90 },
            { "id": "random", "title": t("Драка: случайная пара", "Fight: random pair"), "subtitle": t("двое случайных из звонка", "two random people from the call"), "icon": "heart", "score": 60 },
            { "id": "demo", "title": t("Драка: демо", "Fight: demo"), "subtitle": t("демо-бойцы, без звонка", "demo fighters, no call needed"), "icon": "heart", "score": 50 },
            { "id": "tour", "title": t("Турнир человечков", "Crew Tournament"), "subtitle": t("сетка на выбывание из всех в звонке", "single-elimination bracket of everyone in the call"), "icon": "heart", "score": tourQ ? 95 : 55 },
            { "id": "demoTournament", "title": t("Турнир: демо", "Tournament: demo"), "subtitle": t("демо-бойцы", "demo fighters"), "icon": "heart", "score": tourQ ? 85 : 40 }
        ];
    }
    function activate(id) {
        Quickshell.execDetached(["qs", "-c", "angelos", "ipc", "call", "crewfight", id]);
    }
}
