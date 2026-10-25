# HANDOFF: Драка человечков (crew-fight), плагин AngelOS

## Что это
Это плагин AngelOS (Quickshell/QML): пиксельный бой двух человечков из звонка Discord (обычный клиент и Vesktop). Есть оружие, комбо, криты, раунды, комментатор, турнир с сеткой и пьедестал. Без звонка дерутся демо-бойцы. Версия 2.0.0 опубликована в community-каталоге, в работе 2.1.0-dev.

## Файлы
- `manifest.json`: id `crew-fight`, версия, меню (IPC `qs -c angelos ipc call crewfight pick|tour`).
- `Main.qml`: точка входа, IPC, окно/оверлей, звуки, чтение настроек.
- `CrewArena.qml`: вся арена: физика, ИИ, удары, щит, супер, предметы, HUD, отрисовка.
- `TourBracket.qml`: турнирная сетка. `Launcher.qml`: лаунчер «fight». `Settings.qml`: настройки (группа «Геймплей»: gpShield, gpSuper, gpPickups, gpPickupRate, gpArena, gpArenaFx).
- `sounds/`: wav-файлы, `gen.sh` (генерация звуков), `LICENSES.txt` (все CC0). `shaders/`: толпа (crowd.frag и .qsb).
- `README.md` / `README.ru.md`, `screenshots/`.

## Деплой и тест
Рабочая копия плагина: `~/.config/angelos/plugins/crew-fight/`.
```
cp -a ~/.config/angelos/plugins/crew-fight ~/.config/angelos/plugins-crew-fight.bak-$(date +%Y%m%d-%H%M)   # бэкап
rsync -a --delete --exclude .git --exclude .cursor --exclude screenshots --exclude 'README*' --exclude HANDOFF.md --exclude AGENTS.md --exclude .gitignore ./ ~/.config/angelos/plugins/crew-fight/
~/.config/quickshell/angelos/bin/angelos restart
journalctl --user -u angelos -n 100 --no-pager | grep -iE "crew|error" | grep -v SceneLayer
qs -c angelos ipc call crewfight pick     # запустить бой
```
В логах выводятся строки `crew-fight perf: fps …`. Предупреждения `SceneLayer … 'dir' of null` и `qt.qpa.wayland.textinput` относятся не к плагину, их можно не учитывать.

## Ветки
- `main`: 2.0.0 (опубликованная).
- `gameplay-v2.1`: три коммита: щит → супер → предметы. Сейчас совпадает с live-плагином.
- `gameplay-v2.1-wip`: этот handoff, AGENTS.md и правила Cursor. Работаем здесь.
- Удалённых пушей нет и без разрешения не будет.

## Состояние фич (на 25.10.2026)
1. Щит/блок: сделан (ИИ ставит блок, урон ×0.2, идеальный блок оглушает атакующего, guard break, звуки block/parry). Нужна проверка баланса пользователем.
2. Суперудар: сделан (шкала под HP, суперудары для разных видов оружия, HUD, звуки super/supercharge). Нужна полировка.
3. Предметы (аптечка, ускорение, бомба): сделаны (выпадение, ИИ бежит к предмету или от бомбы, спрайты, звуки heal/boost/drop/fuse, настройка частоты). Это последний коммит перед остановкой, тестировался меньше всего.
4. Арены: пять культурных (додзё, пустыня, фьорд, площадь, терем). У каждой свой пиксельный зал и одна механика (край татами, песчаная буря, лёд, праздник в центре, снег у забора). В «Геймплее» выбор арены или «случайная» (по умолчанию) и выключатель механик. Название коротко на баннере в начале боя. Нужна проверка баланса пользователем. Тик больше не собирает новые массивы и замыкания каждый кадр (из-за этого Quickshell падал в сборщике мусора Qt на Фьорде): частицы из пула, снег двигается без JS-привязок.
В логах ошибок плагина нет, perf около 60 fps. Эко-режим (~25 fps) и английский баннер «X WINS» пользователь принял. Ставки отменены.

## План (строго по очереди)
щит → суперудар → предметы (аптечка, скорость, бомба) → арены. Арены добавлены, ждут фидбек по балансу.

## Откат на последнюю стабильную версию 2.0
```
rm -rf ~/.config/angelos/plugins/crew-fight && cp -a ~/.config/angelos/crew-fight-live.bak-gp1 ~/.config/angelos/plugins/crew-fight && ~/.config/quickshell/angelos/bin/angelos restart
```

## Правила
- Отвечай по-русски, коротко и просто.
- Перед правкой live-плагина делай бэкап.
- Никаких `git push`, PR и релизов в каталог без явного «да» пользователя.
- Без sudo. Без kill/pkill. Перезапуск только через `angelos restart`.
- Прежде чем сказать «готово», проверь логи.
