extends GutTest

## La coreografía del Yastay y sus guanacos.
##
## Se alza (Rear), trota hasta cada cazador y lo derriba de un cabezazo, vuelve
## caminando a su sitio y se alza otra vez antes de perseguirte. Los guanacos
## heridos están tendidos desde el principio y se incorporan al sanarlos.

const ENCUENTRO := preload("res://scenes/actors/YastayEncounter.gd")
const YASTAY := preload("res://models/personaje/yastay.glb")
const GUANACO := preload("res://models/personaje/guanaco.glb")


func _zona() -> Node3D:
	var z := Node3D.new()
	z.set_script(ENCUENTRO)
	add_child_autofree(z)
	return z


func _animador(n: Node) -> AnimationPlayer:
	for h in n.get_children():
		if h is AnimationPlayer:
			return h
		var x := _animador(h)
		if x != null:
			return x
	return null


# ─── El Yastay ───────────────────────────────────────────────────────────────

func test_trae_los_cinco_clips_de_la_escena() -> void:
	var n: Node = YASTAY.instantiate()
	add_child_autofree(n)
	var ap := _animador(n)
	for clip in ["Rear", "Trot", "Head_But", "Walk", "Idle"]:
		assert_true(ap.has_animation(clip), "trae '%s'" % clip)


func test_alzarse_dura_lo_que_dura() -> void:
	var z := _zona()
	var y: Node3D = YASTAY.instantiate()
	z.add_child(y)
	z.set("_yastay", y)
	var t: float = z.call("_yastay_hace", "Rear", false, 1.2)
	assert_almost_eq(t, 2.92, 0.1, "espera el clip entero, no un número inventado")
	assert_eq(_animador(y).assigned_animation, "Rear")


func test_sin_ese_clip_devuelve_el_minimo() -> void:
	var z := _zona()
	var y: Node3D = YASTAY.instantiate()
	z.add_child(y)
	z.set("_yastay", y)
	# Con una cápsula de greybox no hay clips, y la cinemática no puede quedarse
	# esperando cero segundos: el mínimo mantiene el ritmo de la escena.
	assert_almost_eq(float(z.call("_yastay_hace", "NoExiste", false, 1.2)), 1.2, 0.01)


func test_pedir_el_mismo_clip_no_lo_reinicia() -> void:
	# La persecución lo pide en CADA cuadro; relanzarlo lo congelaría.
	var z := _zona()
	var y: Node3D = YASTAY.instantiate()
	z.add_child(y)
	var ap := _animador(y)
	z.call("_clip", y, "Trot", true)
	ap.advance(0.3)
	var donde := ap.current_animation_position
	z.call("_clip", y, "Trot", true)
	assert_almost_eq(ap.current_animation_position, donde, 0.001,
		"sigue por donde iba")


func test_se_para_a_un_cuerpo_del_cazador() -> void:
	var z := _zona()
	var y: Node3D = YASTAY.instantiate()
	z.add_child(y)
	y.global_position = Vector3.ZERO
	z.set("_yastay", y)
	z.call("_yastay_va_a", Vector3(20, 0, 0), "Trot", 999.0, 2.4)
	await wait_seconds(0.4)
	assert_almost_eq(y.global_position.x, 17.6, 0.3,
		"se queda a 2,4 m: va a cabecearlo, no a atravesarlo")


func test_a_su_sitio_vuelve_entero() -> void:
	var z := _zona()
	var y: Node3D = YASTAY.instantiate()
	z.add_child(y)
	y.global_position = Vector3(20, 0, 0)
	z.set("_yastay", y)
	z.call("_yastay_camina_hasta", Vector3.ZERO)
	await wait_seconds(0.4)
	assert_lt(y.global_position.x, 19.9, "arrancó de vuelta")
	assert_eq(_animador(y).assigned_animation, "Walk", "y vuelve caminando")


func test_el_cazador_cae_a_media_embestida() -> void:
	var z := _zona()
	assert_between(float(z.get("MOMENTO_DEL_CABEZAZO")), 0.3, 0.8,
		"ni al empezar el golpe ni cuando ya pasó")


