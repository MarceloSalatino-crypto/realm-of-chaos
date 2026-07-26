extends SceneTree

const LightningEffectScript = preload("res://scripts/lightning_effect.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("LIGHTNING EFFECT: " + message)


func _run() -> void:
	var effect = LightningEffectScript.new()
	effect.animation_time = 0.37
	var start := Vector2(10.0, 20.0)
	var finish := Vector2(130.0, 20.0)
	var segment: PackedVector2Array = effect._build_jagged_segment(start, finish, 0, 5)

	_check(segment.size() == 7, "segmento não contém início, cinco desvios e fim")
	_check(segment[0].is_equal_approx(start), "segmento perdeu o ponto inicial")
	_check(segment[-1].is_equal_approx(finish), "segmento perdeu o ponto final")
	for index in range(1, segment.size() - 1):
		_check(not segment[index].is_equal_approx(finish), "ponto final foi inserido antes do fim do raio")
		_check(segment[index].x > segment[index - 1].x, "raio voltou para trás durante o traçado")

	effect.free()
	if failures.is_empty():
		print("LIGHTNING EFFECT OK: traçado progride até o alvo sem retornos intermediários")
		quit(0)
	else:
		quit(1)
