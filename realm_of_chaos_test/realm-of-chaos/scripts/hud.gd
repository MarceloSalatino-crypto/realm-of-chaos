extends CanvasLayer

@onready var health_bar = $HealthBar

func update_hp(current, maximum):
	health_bar.max_value = maximum
	health_bar.value = current