# ─── Los guanacos ────────────────────────────────────────────────────────────

func test_el_herido_esta_tendido_desde_el_principio() -> void:
	var z := _zona()
	var g: Node3D = GUANACO.instantiate()
	z.add_child(g)
	z.call("_tumbar", g)
	var ap := _animador(g)
	assert_eq(ap.assigned_animation, "Death", "en el suelo")
	assert_false(ap.is_playing(), "congelado, no desplomándose una y otra vez")
	assert_almost_eq(ap.current_animation_position, ap.get_animation("Death").length,
		0.05, "en el último fotograma: la pose del final de la caída")


func test_al_sanarlo_se_incorpora_y_luego_respira() -> void:
	var z := _zona()
	var g: Node3D = GUANACO.instantiate()
	z.add_child(g)
	z.call("_tumbar", g)
	z.call("_levantar", g)
	var ap := _animador(g)
	assert_eq(ap.assigned_animation, "lay_to_idle", "se levanta")
	await wait_seconds(ap.get_animation("lay_to_idle").length + 0.3)
	assert_eq(ap.assigned_animation, "Idle", "y se queda de pie, como los demás")


func test_tumbar_algo_sin_ese_clip_no_rompe() -> void:
	var z := _zona()
	var y: Node3D = YASTAY.instantiate()   # el Yastay no tiene 'Death'
	z.add_child(y)
	z.call("_tumbar", y)
	assert_true(true, "no revienta")


# ─── El golpe: marcar, esperar, y recién entonces pegar ──────────────────────
#
# Antes pegaba en el mismo cuadro en que te acercabas: 25 de daño y un cartel
# que decía "¡Esquiva!" cuando ya te había dado. No había nada que esquivar.

## Un jugador de mentira que sólo anota los golpes que recibe.
class JugadorFalso extends Node3D:
	var recibido := 0.0
	var is_archer := false

	func take_damage(x: float) -> void:
		recibido += x


func _en_pelea() -> Node3D:
	var z := _zona()
	var y: Node3D = YASTAY.instantiate()
	z.add_child(y)
	z.set("_yastay", y)
	z.set("_phase", 2)          # Phase.AGGRESSIVE
	y.global_position = Vector3.ZERO
	# Mirando a +X: el frente de estos modelos es +Z, así que se lo gira.
	z.call("_encarar", Vector3.RIGHT)
	return z


func test_marca_el_suelo_antes_de_pegar() -> void:
	var z := _en_pelea()
	var p := JugadorFalso.new()
	p.add_to_group("player")
	z.add_child(p)
	p.global_position = Vector3(z.get("alcance_del_golpe"), 0, 0)

	z.call("_golpear")
	await wait_frames(2)
	var marcas := 0
	for h in z.get_children():
		if h is MeshInstance3D and h.mesh is CylinderMesh:
			marcas += 1
	assert_eq(marcas, 1, "queda marcado dónde va a caer")
	assert_eq(p.recibido, 0.0, "y todavía no pegó: hay tiempo de salir")


func test_pega_al_que_se_queda_dentro() -> void:
	var z := _en_pelea()
	z.set("aviso_del_golpe", 0.3)
	var p := JugadorFalso.new()
	p.add_to_group("player")
	z.add_child(p)
	p.global_position = Vector3(z.get("alcance_del_golpe"), 0, 0)

	z.call("_golpear")
	await wait_seconds(0.8)
	assert_almost_eq(p.recibido, float(z.get("dano_del_golpe")), 0.01,
		"quedarse dentro cuesta")


func test_el_que_se_aparta_no_recibe_nada() -> void:
	var z := _en_pelea()
	z.set("aviso_del_golpe", 0.3)
	var p := JugadorFalso.new()
	p.add_to_group("player")
	z.add_child(p)
	p.global_position = Vector3(z.get("alcance_del_golpe"), 0, 0)

	z.call("_golpear")
	await wait_frames(2)
	# Salirse mientras el círculo se cierra: eso es esquivar.
	p.global_position = Vector3(0, 0, 14)
	await wait_seconds(0.8)
	assert_eq(p.recibido, 0.0, "esquivar sirve")


