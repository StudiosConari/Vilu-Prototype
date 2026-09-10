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
	assert_almost_eq(GUANACO.ALTO, 2.94, 0.01, "la mitad más que los 1,96 de antes")
	assert_almost_eq(GUANACO.ESCALA * GUANACO.ALTO_DEL_MODELO, 2.94, 0.01,
		"y la escala sale de dividir, no del número viejo")
	assert_between(GUANACO.ESCALA, 1.7, 2.0, "ronda 1,84")


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


## Al invocarlo aparece donde después va a seguirte: a un lado y a la misma
## distancia. A 1,8 m quedaba a un cuerpo entero, suelto.
func test_aparece_a_la_distancia_a_la_que_sigue() -> void:
	assert_between(GUANACO.FOLLOW_DIST, 1.0, 1.4, "pegado al lado, sin montársele encima")
	var src := (load("res://scenes/actors/PlayerController.gd") as GDScript).source_code
	assert_true(src.contains("basis.x * GUANACO_COMP_SCR.FOLLOW_DIST"),
		"invocar usa la misma distancia que seguir")


## Q invoca y guarda; C sube y baja SIN que el guanaco desaparezca.
class GuanacoQueEspera extends Node3D:
	var montado := false

	func set_mounted(v: bool) -> void:
		montado = v


func _benjamin_en_el_arbol() -> CharacterBody3D:
	var p: CharacterBody3D = load("res://scenes/actors/Player.tscn").instantiate()
	p.is_archer = true
	add_child_autofree(p)
	return p


func test_c_sube_y_baja_sin_guardar_el_guanaco() -> void:
	var p := _benjamin_en_el_arbol()
	var g := GuanacoQueEspera.new()
	g.add_to_group("guanaco_companion")
	add_child_autofree(g)

	p.call("_alternar_montura")
	assert_true(p.mounted, "la primera C lo sube")
	assert_true(g.montado)
	p.call("_alternar_montura")
	assert_false(p.mounted, "la segunda lo baja")
	assert_false(g.montado)
	await wait_frames(1)
	assert_true(is_instance_valid(g) and g.is_inside_tree(), "y el guanaco sigue ahí, esperando")


func test_q_con_guanaco_lo_guarda_aunque_vaya_montado() -> void:
	var p := _benjamin_en_el_arbol()
	var g := GuanacoQueEspera.new()
	g.add_to_group("guanaco_companion")
	add_child_autofree(g)
	p.call("_alternar_montura")
	p.call("_alternar_guanaco")
	assert_false(p.mounted, "se baja")
	await wait_frames(1)
	assert_false(is_instance_valid(g), "y el guanaco se guarda")


func test_c_sin_guanaco_no_hace_nada() -> void:
	var p := _benjamin_en_el_arbol()
	p.call("_alternar_montura")
	assert_false(p.mounted)
	assert_null(p.call("guanaco_companion"), "invocar es cosa de Q")


func test_montar_tiene_su_tecla_y_su_boton() -> void:
	assert_true(InputMap.has_action("guanaco_montar"), "existe la acción")
	var teclas := 0
	var botones := 0
	for e in InputMap.action_get_events("guanaco_montar"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_C:
			teclas += 1
		if e is InputEventJoypadButton:
			botones += 1
	assert_eq(teclas, 1, "con la C")
	assert_eq(botones, 1, "y un botón del mando")
	assert_true(load("res://scenes/core/Remapeo.gd").EDITABLES.has("guanaco_montar"),
		"y se puede cambiar en opciones")


## El letrero de abajo a la derecha enseña el guanaco en cuanto se tiene.
func test_el_letrero_de_controles_enseña_el_guanaco() -> void:
	var hud: CanvasLayer = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	await wait_frames(1)
	GameManager.reset_progress()
	hud.show_swap_hint(true)
	var sin: String = hud.get("_swap").text
	assert_false(sin.contains("montar"), "sin guanaco no se menciona")
	GameManager.unlock("guanaco")
	await wait_frames(1)
	var con: String = hud.get("_swap").text
	assert_true(con.contains("[Q] invocar") and con.contains("[C] montar") and con.contains("[G] embestir"),
		"con guanaco: Q invocar, C montar, G embestir")
	assert_true(con.contains("cambiar"), "sin perder lo de cambiar de personaje")
	GameManager.reset_progress()

