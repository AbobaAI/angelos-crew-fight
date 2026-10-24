import QtQuick
import qs.config
import qs.services
import qs.widgets

// Settings → Plugins → Crew Fight (everything is also settable over IPC, see README)
Column {
    id: root
    property var plugin
    width: parent ? parent.width : 400
    spacing: Skin.px(10)
    function get(k, d) { const v = plugin ? plugin.get(k, d) : d; return v === undefined || v === null ? d : v; }
    function set(k, v) { if (plugin) plugin.set(k, v); }

    PxGroup {
        title: I18n.t("Бой", "Fight")
        icon: "heart"
        width: parent.width
        SettingRow {
            label: I18n.t("Раунды по умолчанию", "Default rounds")
            hint: I18n.t("для «Драка», «случайная пара», «демо»; турнир — 1 раунд на матч", "for pick / random / demo; tournaments use 1 round per match")
            PxSegmented {
                model: [{ "label": "1", "value": 1 }, { "label": "3", "value": 3 }, { "label": "5", "value": 5 }, { "label": I18n.t("до KO", "to KO"), "value": 0 }]
                currentValue: Number(root.get("rounds", 1))
                onActivated: v => root.set("rounds", v)
            }
        }
        SettingRow {
            label: I18n.t("Название арены", "Arena name")
            hint: I18n.t("на баннерах зала, до 18 символов", "on the hall banners, up to 18 characters")
            PxField {
                width: parent.width
                placeholder: "CREW ARENA"
                text: String(root.get("arenaName", ""))
                onEdited: root.set("arenaName", text.slice(0, 24))
            }
        }
        SettingRow {
            label: I18n.t("Язык комментатора и интерфейса", "Announcer & UI language")
            PxSegmented {
                model: [{ "label": I18n.t("как в AngelOS", "as AngelOS"), "value": "auto" }, { "label": "Русский", "value": "ru" }, { "label": "English", "value": "en" }]
                currentValue: String(root.get("language", "auto"))
                onActivated: v => root.set("language", v)
            }
        }
    }
    PxGroup {
        title: I18n.t("Геймплей", "Gameplay")
        icon: "heart"
        width: parent.width
        SettingRow {
            label: I18n.t("Блок (щит)", "Block (shield)")
            hint: I18n.t("бойцы сами ставят щит: урон ×0.2; идеальный блок в первые мгновения щита оглушает атакующего", "fighters raise a shield on their own: damage ×0.2; a perfect block in the early shield window staggers the attacker")
            PxToggle {
                checked: root.get("gpShield", true) !== false
                onToggled: c => root.set("gpShield", c)
            }
        }
        SettingRow {
            label: I18n.t("Суперудар", "Super move")
            hint: I18n.t("шкала под HP растёт от ударов; полная — боец сам бьёт суперударом", "the meter under the HP bar fills from hits; when full the fighter fires a super")
            PxToggle {
                checked: root.get("gpSuper", true) !== false
                onToggled: c => root.set("gpSuper", c)
            }
        }
        SettingRow {
            label: I18n.t("Предметы на арене", "Arena pickups")
            hint: I18n.t("аптечка, ускорение и бомба падают на ринг", "heal kit, speed boost and bomb drop into the ring")
            PxToggle {
                checked: root.get("gpPickups", true) !== false
                onToggled: c => root.set("gpPickups", c)
            }
        }
        SettingRow {
            label: I18n.t("Частота предметов", "Pickup frequency")
            PxSegmented {
                model: [{ "label": I18n.t("редко", "rare"), "value": "rare" }, { "label": I18n.t("норм", "normal"), "value": "normal" }, { "label": I18n.t("часто", "often"), "value": "often" }]
                currentValue: String(root.get("gpPickupRate", "normal"))
                onActivated: v => root.set("gpPickupRate", v)
            }
        }
    }
    PxGroup {
        title: I18n.t("Звук", "Sound")
        icon: "speaker"
        width: parent.width
        SettingRow {
            label: I18n.t("Звуки боя", "Fight sounds")
            PxToggle {
                checked: root.get("sound", true) !== false
                onToggled: c => root.set("sound", c)
            }
        }
        SettingRow {
            label: I18n.t("Громкость", "Volume")
            PxSlider {
                width: parent.width
                from: 0; to: 100; stepSize: 5; suffix: "%"
                value: Number(root.get("volume", 50))
                onMoved: v => root.set("volume", Math.round(v))
            }
        }
    }
    PxGroup {
        title: I18n.t("Экран и производительность", "Display & performance")
        icon: "monitor"
        width: parent.width
        SettingRow {
            label: I18n.t("Размер арены", "Arena size")
            hint: I18n.t("авто — по размеру монитора, на котором открывается бой", "auto fits the monitor the fight opens on")
            PxSegmented {
                model: [{ "label": I18n.t("авто", "auto"), "value": "auto" }, { "label": "75%", "value": "75" }, { "label": "100%", "value": "100" }, { "label": "150%", "value": "150" }, { "label": "200%", "value": "200" }]
                currentValue: String(root.get("scale", "auto"))
                onActivated: v => root.set("scale", v)
            }
        }
        SettingRow {
            label: I18n.t("Эко-режим (30 к/с)", "Eco mode (30 fps)")
            hint: I18n.t("вдвое меньше нагрузки на CPU/GPU, например во время игры", "about half the CPU/GPU load, e.g. while gaming")
            PxToggle {
                checked: root.get("eco", false) === true
                onToggled: c => root.set("eco", c)
            }
        }
        SettingRow {
            label: I18n.t("Толпа на GPU (шейдер)", "GPU crowd (shader)")
            hint: I18n.t("выключи, если толпа не рисуется: будет Canvas-версия", "turn off if the crowd doesn't show: a Canvas version is used")
            PxToggle {
                checked: root.get("crowdShader", true) !== false
                onToggled: c => root.set("crowdShader", c)
            }
        }
    }
}
