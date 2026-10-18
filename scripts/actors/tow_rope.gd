class_name TowRope
extends Line2D
## TowRope — буксирный трос буксира: зацеп, отцеп и физика троса.
##
## Трос принадлежит буксиру: один конец всегда на tug_point (корма буксира),
## второй цепляется к точке крепления другой лодки (towed_point, её нос).
##
## Зацеп и отцеп — действие hook_action (по умолчанию "tow": Space / E).
## Кандидаты на зацеп — узлы группы hook_group ("tow_points"; в prefab динги
## это BowPoint), кроме точек на самом буксире. Если трос не подцеплен и
## ближайший кандидат ближе hook_radius к tug_point, нажатие цепляет трос
## к нему; если подцеплен — то же нажатие отдаёт трос. Пока кандидат в
## зоне, вокруг него пульсирует кольцо-подсказка. Сигналы hooked / released
## сообщают о зацепе и отцепе (пригодятся для цели уровня).
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

## Трос подцеплен к towed_point.
signal hooked(target: RigidBody2D)
## Трос отдан; target — лодка, которая была на буксире.
signal released(target: RigidBody2D)

## Точка крепления на буксире (корма буксира).
@export var tug_point: Node2D
## Точка крепления на буксируемой лодке (нос). Если задана в сцене, трос
## подцеплен к ней с начала; иначе назначается при зацепе.
@export var towed_point: Node2D

@export_group("Hook")
## Действие ввода для зацепа / отцепа.
@export var hook_action: StringName = &"tow"
## Группа узлов — точек, за которые можно зацепить трос.
@export var hook_group: StringName = &"tow_points"
## Наибольшее расстояние от tug_point до точки зацепа, px.
@export_range(1.0, 500.0, 1.0) var hook_radius: float = 48.0
## Цвет кольца-подсказки вокруг точки, доступной для зацепа.
@export var hint_color: Color = Color(1.0, 0.9, 0.4, 0.9)

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
## Точка, доступная для зацепа прямо сейчас (null — нет кандидата в зоне).
var _hook_candidate: Node2D
var _hint_time: float = 0.0
## Сила натяжения на последнем шаге физики, Н. Только для чтения (отладка).
var current_force: float = 0.0
## Растяжение на последнем шаге физики, px (отрицательное — слабина).
var current_stretch: float = 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY
	_tug_body = TowRope.find_body(tug_point)
	if _tug_body == null:
		push_error("TowRope: tug_point must be a child of RigidBody2D")
		set_physics_process(false)
		set_process(false)
		return
	var initial: Node2D = towed_point
	towed_point = null
	if initial != null:
		hook(initial)


## Трос подцеплен.
func is_attached() -> bool:
	return towed_point != null


## Лодка на буксире (null, если трос не подцеплен).
func get_towed_body() -> RigidBody2D:
	return _towed_body


## Цепляет трос к точке point. false — если point не на твёрдом теле или
## это точка на самом буксире. Предыдущий зацеп при этом отдаётся.
func hook(point: Node2D) -> bool:
	var body: RigidBody2D = TowRope.find_body(point)
	if body == null or body == _tug_body:
		return false
	if is_attached():
		release()
	towed_point = point
	_towed_body = body
	hooked.emit(body)
	return true


## Отдаёт трос. Ничего не делает, если трос не подцеплен.
func release() -> void:
	if not is_attached():
		return
	var body: RigidBody2D = _towed_body
	towed_point = null
	_towed_body = null
	current_force = 0.0
	current_stretch = 0.0
	released.emit(body)


## Ближайшая точка группы hook_group в радиусе hook_radius от tug_point,
## не принадлежащая буксиру; null — если такой нет.
func find_hook_candidate() -> Node2D:
	var origin: Vector2 = tug_point.global_position
	var best: Node2D = null
	var best_distance: float = hook_radius
	for node: Node in get_tree().get_nodes_in_group(hook_group):
		var point: Node2D = node as Node2D
		if point == null or TowRope.find_body(point) == _tug_body:
			continue
		var distance: float = origin.distance_to(point.global_position)
		if distance <= best_distance:
			best = point
			best_distance = distance
	return best


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(hook_action):
		if is_attached():
			release()
		else:
			var candidate: Node2D = find_hook_candidate()
			if candidate != null:
				hook(candidate)
	_apply_rope_force()


func _apply_rope_force() -> void:
	current_force = 0.0
	current_stretch = 0.0
	if not is_attached():
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


func _process(delta: float) -> void:
	if is_attached():
		_hook_candidate = null
		points = TowRope.rope_polyline(
			tug_point.global_position, towed_point.global_position, length, sag_segments)
	else:
		_hook_candidate = find_hook_candidate()
		points = PackedVector2Array()
	_hint_time += delta
	queue_redraw()


## Кольцо-подсказка вокруг точки, доступной для зацепа. Рисуется поверх
## линии троса (Line2D рисует свои points сам).
func _draw() -> void:
	if _hook_candidate == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(_hint_time * TAU * 1.5)
	var color: Color = hint_color
	color.a *= lerpf(0.4, 1.0, pulse)
	draw_arc(_hook_candidate.global_position, lerpf(9.0, 13.0, pulse), 0.0, TAU, 24, color, 2.0)


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
