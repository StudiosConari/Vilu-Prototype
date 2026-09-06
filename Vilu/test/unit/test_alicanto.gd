extends GutTest

## La quebrada del Alicanto: la cámara y la trampa del oro.

const RESCATE := preload("res://scenes/actors/AlicantoRescate.gd")
const TRAMPA := preload("res://scenes/actors/TrampaDelOro.gd")


## Un doble del nodo del juego que sólo anota adónde le mandan la cámara.
class JuegoFalso extends Node3D:
	var mirado: Node3D = null
	var distancia := 0.0
	var alto := 0.0
	var soltadas := 0

	func focus_camera_on(n: Node3D, _dur := 0.0, dist := 0.0, alt := 1.5) -> void:
		mirado = n
		distancia = dist
		alto = alt

	func clear_camera_focus() -> void:
		mirado = null
		soltadas += 1


func _juego() -> JuegoFalso:
	var j := JuegoFalso.new()
	j.add_to_group("game")
	add_child_autofree(j)
	return j


## La zona, sin construir la quebrada entera: sólo interesa la lógica.
func _zona() -> Node3D:
	var z := Node3D.new()
	z.set_script(RESCATE)
	z.geometria_fijada = true
	add_child_autofree(z)
	return z


func test_la_camara_se_va_al_alicanto() -> void:
	var j := _juego()
	var z := _zona()
	var ave := Node3D.new()
	ave.name = "alicanto"
	z.add_child(ave)
	z.set("_alicanto", ave)

	z.call("_mirar_al_alicanto")
	assert_eq(j.mirado, ave, "la cámara mira al ave")
	assert_eq(j.distancia, RESCATE.DISTANCIA_CAMARA)
	assert_eq(j.alto, RESCATE.ALTO_CAMARA)


func test_sin_ave_la_camara_vuelve_a_emilia() -> void:
	var j := _juego()
	var z := _zona()
	z.set("_alicanto", null)
	z.call("_mirar_al_alicanto")
	assert_eq(j.soltadas, 1, "no se queda mirando a un nodo que no existe")


func test_al_bajar_el_ave_la_camara_la_sigue() -> void:
	var j := _juego()
	var z := _zona()
	# Un hijo llamado "alicanto" evita instanciar el modelo: la zona lo adopta.
	var ave := Node3D.new()
	ave.name = "alicanto"
	ave.visible = false
	z.add_child(ave)

	z.call("_summon_alicanto")
	assert_eq(j.mirado, ave, "al aparecer, se lo enseña al jugador")
	assert_true(ave.visible, "y deja de estar escondido")


# ─── La trampa: el oro se va abajo con la losa ────────────────────────────────

func _losa(nombre: String, en: Vector3, tam := Vector3(8, 1, 8)) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	n.position = en
	var mi := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	mi.mesh = caja
	n.add_child(mi)
	return n


