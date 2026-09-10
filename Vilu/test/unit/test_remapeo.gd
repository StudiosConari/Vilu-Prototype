extends GutTest

## Controles configurables: cambiar un botón, resolver choques intercambiando,
## guardar y volver a aplicar.

const REMAPEO := preload("res://scenes/core/Remapeo.gd")


func after_each() -> void:
	REMAPEO.restablecer()


func _tecla(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e


func _boton(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	return e


func _tiene(accion: String, e: InputEvent) -> bool:
	for x in InputMap.action_get_events(accion):
		if REMAPEO.iguales(x, e):
			return true
	return false


func test_ida_y_vuelta_de_cada_tipo_de_evento() -> void:
	var raton := InputEventMouseButton.new()
	raton.button_index = MOUSE_BUTTON_RIGHT
	var eje := InputEventJoypadMotion.new()
	eje.axis = JOY_AXIS_TRIGGER_RIGHT
	eje.axis_value = 0.8
	for e in [_tecla(KEY_J), raton, _boton(JOY_BUTTON_Y), eje]:
		var d: Dictionary = REMAPEO.serializar(e)
		var vuelta := REMAPEO.deserializar(d)
		assert_true(REMAPEO.iguales(e, vuelta), "sobrevive al guardado: %s" % d)


func test_cambiar_la_tecla_no_toca_el_boton_del_mando() -> void:
	var antes_mando: Array = REMAPEO.eventos_de("jump", true)
	var mapa: Dictionary = REMAPEO.asignar({}, "jump", _tecla(KEY_J), false)
	assert_true(_tiene("jump", _tecla(KEY_J)), "saltar ahora es la J")
	assert_false(_tiene("jump", _tecla(KEY_SPACE)), "y ya no el espacio")
	assert_eq(REMAPEO.eventos_de("jump", true).size(), antes_mando.size(),
		"el mando sigue como estaba")
	assert_true(mapa.has("jump"))
	assert_eq(mapa["jump"][REMAPEO.TECLADO].size(), 1)


func test_un_choque_se_resuelve_intercambiando() -> void:
	# Interactuar está en la X del mando; se la pido para saltar.
	var x := _boton(JOY_BUTTON_X)
	var a := _boton(JOY_BUTTON_A)
	assert_true(_tiene("interact", x), "de fábrica, interactuar es X")
	assert_true(_tiene("jump", a), "y saltar es A")
	var mapa: Dictionary = REMAPEO.asignar({}, "jump", x, true)
	assert_true(_tiene("jump", x), "saltar pasa a X")
	assert_true(_tiene("interact", a), "e interactuar se queda con la A que soltó saltar")
	assert_false(_tiene("interact", x), "nadie se queda con dos")
	assert_true(mapa.has("interact"), "el intercambio también se guarda")


func test_lo_guardado_se_vuelve_a_aplicar_tras_restablecer() -> void:
	var mapa: Dictionary = REMAPEO.asignar({}, "rodar", _tecla(KEY_C), false)
	REMAPEO.restablecer()
	assert_false(_tiene("rodar", _tecla(KEY_C)), "de fábrica no está")
	REMAPEO.aplicar(mapa)
	assert_true(_tiene("rodar", _tecla(KEY_C)), "y al aplicar el mapa vuelve")


func test_lo_que_no_es_editable_no_se_toca() -> void:
	var mapa: Dictionary = REMAPEO.asignar({}, "move_forward", _tecla(KEY_J), false)
	assert_false(mapa.has("move_forward"))
	assert_false(_tiene("move_forward", _tecla(KEY_J)))


func test_que_se_puede_asignar() -> void:
	var eco := _tecla(KEY_J)
	eco.echo = true
	assert_false(REMAPEO.es_asignable(eco, false), "un eco de tecla no")
	assert_false(REMAPEO.es_asignable(_tecla(KEY_ESCAPE), false), "Escape cancela, no asigna")
	assert_true(REMAPEO.es_asignable(_tecla(KEY_J), false))
	assert_false(REMAPEO.es_asignable(_tecla(KEY_J), true), "una tecla no vale para el mando")
	var flojo := InputEventJoypadMotion.new()
	flojo.axis = JOY_AXIS_TRIGGER_LEFT
	flojo.axis_value = 0.2
	assert_false(REMAPEO.es_asignable(flojo, true), "un gatillo apenas rozado no")
	assert_true(REMAPEO.es_asignable(_boton(JOY_BUTTON_B), true))
