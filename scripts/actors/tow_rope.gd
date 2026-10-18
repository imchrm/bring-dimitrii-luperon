class_name TowRope
extends Line2D
## TowRope — буксирный трос между двумя твёрдыми телами.
##
## Трос, а не пружина: тянет только при натяжении (расстояние между точками
## крепления больше length) и никогда не толкает. Пока трос провис, силы нет.
## При натяжении сила = stiffness * растяжение + damping * скорость
## растяжения, обрезанная снизу нулём (трос не толкает даже при быстром
## сближении) и сверху max_force (страховка от "взрыва" физики). Скорость
## растяжения берётся в самих точках крепления, с учётом вращения тел.
##
## Сила приложена к обоим телам в точках крепления (apply_force со
## смещением), поэтому даёт и момент: буксир при рывке уводит кормой,
## а буксируемая лодка разворачивается носом по тросу и — благодаря
## поперечному сопротивлению воды (киль) — встаёт в кильватер.
##
## Устойчивость явной схемы. Худший случай — сила поперёк корпусов на плече
## ~32 px: приведённая масса пары точек m_red ~ 0.28 кг (масса 2 кг, момент
## инерции ~813). Нужно stiffness * dt^2 / m_red и damping * dt / m_red
## заметно меньше 1..2; при 60 Гц и значениях по умолчанию это ~0.3 и ~1.2.
## Повышая жёсткость или демпфирование, держите это в уме.
##
## Узел же рисует трос (Line2D в мировых координатах, top_level): натянутый —
## прямой, провисший — дугой, глубина которой соответствует слабине.
##
## Точки крепления — узлы Node2D (Marker2D), дочерние к телам; тело —
## ближайший предок RigidBody2D. attached = false отключает трос (физику и
## отрисовку) — для будущей механики зацепа/отцепа.

## Точка крепления на буксире (корма буксира).
@export var tug_point: Node2D
## Точка крепления на буксируемой лодке (нос).
@export var towed_point: Node2D
## Трос подключён: тянет и рисуется.
@export var attached: bool = true

@export_group("Physics")
## Длина троса без натяжения, px. ~1.5 длины корпуса динги (64).
@export_range(1.0, 1000.0, 1.0) var length: float = 100.0
## Жёсткость, Н/px: сила на 1 px растяжения.
@export_range(0.0, 5000.0, 1.0) var stiffness: float = 300.0
## Демпфирование, Н*s/px: гасит колебания растяжения.
@export_range(0.0, 500.0, 0.5) var damping: float = 20.0
## Предел силы, Н: страховка от "взрыва" при рывке или застревании.
@export_range(0.0, 100000.0, 10.0) var max_force: float = 5000.0

@export_group("Visual")
## Число отрезков дуги провисшего троса.
@export_range(2, 64, 1) var sag_segments: int = 16

var _tug_body: RigidBody2D
var _towed_body: RigidBody2D
## Сила натяжения на последнем шаге физики, Н. Только для чтения (отладка).
var current_force: float = 0.0
## Растяжение на последнем шаге физики, px (отрицательное — слабина).
var current_stretch: float = 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY
	_tug_body = TowRope.find_body(tug_point)
	_towed_body = TowRope.find_body(towed_point)
	if _tug_body == null or _towed_body == null:
		push_error("TowRope: tug_point and towed_point must be children of RigidBody2D")
		set_physics_process(false)
		set_process(false)
		visible = false


func _physics_process(_delta: float) -> void:
	current_force = 0.0
	current_stretch = 0.0
	if not attached:
		return
	var a: Vector2 = tug_point.global_position
	var b: Vector2 = towed_point.global_position
	var chord: Vector2 = b - a
	var distance: float = chord.length()
	current_stretch = distance - length
	if current_stretch <= 0.0 or distance < 0.001:
		return

	var direction: Vector2 = chord / distance
	var va: Vector2 = TowRope.point_velocity(_tug_body, a)
	var vb: Vector2 = TowRope.point_velocity(_towed_body, b)
	var stretch_rate: float = (vb - va).dot(direction)
	current_force = TowRope.rope_force(current_stretch, stretch_rate, stiffness, damping, max_force)
	if current_force <= 0.0:
		return

	# Буксир тянет к буксируемой, буксируемую — к буксиру.
	var pull: Vector2 = direction * current_force
	_tug_body.apply_force(pull, a - _tug_body.global_position)
	_towed_body.apply_force(-pull, b - _towed_body.global_position)


func _process(_delta: float) -> void:
	visible = attached
	if not attached:
		return
	points = TowRope.rope_polyline(
		tug_point.global_position, towed_point.global_position, length, sag_segments)


## Ближайший предок-RigidBody2D узла (или null).
static func find_body(node: Node) -> RigidBody2D:
	var current: Node = node
	while current != null:
		var body: RigidBody2D = current as RigidBody2D
		if body != null:
			return body
		current = current.get_parent()
	return null


## Скорость точки тела в мировых координатах: v + omega x r.
static func point_velocity(body: RigidBody2D, point: Vector2) -> Vector2:
	var r: Vector2 = point - body.global_position
	return body.linear_velocity + Vector2(-r.y, r.x) * body.angular_velocity


## Сила натяжения троса, Н. Ноль при слабине; при натяжении — упругость
## плюс демпфирование, обрезанные в [0, limit]: трос никогда не толкает.
## Чистая функция без состояния — пригодна для юнит-тестов.
static func rope_force(stretch: float, stretch_rate: float,
		k: float, c: float, limit: float) -> float:
	if stretch <= 0.0:
		return 0.0
	return clampf(k * stretch + c * stretch_rate, 0.0, limit)


## Глубина провиса дуги с хордой chord и длиной rope_length, px.
## Приближение параболы: длина ~ chord + 8 h^2 / (3 chord), откуда
## h = sqrt(3 * chord * (rope_length - chord) / 8). Натянутый трос — 0.
static func sag_depth(chord: float, rope_length: float) -> float:
	if chord >= rope_length or chord <= 0.0:
		return 0.0
	return sqrt(3.0 * chord * (rope_length - chord) / 8.0)


## Точки ломаной троса от a до b: прямая при натяжении, парабола при
## слабине. Провис откладывается вбок от хорды, на одну и ту же сторону.
static func rope_polyline(a: Vector2, b: Vector2, rope_length: float, segments: int) -> PackedVector2Array:
	var chord: Vector2 = b - a
	var depth: float = TowRope.sag_depth(chord.length(), rope_length)
	if depth <= 0.0:
		return PackedVector2Array([a, b])
	var normal: Vector2 = chord.orthogonal().normalized()
	var result: PackedVector2Array = PackedVector2Array()
	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments)
		# 4 t (1 - t) — парабола с вершиной 1 в середине хорды.
		result.append(a + chord * t + normal * (depth * 4.0 * t * (1.0 - t)))
	return result
