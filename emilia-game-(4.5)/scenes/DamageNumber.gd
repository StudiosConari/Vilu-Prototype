extends Label3D

# Numero de dano flotante: sube, crece un poco y se desvanece.

var _t := 0.0
var _life := 0.75
var _vy := 2.0


func setup(amount: float, big: bool) -> void:
	text = str(int(round(amount)))
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	pixel_size = 0.0011
	font_size = 64 if big else 48
	outline_size = 12
	modulate = Color(1.0, 0.55, 0.2) if big else Color(1.0, 0.92, 0.35)
	outline_modulate = Color.BLACK


func _process(delta: float) -> void:
	_t += delta
	position.y += _vy * delta
	_vy = maxf(0.3, _vy - 3.0 * delta)
	var k := _t / _life
	modulate.a = clampf(1.0 - k, 0.0, 1.0)
	var s := 1.0 + minf(k, 0.4) * 0.6
	scale = Vector3(s, s, s)
	if _t >= _life:
		queue_free()