func test_el_aviso_da_tiempo_de_verdad() -> void:
	var z := _zona()
	assert_gte(float(z.get("aviso_del_golpe")), 1.0,
		"al menos un segundo para salir")


# ─── Los guanacos heridos ────────────────────────────────────────────────────

func _guanaco_herido(z: Node3D) -> Node3D:
	var g: Node3D = GUANACO.instantiate()
	g.name = "guanaco2"
	z.add_child(g)
	z.set("_heridos", [g])
	z.set("_phase", 2)          # Phase.AGGRESSIVE
	z.call("_zona_de_cura", g)
	z.call("_tumbar", g)
	return g


func test_arrancan_tendidos() -> void:
	var z := _zona()
	var g := _guanaco_herido(z)
	var ap := _animador(g)
	assert_eq(ap.assigned_animation, "Death", "tendido, no pastando")
	assert_false(ap.is_playing(), "y quieto en el suelo")
	assert_almost_eq(ap.current_animation_position,
		ap.get_animation("Death").length, 0.05, "en el último fotograma")


func test_se_sanan_con_la_e_y_no_al_pasar_al_lado() -> void:
	var z := _zona()
	var g := _guanaco_herido(z)
	var zona := g.get_node_or_null("ZonaCura") as Area3D
	assert_not_null(zona, "tiene su zona")
	assert_true(zona.has_signal("interacted"), "que se activa con [E]")
	assert_eq(String(zona.get("prompt")), "[E] Sanar al guanaco")


func test_emilia_no_puede_sanarlo() -> void:
	var z := _zona()
	var g := _guanaco_herido(z)
	var emilia := JugadorFalso.new()
	emilia.add_to_group("player")
	emilia.is_archer = false
	add_child_autofree(emilia)

	z.call("_on_heal_entered", emilia, g)
	await wait_frames(2)
	assert_eq(_animador(g).assigned_animation, "Death", "sigue en el suelo")
	assert_eq((z.get("_sanados") as Array).size(), 0, "y sin sanar")


func test_benjamin_lo_levanta() -> void:
	var z := _zona()
	var g := _guanaco_herido(z)
	var benja := JugadorFalso.new()
	benja.add_to_group("player")
	benja.is_archer = true
	add_child_autofree(benja)

	z.call("_on_heal_entered", benja, g)
	await wait_frames(2)
	var ap := _animador(g)
	assert_true(ap.is_playing(), "se está incorporando")
	assert_eq(ap.assigned_animation, "lay_to_idle", "con su gesto de levantarse")
	var t := 0.0
	while t < 6.0 and ap.assigned_animation != "Idle":
		await wait_seconds(0.2)
		t += 0.2
	assert_eq(ap.assigned_animation, "Idle", "y acaba de pie, respirando")


func test_al_calmarse_vuelve_a_reposo_para_hablar() -> void:
	# Hablaba con el último clip de la persecución puesto —el cabezazo,
	# encabritado sobre el jugador—, que es justo la amenaza de la que acababa
	# de salir.
	var z := _zona()
	var y: Node3D = YASTAY.instantiate()
	z.add_child(y)
	z.set("_yastay", y)
	z.set("_yastay_origen", Transform3D(Basis(), Vector3(0, 0, -8)))
	z.call("_yastay_hace", "Head_But", false)
	assert_eq(_animador(y).assigned_animation, "Head_But", "venía del cabezazo")

	z.call("_volver_a_su_sitio")
	await wait_frames(2)
	assert_eq(_animador(y).assigned_animation, "Walk", "vuelve caminando")

	var t := 0.0
	while t < 6.0 and _animador(y).assigned_animation != "Idle":
		await wait_seconds(0.2)
		t += 0.2
	assert_eq(_animador(y).assigned_animation, "Idle", "y habla en reposo")
