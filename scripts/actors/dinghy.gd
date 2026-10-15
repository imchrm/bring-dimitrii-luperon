extends RigidBody2D
## Dinghy — небольшая надувная лодка.
##
## Вид сверху, гравитации нет (gravity_scale = 0). "Вода" моделируется
## демпфированием: linear_damp гасит скорость (сопротивление воды),
## angular_damp гасит вращение. Лодка сама замедляется и останавливается.
##
## Направление "вперёд" — локальная ось +X (нос корпуса нарисован вдоль +X).
## Тяга прикладывается вдоль forward; руль (torque) работает тем сильнее,
## чем быстрее идёт лодка — как настоящий руль, которому нужен поток воды.
##
## has_engine = false превращает эту же сцену в заглохшую динги, которую
## предстоит буксировать (точка крепления троса — узел TowPoint на корме).
## Сам трос (DampedSpringJoint2D от TowPoint) здесь намеренно не подключён —
## это следующий шаг-прототип, главный технический риск проекта.

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


func _physics_process(_delta: float) -> void:
	if not has_engine:
		return

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