func _cristal(nombre: String, en: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	n.position = en
	return n


func test_el_oro_de_encima_cae_con_el_camino() -> void:
	var zona := Node3D.new()
	add_child_autofree(zona)
	var puente := _losa("puente_derrumbable_1", Vector3(0, 0, 0))
	var camino := _losa("camino_derrumbable_1", Vector3(20, 0, 0))
	zona.add_child(puente)
	zona.add_child(camino)
	var encima := _cristal("cristal_de_oro_1", Vector3(21, 1, 1))
	var lejos := _cristal("cristal_de_oro_2", Vector3(60, 1, 0))
	zona.add_child(encima)
	zona.add_child(lejos)

	var trampa := Node3D.new()
	trampa.set_script(TRAMPA)
	trampa.puente = puente
	trampa.camino = camino
	zona.add_child(trampa)

	assert_eq(encima.get_parent(), camino, "el oro de encima cuelga del camino")
	assert_eq(lejos.get_parent(), zona, "el de la quebrada se queda donde estaba")


func test_el_oro_adoptado_se_mueve_con_la_losa() -> void:
	var zona := Node3D.new()
	add_child_autofree(zona)
	var puente := _losa("puente_derrumbable_1", Vector3(0, 0, 0))
	var camino := _losa("camino_derrumbable_1", Vector3(20, 0, 0))
	zona.add_child(puente)
	zona.add_child(camino)
	var oro := _cristal("cristal_de_oro_1", Vector3(20, 1, 0))
	zona.add_child(oro)

	var trampa := Node3D.new()
	trampa.set_script(TRAMPA)
	trampa.puente = puente
	trampa.camino = camino
	zona.add_child(trampa)

	var antes := oro.global_position.y
	camino.global_position -= Vector3(0.0, TRAMPA.CAIDA, 0.0)
	assert_almost_eq(oro.global_position.y, antes - TRAMPA.CAIDA, 0.01,
		"el oro baja los mismos metros que la losa")


# ─── Colocar el ave desde el editor ──────────────────────────────────────────
#
# El ave se dibujaba en unas coordenadas escritas en el código: en el editor no
# se veía nada y colocarla era adivinar. Con un marcador puesto en la escena
# —que lleva VistaPrevia y la dibuja— se la mueve y se la agranda con el gizmo.

func test_el_ave_va_donde_diga_el_marcador() -> void:
	var z := _zona()
	var marca := Marker3D.new()
	marca.name = "AveSpawn"
	z.add_child(marca)
	marca.position = Vector3(3.0, 9.0, -12.0)
	marca.scale = Vector3.ONE * 2.5

	z.call("_build_alicanto")
	var ave: Node3D = z.get("_alicanto")
	assert_not_null(ave, "hay ave")
	assert_almost_eq(ave.position, Vector3(3.0, 9.0, -12.0), Vector3.ONE * 0.01,
		"en el sitio del marcador")
	assert_almost_eq(ave.scale.y, 2.5, 0.01, "y del tamaño del marcador")


func test_sin_marcador_sigue_saliendo_donde_salía() -> void:
	var z := _zona()
	z.call("_build_alicanto")
	var ave: Node3D = z.get("_alicanto")
	assert_not_null(ave, "hay ave igual")
	assert_almost_eq(ave.position, Vector3(11.0, 6.0, -34.0), Vector3.ONE * 0.01,
		"el sitio de siempre")


func test_esta_puesto_el_marcador_en_atacama() -> void:
	var st := (load("res://scenes/core/WorldAtacama.tscn") as PackedScene).get_state()
	var hay := false
	for i in st.get_node_count():
		if String(st.get_node_name(i)) == "AveSpawn":
			hay = true
	assert_true(hay, "el marcador del ave, para verla en el editor")


# ─── La persona herida ───────────────────────────────────────────────────────
#
# Era una cápsula gris del greybox con un cartel encima, y el personaje puesto
# al lado se quedaba de pie. Ahora la herida es el personaje que asignás en el
# inspector, tendida con la misma caída que los cazadores del Yastay.

const CAZADOR := preload("res://models/personaje/cazador_joven.glb")


func _con_herida() -> Array:
	var z := _zona()
	var c: Node3D = CAZADOR.instantiate()
	c.name = "cazador_joven2"
	z.add_child(c)
	c.position = Vector3(11.0, 0.0, -22.0)
	z.set("persona_herida", NodePath("cazador_joven2"))
	z.call("_reponer_herida")
	return [z, c]


func test_la_herida_es_la_que_asignaste() -> void:
	var todo := _con_herida()
	assert_eq(todo[0].get("_hurt"), todo[1], "la herida es el personaje puesto")
	assert_true(bool(todo[0].get("_hurt_es_modelo")), "y se la trata como modelo")


func test_esta_tendida_en_el_suelo() -> void:
	var todo := _con_herida()
	var c: Node3D = todo[1]
	var animado := c.get_node_or_null("Animado")
	assert_not_null(animado, "se le puso el modelo con huesos")
	var ap: AnimationPlayer = null
	var pend: Array[Node] = [animado]
	while not pend.is_empty():
		var x: Node = pend.pop_back()
		if x is AnimationPlayer:
			ap = x
			break
		pend.append_array(x.get_children())
	assert_not_null(ap, "y trae su reproductor")
	assert_true(ap.assigned_animation.begins_with("derrotad"),
		"tendida, no de pie: '%s'" % ap.assigned_animation)
	assert_almost_eq(c.rotation.z, 0.0, 0.01,
		"tumbada por la animación, no girando el nodo")


func test_le_cuelga_su_zona_de_ayuda() -> void:
	var todo := _con_herida()
	var c: Node3D = todo[1]
	assert_true(c.has_node("ZonaAyuda"), "el [E] Ayudar va con ella")
	assert_not_null(c.get_node_or_null("Label3D"), "y su cartel")


func test_ya_no_hay_pildora_en_la_escena() -> void:
	# La cápsula gris estaba horneada en el mundo: se veía en el editor y en el
	# juego hasta que el código la borraba.
	var st := (load("res://scenes/core/WorldAtacama.tscn") as PackedScene).get_state()
	for i in st.get_node_count():
		for j in st.get_node_property_count(i):
			if String(st.get_node_property_name(i, j)) != "text":
				continue
			assert_ne(String(st.get_node_property_value(i, j)), "¡Alguien herido!",
				"no queda el cartel de la cápsula")


func test_al_curarla_se_incorpora() -> void:
	# El "se incorpora" de antes giraba la cápsula y la bajaba a y=0. A un modelo
	# eso lo hunde en el suelo: se incorpora cambiando de clip.
	const POSE := preload("res://scenes/core/PoseAnimada.gd")
	var todo := _con_herida()
	assert_true(POSE.reproducir(todo[1], "sentado", true),
		"tiene con qué incorporarse")


func test_al_curarla_se_queda_de_pie_no_sentada_en_el_aire() -> void:
	# `sentado_victoria` está hecho para una silla, y en la quebrada no hay
	# ninguna: la superviviente quedaba sentada en el aire. Su modelo del
	# pipeline es un cuerpo rígido y su pose de fábrica ya es estar de pie, así
	# que "levantarse" es quitarle el animado.
	const POSE := preload("res://scenes/core/PoseAnimada.gd")
	var todo := _con_herida()
	var c: Node3D = todo[1]
	assert_not_null(c.get_node_or_null("Animado"), "tendida, con su esqueleto")

	assert_true(POSE.quitar(c), "se le quita el animado")
	assert_null(c.get_node_or_null("Animado"), "y ya no está")
	var visibles := 0
	for m in _mallas(c):
		if m.visible:
			visibles += 1
	assert_gt(visibles, 0, "vuelve a verse su propio modelo, de pie")


func _mallas(n: Node) -> Array:
	var r: Array = []
	if n is MeshInstance3D:
		r.append(n)
	for h in n.get_children():
		r.append_array(_mallas(h))
	return r
