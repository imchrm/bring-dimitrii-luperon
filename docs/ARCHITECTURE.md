# ARCHITECTURE — Bring Dimitrii To Home: Luperon

Структура проекта, принципы организации сцен и физическая модель.

## Принцип: сцена = версия игры

Каждый самодостаточный мир — отдельная главная сцена в `scenes/world/`.
Текущая — `luperon.tscn` (залив Luperón). Новая версия игры = новая главная
сцена, переиспользующая те же под-сцены-prefab (динги, препятствия, яхты).
Это идиоматично для Godot: всё — узел (Node), сцена — дерево узлов, сцена
целиком инстанцируется внутри другой как переиспользуемый компонент.

## Структура каталогов

```
project.godot              # манифест: input map, рендерер, окно, гравитация=0
icon.svg
scenes/
  world/luperon.tscn       # главная сцена (мир залива Luperón)
  actors/dinghy.tscn       # динги — переиспользуемый prefab
scripts/
  world/luperon.gd
  actors/dinghy.gd         # физическая модель лодки
assets/                    # sprites / audio / fonts
addons/                    # GDExtension и плагины (напр. физика троса)
export_presets.cfg         # пресеты Linux / Android
docs/                      # проектная документация
.vscode/                   # launch.json / settings.json / extensions.json
.github/workflows/ci.yml   # headless import + smoke-run
```

Код и сцены — plain text, дружелюбны к git. Движок в репозиторий не входит
(портативный .exe, версия фиксируется отдельно). Кеш `.godot/` — в `.gitignore`.

## Дерево узлов главной сцены (luperon.tscn)

```
Luperon (Node2D)                  [scripts/world/luperon.gd]
├── Water (Polygon2D)             # фон "воды"
├── Shore (StaticBody2D)          # береговая линия + коллизия
├── Dock (StaticBody2D)           # док (препятствие/цель)
├── MooredBoatA/B (StaticBody2D)  # пришвартованные лодки-препятствия
├── Dinghy (instance dinghy.tscn) # управляемая игроком
│   └── FollowCamera (Camera2D)
├── DinghyToTow (instance dinghy.tscn, has_engine=false) # цель буксировки
└── HUD (CanvasLayer)
```

## Prefab динги (dinghy.tscn)

```
Dinghy (RigidBody2D)              [scripts/actors/dinghy.gd]
├── Hull (Polygon2D)              # корпус
├── Bow (Polygon2D)               # нос (маркер направления, локальная +X)
├── CollisionShape2D
├── TowPoint (Marker2D)           # корма — сюда крепится трос буксира
└── BowPoint (Marker2D)           # нос — сюда крепится трос буксируемой
```

## Физическая модель лодки

Вид сверху, гравитации нет (`gravity_scale = 0`, глобально
`physics/2d/default_gravity = 0`). "Вода":

- **Линейное сопротивление** считается в скрипте отдельно по осям корпуса
  (`Dinghy.water_drag_acceleration`, чистая статическая функция): скорость
  раскладывается на продольную и поперечную составляющие, каждая гасится своим
  коэффициентом — `forward_drag` (малый) и `lateral_drag` (в разы больше, как
  у корпуса с килем). Встроенный `linear_damp` отключён
  (`linear_damp_mode = Replace`, значение 0), чтобы не складываться с этим.
- **Вращение** гасит встроенный `angular_damp`.

Лодка сама замедляется и останавливается, а в повороте почти не скользит боком.
Это же нужно для буксировки: буксируемая динги выстраивается в кильватер, потому
что поперёк ей двигаться намного тяжелее, чем вдоль. Сопротивление действует и
при `has_engine = false`.

Сила считается по скорости предыдущего шага (явная схема), поэтому
`drag * шаг_физики < 1` (при 60 Гц — `drag < 60`); иначе скорость начнёт
колебаться. Модель линейная по скорости; квадратичная составляющая — кандидат
для Вехи 2. Направление "вперёд" — локальная
ось +X. Управление (`scripts/actors/dinghy.gd`, `_physics_process`):

- **Тяга**: `apply_central_force` вдоль forward; вперёд `engine_force`,
  назад `reverse_force`.
- **Руль**: `apply_torque`, эффективность пропорциональна текущей скорости
  (`speed_factor`) — как настоящий руль, которому нужен поток воды.

Параметры вынесены в `@export` (сопротивление — в группе "Water drag") для
подбора вживую через вкладку Remote.

`has_engine = false` превращает тот же prefab в заглохшую динги (цель
буксировки): управление отключается, остаётся пассивное тело с сопротивлением
воды на тросе. Скрипт объявлен как `class_name Dinghy` — в коде мира ссылки
типизируются как `Dinghy`, а не как безликий `RigidBody2D`.

## Типизация GDScript

В `project.godot` (секция `[debug]`) предупреждения анализатора подняты до
ошибок: `untyped_declaration`, `unsafe_property_access`,
`unsafe_method_access`, `unsafe_call_argument` (а `unsafe_cast` —
предупреждение). Нетипизированная переменная, функция без типа возврата или
обращение к свойству через базовый `Node` (`get_node("X").position`) ломают
загрузку скрипта — и, как следствие, CI. Нужное приведение делается явно:
`get_node("X") as Marker2D`. Вывод типа через `:=` разрешён (это статический
тип). Каталог `addons/` по умолчанию из проверки исключён.

## Карта ввода

Действия (`project.godot [input]`): `thrust` (W / Up), `reverse` (S / Down),
`steer_left` (A / Left), `steer_right` (D / Right).

## Буксировка троса (план, главный риск)

Не реализовано в каркасе — следующий шаг. План:

1. Базовый вариант: `DampedSpringJoint2D` между `Dinghy/TowPoint` и
   `DinghyToTow`. Параметры (length / rest_length / stiffness / damping) —
   в `@export`, подбор через Remote.
2. Если натяжение/устойчивость не устроят (риск "взрыва" физики на поворотах
   из-за связки инерция + сопротивление + джойнт) — переход на GDExtension
   **Rapier** (`RapierRopeJoint2D`) или **Box2D** через `addons/`.
3. При подключении нативного расширения: в Android-пресете включить
   **Use Gradle Build** и установить Android Build Template, иначе нативные
   библиотеки не попадут в APK. Расширение должно содержать варианты под все
   целевые архитектуры (arm64-v8a для телефона, x86_64 для MuMu-эмулятора).

## Ландшафт (план)

Береговая линия, заливы, доки — на **TileSet Terrains** (автотайлинг с
автоскруглением краёв по битовой маске). При необходимости применяется в
рантайме через `set_cells_terrain_connect()`. Внутриигрового конструктора нет.
