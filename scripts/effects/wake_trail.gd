class_name WakeTrail
extends Node2D
## WakeTrail — кильватерный след за лодкой из затухающих прямоугольников.
##
## Компонент: добавляется дочерним узлом к любому Node2D (в проекте — к
## prefab динги) и только читает global_transform родителя, в физику не
## вмешивается. Узел переводится в top_level, поэтому метки живут в мировых
## координатах и не едут вместе с лодкой.
##
## Форма — волна Кельвина: след расходится от НОСА двумя плечами буквой V.
## Каждые spawn_interval секунд у носа рождается пара меток, и каждая метка
## отплывает от линии курса вбок со скоростью speed * tan(half_angle), где
## speed — скорость лодки при рождении метки. Поэтому угол V не зависит от
## скорости (как у настоящей волны Кельвина на глубокой воде, ~19.5 град), а
## в повороте плечи естественно изгибаются. Ближняя к носу часть плеч скрыта
## под корпусом и выходит из-под него у кормы. При движении задним ходом
## след так же расходится, но от кормы. Опционально — струя от винта
## (stern_wash): цепочка меток по оси за кормой, без бокового сноса.
##
## Метка не сжимается, а расходится и растворяется: ширина поперёк растёт
## до spread раз, длина не меняется, гаснет только альфа. Доля "жизни"
## (fade) — худшая из двух: по возрасту (lifetime) и по пройденному лодкой
## пути с момента рождения метки (max_length). Так след никогда не длиннее
## max_length и тает на месте, когда лодка встала.
##
## Сила метки (strength) фиксируется при рождении по скорости: полная при
## full_wake_speed, слабее на малом ходу (меньше альфа и размер).

## Длина следа по пройденному пути от точки рождения, px. По умолчанию —
## 3 длины корпуса динги (64), считая от носа.
@export_range(0.0, 1000.0, 1.0) var max_length: float = 192.0
## Время жизни метки, с.
@export_range(0.05, 10.0, 0.05) var lifetime: float = 1.5
## Интервал между парами меток, с.
@export_range(0.01, 1.0, 0.01) var spawn_interval: float = 0.06
## Метки не ставятся, если лодка движется медленнее, px/s.
@export_range(0.0, 100.0, 0.5) var min_speed: float = 8.0
## Полуугол V, град. 19.47 — угол Кельвина для глубокой воды.
@export_range(0.0, 60.0, 0.5) var half_angle_deg: float = 19.47
## Точка рождения плеч V при ходе вперёд, локально (нос).
@export var bow_offset: Vector2 = Vector2(34.0, 0.0)
## Точка рождения плеч V при заднем ходе и струи от винта, локально (корма).
@export var stern_offset: Vector2 = Vector2(-30.0, 0.0)
## Струя от винта: метки по оси за кормой (только при ходе вперёд).
@export var stern_wash: bool = false
## Размер свежей метки на полном ходу, px: x — вдоль плеча, y — поперёк.
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
	## Скорость бокового сноса метки (плечо V), px/s; ноль — для струи винта.
	var drift: Vector2
	## Показание одометра лодки в момент рождения, px.
	var odometer: float
	## Сила при рождении, [0, 1]; зависит от скорости лодки.
	var strength: float
	var age: float = 0.0
	var fade: float = 1.0

	func _init(at: Vector2, heading: float, drift_velocity: Vector2,
			odometer_at_birth: float, wake_strength: float) -> void:
		position = at
		rotation = heading
		drift = drift_velocity
		odometer = odometer_at_birth
		strength = wake_strength


var _source: Node2D
## От старой к новой: новая метка — в конце.
var _marks: Array[Mark] = []
var _spawn_timer: float = 0.0
## Позиция лодки на момент прошлой проверки спавна — для оценки скорости.
var _last_spawn_check_position: Vector2
## Позиция лодки на прошлом кадре — для одометра.
var _last_position: Vector2
## Путь, пройденный лодкой, px. Длина следа считается по нему, а не по
## расстояниям между метками: метки двух плеч чередуются и разнесены вбок.
var _odometer: float = 0.0


func _ready() -> void:
	_source = get_parent() as Node2D
	if _source == null:
		push_error("WakeTrail: parent must be a Node2D")
		set_physics_process(false)
		return
	top_level = true
	global_transform = Transform2D.IDENTITY
	_last_position = _source.global_position
	_last_spawn_check_position = _last_position


