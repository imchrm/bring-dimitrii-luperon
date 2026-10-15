# CHANGELOG — Bring Dimitrii To Home: Luperon

Формат по мотивам [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
версионирование — [SemVer](https://semver.org/lang/ru/).

## [Unreleased]

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
