class_name WakeTrail
extends Node2D
## WakeTrail — след за лодкой из затухающих прямоугольников.
##
## Компонент: добавляется дочерним узлом к любому Node2D (в проекте — к
## prefab динги) и только читает global_transform родителя, в физику не
## вмешивается. Узел переводится в top_level, поэтому метки живут в мировых
## координатах и не едут вместе с лодкой.
##
## Метки ставятся через равные промежутки ВРЕМЕНИ (spawn_interval), поэтому
## расстояние между ними показывает скорость: реже — быстрее. Прямоугольник
## повёрнут по НОСУ корпуса, а не по траектории: в повороте видно, насколько
## корпус развёрнут относительно направления движения (снос боком).
##
## Как настоящий кильватерный след, метка не сжимается, а РАСХОДИТСЯ и
## растворяется: ширина поперёк корпуса растёт до spread раз, длина вдоль
## корпуса не меняется, гаснет только альфа. Доля "жизни" (fade) — худшая из
## двух: по возрасту (lifetime) и по удалённости от лодки вдоль следа
## (max_length). Так след никогда не длиннее max_length и не "втягивается"
## в корму, когда лодка встала, а тает на месте.
##
## Сила метки (strength) фиксируется при рождении по скорости: полная при
## full_wake_speed, слабее на малом ходу (меньше альфа и размер). Тормозящая
## лодка оставляет всё более слабые метки — без яркого сгустка у кормы.

## Длина следа вдоль траектории, px. По умолчанию — 3 длины корпуса динги (64).
@export_range(0.0, 1000.0, 1.0) var max_length: float = 192.0
## Время жизни метки, с.
@export_range(0.05, 10.0, 0.05) var lifetime: float = 1.5
## Интервал между метками, с.
@export_range(0.01, 1.0, 0.01) var spawn_interval: float = 0.06
## Метки не ставятся, если источник движется медленнее, px/s.
@export_range(0.0, 100.0, 0.5) var min_speed: float = 8.0
## Точка появления меток в локальных координатах родителя (корма).
@export var emit_offset: Vector2 = Vector2(-30.0, 0.0)
## Размер свежей метки на полном ходу, px: x — вдоль корпуса, y — поперёк.
@export var mark_size: Vector2 = Vector2(12.0, 5.0)
## Цвет свежей метки на полном ходу; альфа гаснет с fade и strength.
@export var mark_color: Color = Color(0.85, 0.95, 1.0, 0.65)
## Во сколько раз ширина метки (y) вырастает к концу жизни.
@export_range(1.0, 10.0, 0.1) var spread: float = 2.5
## Скорость, при которой метка рождается с полной силой, px/s.
@export_range(1.0, 1000.0, 1.0) var full_wake_speed: float = 200.0
## Масштаб размера метки при нулевой силе (на малом ходу); 1 — не зависит.
@export_range(0.0, 1.0, 0.05) var min_size_scale: float = 0.5


## Одна метка следа.
class Mark:
	var position: Vector2
	var rotation: float
	## Сила при рождении, [0, 1]; зависит от скорости лодки.
	var strength: float
	var age: float = 0.0
	var fade: float = 1.0

	func _init(at: Vector2, heading: float, wake_strength: float) -> void:
		position = at
		rotation = heading
		strength = wake_strength


var _source: Node2D
## От старой к новой: новая метка — в конце.
var _marks: Array[Mark] = []
var _spawn_timer: float = 0.0
## Точка появления на момент прошлой проверки спавна — для оценки скорости.
var _last_spawn_check_point: Vector2
## Точка появления на момент последнего пересчёта меток (голова следа).
var _head: Vector2


func _ready() -> void:
	_source = get_parent() as Node2D
	if _source == null:
		push_error("WakeTrail: parent must be a Node2D")
		set_process(false)
		return
	top_level = true
	global_transform = Transform2D.IDENTITY
	_head = _emit_point()
	_last_spawn_check_point = _head


func _process(delta: float) -> void:
	_head = _emit_point()

	# Скорость оценивается по смещению за весь интервал, а не за кадр:
	# кадров отрисовки может быть больше, чем шагов физики (монитор 120/144 Гц,
	# headless), и тогда в части кадров тело "стоит" и скорость была бы 0.
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		var speed: float = _head.distance_to(_last_spawn_check_point) / _spawn_timer
		_spawn_timer = 0.0
		_last_spawn_check_point = _head
		if speed >= min_speed:
			var strength: float = WakeTrail.strength_for_speed(speed, full_wake_speed)
			_marks.append(Mark.new(_head, _source.global_rotation, strength))

	_update_marks(_head, delta)
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = mark_size * 0.5
	for mark: Mark in _marks:
		var color: Color = mark_color
		color.a *= mark.fade * mark.strength
		var scale_xy: Vector2 = WakeTrail.mark_scale(mark.fade, mark.strength, spread, min_size_scale)
		draw_set_transform(mark.position, mark.rotation, scale_xy)
		draw_rect(Rect2(-half, mark_size), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Старит метки, пересчитывает fade и удаляет исчезнувшие. Проход идёт от
## новой метки к старой с накоплением длины следа; fade монотонно не растёт
## к старым меткам, поэтому первая исчезнувшая отсекает и все более старые.
func _update_marks(head: Vector2, delta: float) -> void:
	var distance: float = 0.0
	var previous: Vector2 = head
	var first_alive: int = 0
	for i: int in range(_marks.size() - 1, -1, -1):
		var mark: Mark = _marks[i]
		mark.age += delta
		distance += previous.distance_to(mark.position)
		previous = mark.position
		mark.fade = WakeTrail.fade_factor(mark.age, lifetime, distance, max_length)
		if mark.fade <= 0.0:
			first_alive = i + 1
			break
	if first_alive > 0:
		_marks = _marks.slice(first_alive)


func _emit_point() -> Vector2:
	return _source.global_transform * emit_offset


## Доля "жизни" метки в [0, 1]: 1 — свежая, 0 — исчезла. Берётся худшая из
## двух долей: по возрасту и по удалённости от лодки вдоль следа.
## Чистая функция без состояния — пригодна для юнит-тестов.
static func fade_factor(age: float, max_age: float, distance: float, length_limit: float) -> float:
	if max_age <= 0.0 or length_limit <= 0.0:
		return 0.0
	return clampf(1.0 - maxf(age / max_age, distance / length_limit), 0.0, 1.0)


## Сила метки по скорости при рождении, [0, 1]: линейно до full_speed.
static func strength_for_speed(speed: float, full_speed: float) -> float:
	if full_speed <= 0.0:
		return 1.0
	return clampf(speed / full_speed, 0.0, 1.0)


## Масштаб метки (x — вдоль корпуса, y — поперёк). Базовый масштаб растёт
## с силой от min_scale до 1; ширина дополнительно расходится от 1 до
## spread_max по мере угасания (fade: 1 -> 0). Длина от fade не зависит.
static func mark_scale(fade: float, strength: float, spread_max: float, min_scale: float) -> Vector2:
	var base: float = lerpf(min_scale, 1.0, strength)
	var widen: float = lerpf(spread_max, 1.0, fade)
	return Vector2(base, base * widen)