# Логика следа — в шаге физики, а не в _process: позиция тела меняется
# только на шагах физики, и лишь здесь смещение и прошедшее время
# согласованы. В _process (монитор 120/144 Гц, headless) в интервал
# попадало бы то 3, то 4 шага физики, и оценка скорости — а с ней боковой
# снос и угол V — прыгала бы на десятки процентов.
func _physics_process(delta: float) -> void:
	var position_now: Vector2 = _source.global_position
	_odometer += position_now.distance_to(_last_position)
	_last_position = position_now

	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		var displacement: Vector2 = position_now - _last_spawn_check_position
		var velocity: Vector2 = displacement / _spawn_timer
		_spawn_timer = 0.0
		_last_spawn_check_position = position_now
		if velocity.length() >= min_speed:
			_spawn(velocity)

	_update_marks(delta)
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


## Рождает пару меток V (и метку струи винта, если включена).
func _spawn(velocity: Vector2) -> void:
	var transform_now: Transform2D = _source.global_transform
	var heading: float = _source.global_rotation
	var forward: Vector2 = Vector2.RIGHT.rotated(heading)
	var moving_forward: bool = velocity.dot(forward) >= 0.0
	var speed: float = velocity.length()
	var strength: float = WakeTrail.strength_for_speed(speed, full_wake_speed)
	var half_angle: float = deg_to_rad(half_angle_deg)

	# V рождается у ведущей оконечности корпуса и ориентирована по
	# направлению движения, а не по носу: при заднем ходе — от кормы.
	var origin: Vector2 = transform_now * (bow_offset if moving_forward else stern_offset)
	var track_heading: float = velocity.angle()
	for side: float in [1.0, -1.0]:
		var arm: Vector2 = WakeTrail.arm_drift(velocity, half_angle, side)
		# Плечо уходит назад и в сторону сноса: линия меток идёт под углом
		# side * half_angle к курсу (ось y экрана направлена вниз).
		var arm_rotation: float = track_heading + side * half_angle
		_marks.append(Mark.new(origin, arm_rotation, arm, _odometer, strength))

	if stern_wash and moving_forward:
		var stern: Vector2 = transform_now * stern_offset
		_marks.append(Mark.new(stern, heading, Vector2.ZERO, _odometer, strength))


## Старит и сносит метки, пересчитывает fade и удаляет исчезнувшие. Проход
## идёт от новой метки к старой; fade монотонно не растёт к старым меткам
## (они старше и родились раньше по одометру), поэтому первая исчезнувшая
## отсекает и все более старые.
func _update_marks(delta: float) -> void:
	var first_alive: int = 0
	for i: int in range(_marks.size() - 1, -1, -1):
		var mark: Mark = _marks[i]
		mark.age += delta
		mark.position += mark.drift * delta
		var distance: float = _odometer - mark.odometer
		mark.fade = WakeTrail.fade_factor(mark.age, lifetime, distance, max_length)
		if mark.fade <= 0.0:
			first_alive = i + 1
			break
	if first_alive > 0:
		_marks = _marks.slice(first_alive)


## Доля "жизни" метки в [0, 1]: 1 — свежая, 0 — исчезла. Берётся худшая из
## двух долей: по возрасту и по пройденному с рождения пути.
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


## Масштаб метки (x — вдоль плеча, y — поперёк). Базовый масштаб растёт
## с силой от min_scale до 1; ширина дополнительно расходится от 1 до
## spread_max по мере угасания (fade: 1 -> 0). Длина от fade не зависит.
static func mark_scale(fade: float, strength: float, spread_max: float, min_scale: float) -> Vector2:
	var base: float = lerpf(min_scale, 1.0, strength)
	var widen: float = lerpf(spread_max, 1.0, fade)
	return Vector2(base, base * widen)


## Скорость бокового сноса метки плеча V, px/s: перпендикулярно курсу,
## величиной |velocity| * tan(half_angle). side = +1 / -1 — сторона плеча.
## Метка неподвижна вдоль курса, а лодка уходит со скоростью |velocity|,
## поэтому плечо отклоняется от линии курса ровно на half_angle.
static func arm_drift(velocity: Vector2, half_angle: float, side: float) -> Vector2:
	return velocity.orthogonal() * (tan(half_angle) * side)
