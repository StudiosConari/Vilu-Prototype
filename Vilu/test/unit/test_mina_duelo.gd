extends "res://addons/gut/test.gd"

## Cómo está la mina cuando volvés a por el Chupacabras.
##
## Volvés a un sitio por el que ya pasaste, así que tiene que estar como lo
## dejaste al salir corriendo: obeliscos encendidos, el sector de la derecha
## despejado —esos mineros ya los mataste— y el pasillo central con su gente.
## Encontrarla de cero contradice lo que acabás de jugar.

const MINA := preload("res://scenes/regions/Mina.tscn")


func after_all() -> void:
	GameManager.reset_progress()


## Todos los logros menos el del propio Chupacabras: la condición del duelo.
func _con_todo_hecho() -> void:
	GameManager.reset_progress()
	for l in GameManager.LOGROS:
		if l["id"] != "chupacabras":
			GameManager.conceder(str(l["id"]))


func _mina() -> Node3D:
	var m: Node3D = MINA.instantiate()
	add_child_autofree(m)
	# Frames de sobra: `_precalentar_shaders` crea un minero de mentira y lo
	# libera un par de cuadros despues. Sin esperarlo, se cuela en la cuenta.
	await wait_frames(8)
	await wait_physics_frames(4)
	for e in get_errors():
		e.handled = true
	return m


func _cueva(m: Node3D) -> Node:
	for n in m.get_children():
		if n.get_script() != null \
				and String(n.get_script().resource_path).ends_with("MinaCueva.gd"):
			return n
	return m


func _obeliscos(n: Node) -> Array:
	var r: Array = []
	for h in n.get_children():
		if h.get_script() != null \
				and String(h.get_script().resource_path).ends_with("Obelisco.gd"):
			r.append(h)
		r.append_array(_obeliscos(h))
	return r


func _mineros(n: Node) -> Array:
	var r: Array = []
	for h in n.get_children():
		if not h.scene_file_path.ends_with("MineroCorrupto.tscn"):
			continue
		# El del precalentado lleva el proceso apagado. Por capa de colisiÃ³n NO
		# se puede distinguir: los de verdad la tienen a 0 mientras dura su
		# animaciÃ³n de apariciÃ³n.
		if h.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		r.append(h)
	return r


func test_volviendo_al_duelo_la_mina_esta_como_la_dejaste() -> void:
	_con_todo_hecho()
	var m := await _mina()
	var c := _cueva(m)

	assert_true(c._combat_cleared,
		"el sector de la derecha cuenta como despejado: esos mineros ya murieron")
	assert_true(c._combat_started,
		"…y no vuelven a salir al pisar el disparador")

	var obs := _obeliscos(m)
	assert_gt(obs.size(), 0, "la mina tiene obeliscos")
	for o in obs:
		assert_true(o._activado, "el obelisco '%s' ya está encendido" % o.name)

	var mineros := _mineros(c)
	assert_eq(mineros.size(), c.MINEROS_DEL_PASILLO.size(),
		"el pasillo central tiene su gente, como al huir")
	# Por la vida y no por el grupo "enemies": entran en él al terminar su
	# animación de aparición, así que nada más nacer todavía no están.
	for mm in mineros:
		assert_lt(mm.max_health, 999.0,
			"y ahora sí se les puede matar: en la huida eran invulnerables")


func test_la_primera_visita_no_cambia() -> void:
	GameManager.reset_progress()
	var m := await _mina()
	var c := _cueva(m)

	assert_false(c._combat_cleared, "en la primera visita hay que despejar")
	for o in _obeliscos(m):
		assert_false(o._activado, "los obeliscos se encienden a mano")
	assert_eq(_mineros(c).size(), 0,
		"el pasillo central se puebla en la huida, no al entrar")


# ─── Colocar y escalar al Chupacabras desde el editor ────────────────────────
#
# El marcador de aparición era una crucecita: en el editor no se veía qué tan
# grande iba a salir el bicho. Ahora lleva VistaPrevia —lo dibuja— y su tamaño
# es el que manda.

func test_el_jefe_sale_del_tamano_del_marcador() -> void:
	_con_todo_hecho()
	var m := await _mina()
	var marca := m.get_node_or_null("ChupacabrasSpawnPoint") as Node3D
	assert_not_null(marca, "el marcador sigue ahí")
	marca.scale = Vector3.ONE * 1.75

	# Sin la entrada de los ojos: acá se prueba el tamaño del jefe, no su
	# puesta en escena.
	m.set("ojos_en_la_sombra", 0.05)
	m.call("_iniciar_duelo")
	await wait_seconds(0.3)
	await wait_frames(2)
	var jefe: Node3D = m.get("_chupa_jefe")
	assert_not_null(jefe, "salió el jefe")
	assert_almost_eq(jefe.scale.y, 1.75, 0.01, "del tamaño que le pusiste")


func test_el_marcador_dibuja_al_bicho_en_el_editor() -> void:
	var st := MINA.get_state()
	for i in st.get_node_count():
		if String(st.get_node_name(i)) != "ChupacabrasSpawnPoint":
			continue
		var props: Array = []
		for j in st.get_node_property_count(i):
			props.append(String(st.get_node_property_name(i, j)))
		assert_true(props.has("script"), "lleva VistaPrevia")
		assert_true(props.has("modelo"), "y sabe qué modelo dibujar")
		return
	fail_test("no está el marcador del Chupacabras")
