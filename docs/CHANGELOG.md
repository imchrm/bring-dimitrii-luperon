# CHANGELOG — Bring Dimitrii To Home: Luperon

Формат по мотивам [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
версионирование — [SemVer](https://semver.org/lang/ru/).

## [Unreleased]

### Added
- Зацеп и отцеп троса: действие `tow` (Space / E). Подойти кормой к носу
  другой лодки ближе `hook_radius` (48 px) — вокруг её носа пульсирует
  кольцо; нажатие цепляет трос, повторное — отдаёт. Кандидаты — группа
  `tow_points` (`BowPoint` в prefab динги), своя лодка исключена.
  `TowRope`: методы `hook()` / `release()` / `is_attached()` /
  `get_towed_body()` / `find_hook_candidate()`, сигналы `hooked` / `released`.
- Буксирный трос `TowRope` (`scripts/actors/tow_rope.gd`): свой, на GDScript;
  только тянет (упругость + демпфирование, обрезка в `[0, max_force]`),
  сила приложена в точках крепления; отрисовка `Line2D` с провисом по
  слабине. В `luperon.tscn` заглохшая динги подцеплена к корме игрока с
  начала сцены. Устойчивость проверена headless: прямая, полный руль,
  провис, рывок, 30 с циркуляции.
- Камера `FollowCamera` (`scripts/world/follow_camera.gd`): держит лодку
  носом вверх и поворачивается за курсом с запаздыванием (`rotation_lag`,
  0.15 с — ~14 град отставания при полном руле); центр вида смещён вперёд
  по курсу (`look_ahead`).
- След за лодкой `WakeTrail` (`scripts/effects/wake_trail.gd`): прямоугольники
  по направлению носа, ставятся по времени, уменьшаются и бледнеют по возрасту
  и удалённости; длина следа не больше `max_length` (192 px = 3 длины корпуса).
  Подключён в prefab динги, параметры в `@export`.
- Сопротивление воды раздельно вдоль и поперёк корпуса
  (`forward_drag` / `lateral_drag`, группа "Water drag" в инспекторе):
  снос боком в повороте уменьшился примерно в 4 раза при той же скорости
  на прямой. Действует и на заглохшую динги.
- `BowPoint (Marker2D)` на носу prefab динги — точка крепления троса у
  буксируемой лодки.
- `class_name Dinghy` для типизированных ссылок на лодку.
- Строгая типизация GDScript: `untyped_declaration`, `unsafe_*` подняты до
  ошибок в `project.godot` (`[debug]`).

### Changed
- `TowRope`: экспорт `attached` убран — состояние определяется зацепом
  (`towed_point` в сцене теперь означает "подцеплен с начала").
- В `luperon.tscn` трос с начала не подцеплен; заглохшая динги стоит впереди
  носом навстречу (`(260, 240)`), чтобы её можно было зацепить, пройдя мимо.
  Подсказка HUD описывает зацеп.
- Ориентация экрана — портретная: вьюпорт 720x1280,
  `handheld/orientation = portrait` (было `"landscape"` строкой — в Godot 4
  это целочисленный enum); окно на десктопе 450x800. Подсказка HUD
  переносится по словам.
- `WakeTrail`: след расходится от носа буквой V (волна Кельвина,
  `half_angle_deg` = 19.47) вместо цепочки из точки за кормой; при заднем ходе
  — от кормы. Струя от винта из точки крепления мотора на корме
  (`stern_wash`, включена по умолчанию). Длина следа
  считается по пути лодки (одометр). Параметр `emit_offset` заменён на
  `bow_offset` / `stern_offset`.
- `WakeTrail`: метки расходятся вширь (`spread`) и гаснут только по альфе,
  а не сжимаются; сила метки зависит от скорости при рождении
  (`full_wake_speed`, `min_size_scale`). След остановившейся лодки тает на
  месте, а не втягивается в корму, и при торможении у кормы нет яркого
  сгустка.
- `Water` в `luperon.tscn` опущен на `z_index = -10`, чтобы след рисовался
  поверх воды, но под лодками и берегом.
- Встроенный `linear_damp` динги отключён (`linear_damp_mode = Replace`, 0) —
  линейное сопротивление считается в скрипте.
- CI падает также на любых строках `ERROR:` движка (не только на ошибках
  скриптов).

### Fixed
- `WakeTrail`: логика перенесена в `_physics_process`; в `_process` оценка
  скорости зависела от числа шагов физики, попавших в интервал, и прыгала на
  десятки процентов (при 120/144 Гц и в headless).
- `SETUP.md` §8: описана ловушка `Identifier not found: <ИмяКласса>` после
  `git pull` — устаревший кеш глобальных классов редактора (например, F5 из
  VS Code до того, как редактор пересканировал файлы с новым `class_name`).
- Документация: версия Godot в `SETUP.md` §4.1, требования NDK/CMake в
  комментарии `ci.yml`, устаревший раздел "Инициализация git" в `README.md`.

### Планируется
- Прототип буксировки троса (`DampedSpringJoint2D`, при необходимости
  Rapier/Box2D GDExtension).

## [0.1.0] — 2026-10-15

Стартовый каркас проекта.

### Added
- Проект Godot 4.7 (GDScript, рендерер Compatibility), `project.godot` с
  картой ввода и нулевой гравитацией.
- Главная сцена `scenes/world/luperon.tscn`: вода, береговая линия, док,
  пришвартованные лодки-препятствия, следящая камера, HUD.
- Prefab `scenes/actors/dinghy.tscn` + физическая модель лодки
  `scripts/actors/dinghy.gd` (`RigidBody2D`, демпфирование как сопротивление
  воды, тяга вдоль носа, руль пропорционально скорости, `TowPoint` на корме).
- Заглохшая динги (`has_engine = false`) как будущая цель буксировки.
- Обвязка репозитория: `.gitignore`, `.gitattributes` (LF), `.editorconfig`,
  `.vscode` (launch.json / settings.json / extensions.json).
- CI `.github/workflows/ci.yml`: headless import + smoke-run, падение на
  ошибках скриптов/парсинга.
- Пресеты экспорта `export_presets.cfg` (Linux, Android).
- Документация: `README.md`, `SETUP.md`, `docs/` (CONTEXT, ARCHITECTURE,
  TODO, CHANGELOG).

[Unreleased]: https://github.com/imchrm/bring-dimitrii-luperon/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/imchrm/bring-dimitrii-luperon/releases/tag/v0.1.0
