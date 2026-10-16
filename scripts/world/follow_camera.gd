class_name FollowCamera
extends Camera2D
## FollowCamera — камера, привязанная к курсу лодки.
##
## Добавляется дочерним узлом к цели (в проекте — к динги игрока) и только
## читает её global_transform. Узел переводится в top_level, чтобы
## положение и поворот камеры задавались здесь, а не наследовались.
##
## Поворот: камера разворачивает вид так, что нос цели (локальная +X)
## смотрит вверх экрана. Разворот следует за курсом с запаздыванием первого
## порядка (rotation_lag, с): в установившемся повороте с угловой скоростью
## omega камера отстаёт на omega * rotation_lag рад. При полном руле динги
## (~91 град/с) и rotation_lag = 0.15 это ~14 град — камера "немного не
## поспевает" за поворотом и плавно догоняет его после.
##
## Положение: центр вида — на цели плюс look_ahead вверх экрана, то есть
## лодка стоит в нижней части экрана и впереди видно больше воды.
##
## Обновление — в шаге физики (process_callback = Physics): цель — тело,
## которое движется только на шагах физики; иначе на мониторах 120/144 Гц
## камера дёргалась бы относительно лодки.

## Время запаздывания поворота камеры за курсом, с. 0 — без инерции.
@export_range(0.0, 2.0, 0.01) var rotation_lag: float = 0.15
## Смещение центра вида вперёд по курсу (вверх экрана), px.
@export_range(0.0, 1000.0, 1.0) var look_ahead: float = 280.0

var _target: Node2D


func _ready() -> void:
	_target = get_parent() as Node2D
	if _target == null:
		push_error("FollowCamera: parent must be a Node2D")
		set_physics_process(false)
		return
	top_level = true
	ignore_rotation = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	rotation = FollowCamera.view_rotation_for_heading(_target.global_rotation)
	_place()
	reset_smoothing()


func _physics_process(delta: float) -> void:
	var target_rotation: float = FollowCamera.view_rotation_for_heading(_target.global_rotation)
	rotation = FollowCamera.smooth_angle(rotation, target_rotation, rotation_lag, delta)
	_place()


func _place() -> void:
	# Вверх экрана в мировых координатах — это (0, -1), повёрнутый на
	# текущий (запаздывающий) поворот камеры.
	global_position = _target.global_position + Vector2(0.0, -look_ahead).rotated(rotation)


## Поворот камеры, при котором направление heading (рад, мир) смотрит вверх
## экрана. Камера с поворотом r показывает вверху мировое направление
## (0, -1).rotated(r) = (sin r, -cos r); приравнивая его к
## (cos heading, sin heading), получаем r = heading + PI/2.
static func view_rotation_for_heading(heading: float) -> float:
	return heading + PI * 0.5


## Экспоненциальное сглаживание угла (запаздывание первого порядка) с
## постоянной времени lag, с. Не зависит от частоты кадров и идёт по
## кратчайшей дуге (lerp_angle). lag <= 0 — мгновенно к цели.
## Чистая функция без состояния — пригодна для юнит-тестов.
static func smooth_angle(current: float, target: float, lag: float, delta: float) -> float:
	if lag <= 0.0:
		return target
	return lerp_angle(current, target, 1.0 - exp(-delta / lag))
