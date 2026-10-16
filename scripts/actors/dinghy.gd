class_name Dinghy
extends RigidBody2D
## Dinghy — небольшая надувная лодка.
##
## Вид сверху, гравитации нет (gravity_scale = 0). "Вода" моделируется
## сопротивлением, разным вдоль и поперёк корпуса: вдоль (forward_drag) лодка
## идёт легко, поперёк (lateral_drag) — сопротивление в разы выше, как у
## корпуса с килем. Благодаря этому лодка не скользит боком в поворотах, а
## буксируемая динги выстраивается в кильватер за буксиром. Встроенный
## linear_damp отключён (linear_damp_mode = Replace, 0) — всё линейное
## сопротивление считается здесь. Вращение по-прежнему гасит angular_damp.
##
## Направление "вперёд" — локальная ось +X (нос корпуса нарисован вдоль +X).
## Тяга прикладывается вдоль forward; руль (torque) работает тем сильнее,
## чем быстрее идёт лодка — как настоящий руль, которому нужен поток воды.
##
## has_engine = false превращает эту же сцену в заглохшую динги, которую
## предстоит буксировать: управление отключается, сопротивление воды остаётся.
## Точки крепления троса: TowPoint на корме (буксир), BowPoint на носу
## (буксируемая). Сам трос здесь намеренно не подключён — это следующий
## шаг-прототип, главный технический риск проекта.

## Сила тяги двигателя вперёд, Н.
@export var engine_force: float = 1100.0
## Сила заднего хода, Н.
@export var reverse_force: float = 450.0
## Момент поворота (руль), Н*м при полной скорости.
@export var turn_torque: float = 9000.0
## Скорость, при которой руль выходит на полную эффективность, px/s.
@export var full_rudder_speed: float = 60.0
## Есть ли рабочий мотор. false = объект для буксировки.
@export var has_engine: bool = true

@export_group("Water drag")
## Продольное сопротивление, 1/s: доля продольной скорости, гасимая за
## секунду (смысл как у linear_damp). Определяет максимальную скорость.
@export_range(0.0, 20.0, 0.1) var forward_drag: float = 2.1
## Поперечное сопротивление, 1/s. Чем выше относительно forward_drag, тем
## меньше снос боком ("киль"). Сила считается по скорости прошлого шага,
## поэтому drag * шаг физики должно быть меньше 1 (при 60 Гц — drag < 60),
## иначе поперечная скорость начнёт колебаться со сменой знака.
@export_range(0.0, 30.0, 0.1) var lateral_drag: float = 12.0


func _physics_process(_delta: float) -> void:
	_apply_water_drag()
	if has_engine:
		_apply_controls()


## Линейное сопротивление воды, раздельно по осям корпуса.
func _apply_water_drag() -> void:
	# Статический метод своего класса вызывается без префикса "Dinghy.":
	# так скрипт не зависит от кеша глобальных классов редактора.
	var drag_accel: Vector2 = water_drag_acceleration(
		linear_velocity, rotation, forward_drag, lateral_drag)
	apply_central_force(drag_accel * mass)


func _apply_controls() -> void:
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)

	# Тяга: thrust - reverse даёт знак и величину в диапазоне [-1, 1].
	var throttle: float = Input.get_action_strength(&"thrust") - Input.get_action_strength(&"reverse")
	if throttle > 0.0:
		apply_central_force(forward * engine_force * throttle)
	elif throttle < 0.0:
		apply_central_force(forward * reverse_force * throttle)

	# Руль: бьёт только когда корпус движется сквозь воду.
	var steer: float = Input.get_action_strength(&"steer_right") - Input.get_action_strength(&"steer_left")
	var speed_factor: float = clampf(linear_velocity.length() / full_rudder_speed, 0.0, 1.0)
	apply_torque(steer * turn_torque * speed_factor)


## Ускорение от сопротивления воды (px/s^2) для скорости velocity корпуса,
## повёрнутого на heading (рад). Скорость раскладывается на продольную (вдоль
## носа, +X) и поперечную составляющие, каждая гасится своим коэффициентом.
## Чистая функция без состояния — пригодна для юнит-тестов.
static func water_drag_acceleration(
		velocity: Vector2, heading: float, drag_forward: float, drag_lateral: float) -> Vector2:
	var forward: Vector2 = Vector2.RIGHT.rotated(heading)
	var side: Vector2 = forward.orthogonal()
	var v_forward: float = velocity.dot(forward)
	var v_side: float = velocity.dot(side)
	return -(forward * v_forward * drag_forward + side * v_side * drag_lateral)
