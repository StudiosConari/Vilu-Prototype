extends "res://addons/gut/test.gd"

## El cierre del prototipo: con todos los logros menos el suyo, volver a la mina
## deja de ser una huida y pasa a ser el duelo contra el Chupacabras.

const MINA := preload("res://scenes/regions/Mina.tscn")


func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func _cueva() -> Node:
	var m := MINA.instantiate()
	add_child_autofree(m)
	await wait_physics_frames(2)
	for n in m.get_children():
		var s: Script = n.get_script()
		if s != null and String(s.resource_path).ends_with("MinaCueva.gd"):
			return n
	return m


func _senuelo() -> Node3D:
	var j := Node3D.new()
	j.add_to_group("player")
	add_child_autofree(j)
	return j


func _todos_menos_el_chupacabras() -> void:
	for l in GameManager.LOGROS:
		if l["id"] != "chupacabras":
			GameManager.conceder(l["id"])
	assert_false(GameManager.prototipo_completo(), "falta justo el suyo")


func test_sin_los_logros_la_mina_sigue_siendo_una_huida() -> void:
	var c := await _cueva()
	assert_false(c._toca_el_duelo(), "recién empezada no toca el duelo")
	c._combat_cleared = true
	c._on_nest_enter(_senuelo())
	assert_true(c._chase_active, "arranca la persecución de siempre")
	assert_false(c._duelo_activo)
	c._chase_active = false


func test_con_todos_los_demas_logros_planta_cara() -> void:
	_todos_menos_el_chupacabras()
	var c := await _cueva()
	assert_true(c._toca_el_duelo())
	# A propósito SIN _combat_cleared: se vuelve a buscarlo y el camino al nido
	# está abierto, no hay que volver a despejar a los mineros.
	c._on_nest_enter(_senuelo())
	assert_true(c._duelo_activo, "se planta")
	assert_false(c._chase_active, "y ya no se huye")
	assert_not_null(c._chupa_jefe, "aparece como enemigo, no como perseguidor")
	assert_true(c._chupa_jefe.is_boss)
	assert_gt(c._chupa_jefe.max_health, 0.0)


func test_vencerlo_concede_el_logro_y_cierra_el_prototipo() -> void:
	_todos_menos_el_chupacabras()
	var c := await _cueva()
	c._on_nest_enter(_senuelo())
	watch_signals(GameManager)
	c._chupa_jefe.take_damage(99999.0, Vector3.ZERO)
	await wait_physics_frames(2)
	assert_true(GameManager.tiene_logro("chupacabras"), "vencerlo lo concede")
	assert_true(GameManager.prototipo_completo(), "y con eso se supera el prototipo")
	assert_signal_emitted(GameManager, "prototipo_superado")


func test_una_vez_vencido_no_vuelve_a_haber_duelo() -> void:
	for l in GameManager.LOGROS:
		GameManager.conceder(l["id"])
	var c := await _cueva()
	assert_false(c._toca_el_duelo(), "ya está hecho, la mina no lo repite")


func test_el_duelo_no_se_dispara_dos_veces() -> void:
	_todos_menos_el_chupacabras()
	var c := await _cueva()
	var j := _senuelo()
	c._on_nest_enter(j)
	var primero = c._chupa_jefe
	c._on_nest_enter(j)
	assert_eq(c._chupa_jefe, primero, "cruzar de nuevo no invoca un segundo")
