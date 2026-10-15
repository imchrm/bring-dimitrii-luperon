extends Node2D
## Luperon — залив Luperón, одна "версия" игры (один самодостаточный мир).
##
## Мир собран вручную: вода, береговая линия, док и пара пришвартованных
## лодок-препятствий, плюс управляемая игроком динги (Dinghy). Заглохшая
## динги (DinghyToTow, has_engine = false) — будущая цель буксировки.
##
## Следующий шаг-прототип (не здесь): трос от Dinghy/TowPoint к
## DinghyToTow через DampedSpringJoint2D, с запасным вариантом на
## Rapier/Box2D RopeJoint2D, если натяжение/устойчивость не устроят.

func _ready() -> void:
	print("Luperon bay loaded. Управление: WASD / стрелки.")
