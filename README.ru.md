<div align="center">

<img src="screenshots/fight.gif" alt="Драка человечков" width="600">

# 🥊 Драка человечков

**Пиксельный бокс между людьми из твоего звонка Discord — прямо на рабочем столе AngelOS.**

[![AngelOS](https://img.shields.io/badge/AngelOS-релиз%206%2B-e8668b?style=flat-square)](https://github.com/futureUnd1ground/angelos-community-registry)
[![Version](https://img.shields.io/badge/version-2.0.0-6ec3e8?style=flat-square)](https://github.com/AbobaAI/angelos-crew-fight/releases/tag/v2.0.0)
[![License: MIT](https://img.shields.io/badge/license-MIT-8bd17c?style=flat-square)](LICENSE)
[![Sounds: CC0](https://img.shields.io/badge/звуки-CC0-f0b44c?style=flat-square)](sounds/LICENSES.txt)
[![Languages](https://img.shields.io/badge/lang-ru%20%7C%20en-b48cf0?style=flat-square)](README.md)

[English](README.md) | **Русский**

</div>

---

## ✨ Возможности

- 👥 **Настоящие бойцы** — «Человечки из звонка Discord», которых AngelOS уже рисует над панелью; нет звонка → демо-бойцы.
- ⚔️ **8 видов оружия**, по 3 приёма и добивание, комбо, криты, отбрасывание, оглушение.
- 🔔 **Раунды** (1 / 3 / 5 / до нокаута) с девушкой с табличкой, очки судей, тренеры в углах с водой, полотенцем и веером.
- 🎙️ **Комментатор** и советы из углов — на русском и английском.
- 🏆 **Турнир** на выбывание до 16 бойцов, анимированная сетка, пьедестал и конфетти.
- 🔊 **Звук** — удары у каждого оружия, свист замаха, крит, нокаут, гонг, гул толпы и овации, фанфары.
- 🖥️ **Толпа на GPU-шейдере** с запасным вариантом на Canvas, авторазмер под монитор, 🍃 эко-режим для игр.
- 🎨 Обе темы AngelOS (пиксельная и macOS / Golden Gate).

### 🗡️ Оружие

| | Оружие | Приёмы | Добивание |
|:-:|---|---|---|
| 👊 | Кулаки | джеб · апперкот · серия | НОКАУТ ХУКОМ |
| 🩴 | Тапок | шлепок · тапочный шквал · тапок-бумеранг | ТАПОЧНЫЙ ПРИГОВОР |
| 🏏 | Бита | замах · удар сверху · хоумран | ХОУМРАН! УЛЕТЕЛ! |
| 🐟 | Рыба | рыбья пощёчина · рыба-попрыгунья · рыбный удар сверху | РЫБНЫЙ ДЕНЬ |
| 🎤 | Микрофон *(дальний)* | звуковая волна · фидбэк · микрофоном по лбу | MIC DROP |
| ⌨️ | Клавиатура | клавой по голове · дождь клавиш · удар пробелом | ALT+F4 |
| 🥖 | Батон *(лечит)* | батоном · перекус · батон-бумеранг | ХЛЕБНУЛ ГОРЯ |
| 🔴 | Лазер-указка *(редкий, дальний)* | заряженный луч · глаза-лазеры · рукояткой | ЛАЗЕР НА МАКСИМУМ |

## 📸 Скриншоты

<table>
<tr>
<td><img src="screenshots/ru-intro.png" alt="Выход бойцов"></td>
<td><img src="screenshots/ru-fight.png" alt="Бой"></td>
</tr>
<tr>
<td><img src="screenshots/ru-win.png" alt="Пьедестал"></td>
<td><img src="screenshots/settings.png" alt="Настройки"></td>
</tr>
</table>

## 📦 Установка

**Магазин AngelOS:** Настройки → Плагины → Community → *Драка человечков* (после одобрения).

**Одной командой:**

```bash
mkdir -p ~/.config/angelos/plugins && curl -fsSL https://github.com/AbobaAI/angelos-crew-fight/releases/download/v2.0.0/crew-fight-v2.0.0.zip -o /tmp/crew-fight.zip && unzip -oq /tmp/crew-fight.zip -d ~/.config/angelos/plugins/crew-fight && ~/.config/quickshell/angelos/bin/angelos restart
```

**Вручную:**

```bash
git clone https://github.com/AbobaAI/angelos-crew-fight
cp -a angelos-crew-fight ~/.config/angelos/plugins/crew-fight
~/.config/quickshell/angelos/bin/angelos restart     # или включи в Настройки → Плагины
```

Нужен **AngelOS релиз 6 («2004»)** или новее. QtMultimedia (звук) уже есть в Qt AngelOS.

## 🎧 Настройка Discord

**Своего подключения к Discord у плагина нет** — он берёт звонок у AngelOS (`services/DiscordVoice`).
Сначала включи **«Человечки из звонка Discord»** (ПКМ по рабочему столу → виджеты или
`qs -c angelos ipc call angelos discordCrew` — переключатель).

| Клиент | Как AngelOS видит звонок | Что сделать |
|---|---|---|
| **Discord** (официальный) | локальный RPC `ws://127.0.0.1:6463–6472` | один раз подтвердить запрос в Discord |
| **Vesktop / Equibop / Legcord** | в arRPC нет голосового RPC → мост AngelOS через DevTools (по желанию) | запустить клиент с портом DevTools на 127.0.0.1 и записать `{"port": N}` в `~/.config/angelos/discord-voice.json` (или `$XDG_RUNTIME_DIR/angelos-discord-voice.json`, или `ANGELOS_DISCORD_CDP_PORT`) |

Если человечки выключены, Discord не запущен, ты не в голосовом или отвечает только arRPC — окно
выбора скажет, в чём дело, и предложит демо-бойцов.

> [!WARNING]
> Порт DevTools (удалённой отладки) даёт полный контроль над клиентом Discord всему, что до него
> достучится. Открывай его **только на 127.0.0.1**, никогда не в сеть, и не запускай в это время
> недоверенные программы. Мост AngelOS подключается только к loopback-адресу на указанном порту.
> Официальному Discord всё это не нужно.

## 🎮 Как запустить

- 🔎 **Лаунчер** (Mod+Space / Spotlight): `fight`, `драка человечков`, `турнир`
- 🖱️ **ПКМ по рабочему столу:** «Драка человечков» / «Турнир человечков»
- ⌨️ **Горячая клавиша** (по желанию) — в `~/.config/niri/cfg/user.kdl`:

```kdl
binds {
    Mod+Ctrl+K hotkey-overlay-title="Драка человечков" { spawn "qs" "-c" "angelos" "ipc" "call" "crewfight" "pick"; }
}
```

- 🔌 **IPC:** `qs -c angelos ipc call crewfight <функция> [аргументы…]`

| Функция | Что делает |
|---|---|
| `pick` | окно выбора: двое бойцов, оружие, раунды |
| `random` · `demo` | случайная пара из звонка · демо-пара |
| `brawl A B` | двое по имени/id, случайное оружие |
| `fight A B wA wB` · `match A B wA wB rounds` | с оружием (`random` или id из `weapons`) и раундами |
| `demoMatch rounds` | демо-бойцы, раунды `1` `3` `5` `ko` |
| `tour` · `tournament rounds` | турнир всех из звонка |
| `demoTournament` · `demoTournamentN n rounds` | демо-турнир (n = 2–16) |
| `weapons` · `status` · `stop` | список оружия · состояние JSON · стоп |

## ⚙️ Настройки

Настройки → Плагины → Драка человечков или IPC (сохраняются одинаково):

| Настройка | IPC | По умолчанию |
|---|---|---|
| Раунды по умолчанию | `rounds 1\|3\|5\|ko` | `1` |
| Название арены (баннеры) | `arenaName ИМЯ` | `CREW ARENA` |
| Язык комментатора и интерфейса | `language auto\|ru\|en` | `auto` (как в AngelOS) |
| Звук · громкость | `sound on\|off\|toggle` · `volume 0-100` | вкл · `50` |
| Размер арены | `scale auto\|50-300` | `auto` (под монитор) |
| Эко-режим (~25–30 к/с) | `eco on\|off\|toggle` | выкл |
| Толпа на GPU (шейдер) | `shader on\|off` | вкл (иначе Canvas) |

## 🏆 Турнир

Все из звонка (или 2–16 демо-бойцов) случайно расставляются в сетку на выбывание; при нечётном
числе кто-то проходит без боя. Между матчами линия победителя анимированно «дорисовывается» в
следующий слот; чемпион поднимается на пьедестал. Раунды: `tournament 1` (по умолчанию, все матчи и
финал), `tournament 3`, `tournament 1/3` (матчи / финал), `tournament ko`.

Пока идёт бой, «гуляющие» копии бойцов скрыты (`crewHidden`) и потом возвращаются — даже после
падения или перезагрузки оболочки.

## 🔊 Звуки

Все 22 звука синтезированы с нуля в ffmpeg скриптом [`sounds/gen.sh`](sounds/gen.sh) — без сэмплов
и паков — и выпущены под **CC0 1.0** ([`sounds/LICENSES.txt`](sounds/LICENSES.txt)). Громкость по
умолчанию — умеренные 50%.

## 📜 Авторы и лицензия

Автор — **aboba**, для [AngelOS](https://github.com/futureUnd1ground/angelos-community-registry).
Код: [MIT](LICENSE) · Звуки: CC0 1.0 · Исходник шейдера толпы: [`shaders/crowd.frag`](shaders/crowd.frag).
