extends GutTest

## El guanaco compañero pasó a usar el modelo animado de la quebrada.
##
## El espiritual traía un solo clip y un esqueleto de 24 huesos: los clips
## nuevos no le entraban. Con el cambio se lleva los seis, y el paso deja de ser
## un deslizamiento con las patas clavadas.

const GUANACO := preload("res://scenes/actors/GuanacoCompanion.gd")


func _guanaco() -> Node3D:
	var g := Node3D.new()
	g.set_script(GUANACO)
	add_child_autofree(g)
	return g


func _animador(n: Node) -> AnimationPlayer:
	for h in n.get_children():
		if h is AnimationPlayer:
			return h
		var x := _animador(h)
		if x != null:
			return x
	return null


# ─── El modelo y su tamaño ───────────────────────────────────────────────────

func test_usa_el_modelo_animado() -> void:
	var g := _guanaco()
	var ap := _animador(g)
	assert_not_null(ap, "trae reproductor")
	if ap == null:
		return
	for c in ["Idle", "Walk", "Run", "Kick"]:
		assert_true(ap.has_animation(c), "tiene '%s'" % c)


func test_sigue_midiendo_lo_de_siempre() -> void:
	# El espiritual medía 0.98 m y llevaba escala 2. Éste mide 1.60: aplicarle
	# el factor viejo lo dejaría en 3,20 m, como un caballo de tiro.
	assert_almost_eq(GUANACO.ALTO, 1.96, 0.01, "la altura pedida no cambió")
	assert_almost_eq(GUANACO.ESCALA * GUANACO.ALTO_DEL_MODELO, 1.96, 0.01,
		"y la escala sale de dividir, no del número viejo")
	assert_between(GUANACO.ESCALA, 1.1, 1.4, "ronda 1,23, no 2")


func test_arranca_quieto_y_no_congelado() -> void:
	var g := _guanaco()
	var ap := _animador(g)
	assert_eq(ap.assigned_animation, "Idle", "respira desde el primer momento")
	assert_eq(ap.get_animation("Idle").loop_mode, Animation.LOOP_LINEAR)


# ─── Qué clip según cómo se mueve ────────────────────────────────────────────

func test_camina_despacio_y_corre_deprisa() -> void:
	var g := _guanaco()
	var ap := _animador(g)
	g.set("_ready_done", true)

	# Quieto.
	g.set("_pos_previa", g.global_position)
	g.call("_animar", 0.1)
	assert_eq(ap.assigned_animation, "Idle", "parado, respira")

	# A paso.
	g.set("_pos_previa", g.global_position - Vector3(0.3, 0, 0))
	g.call("_animar", 0.1)          # 3 m/s
	assert_eq(ap.assigned_animation, "Walk", "a 3 m/s camina")

	# A la carrera.
	g.set("_pos_previa", g.global_position - Vector3(1.2, 0, 0))
	g.call("_animar", 0.1)          # 12 m/s
	assert_eq(ap.assigned_animation, "Run", "a 12 m/s corre")


func test_el_paso_acompana_la_velocidad() -> void:
	var g := _guanaco()
	var ap := _animador(g)
	g.set("_ready_done", true)
	g.set("_pos_previa", g.global_position - Vector3(0.2, 0, 0))
	g.call("_animar", 0.1)
	assert_gt(ap.speed_scale, 0.0, "no patina: el ritmo sigue a la velocidad")


# ─── La coz que hace de salto ────────────────────────────────────────────────

func test_al_saltar_da_la_coz() -> void:
	var g := _guanaco()
	var ap := _animador(g)
	g.call("saltar")
	assert_eq(ap.assigned_animation, "Kick", "patea")
	assert_eq(ap.get_animation("Kick").loop_mode, Animation.LOOP_NONE,
		"una vez, no en bucle")
	assert_gt(float(g.get("_salto_restante")), 0.0, "y se anota cuánto dura")


func test_la_coz_no_se_corta_al_aterrizar() -> void:
	var g := _guanaco()
	var ap := _animador(g)
	g.set("_ready_done", true)
	g.call("saltar")
	# Mientras dura, moverse no debe cambiarle el clip.
	g.set("_pos_previa", g.global_position - Vector3(1.0, 0, 0))
	g.call("_animar", 0.1)
	assert_eq(ap.assigned_animation, "Kick", "sigue pateando")
	# Y al agotarse, vuelve a mandar el paso.
	g.set("_salto_restante", 0.0)
	g.set("_pos_previa", g.global_position)
	g.call("_animar", 0.1)
	assert_eq(ap.assigned_animation, "Idle", "recupera el mando")
