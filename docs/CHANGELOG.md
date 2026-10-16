# CHANGELOG — Bring Dimitrii To Home: Luperon

Формат по мотивам [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
версионирование — [SemVer](https://semver.org/lang/ru/).

## [Unreleased]

### Added
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
