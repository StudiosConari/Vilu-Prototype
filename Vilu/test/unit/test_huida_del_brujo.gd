extends GutTest

## La huida del brujo: cae derrotado y se va herido por el puente, siguiendo el
## camino de marcadores puesto en la escena.

const ENCUENTRO := preload("res://scenes/actors/YastayEncounter.gd")
const BRUJO := preload("res://models/personaje/brujo.glb")


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


# ─── El modelo ───────────────────────────────────────────────────────────────

func test_el_brujo_trae_sus_tres_momentos() -> void:
	var n: Node = BRUJO.instantiate()
	add_child_autofree(n)
	var ap := _animador(n)
	assert_not_null(ap, "ya no es una estatua")
	if ap == null:
		return
	for clip in ["apuntando", "derrotado", "correr_herido"]:
		assert_true(ap.has_animation(clip), "trae '%s'" % clip)


func test_esta_de_pie_y_conserva_su_estatura() -> void:
	# El riggeado de AccuRig lo devolvió TUMBADO —su altura corría por Z— y
	# midiendo 1,93 m. En la quebrada eso es un gigante acostado.
	var n: Node3D = BRUJO.instantiate()
	add_child_autofree(n)
	await wait_frames(3)
	assert_almost_eq(_estatura(n), 1.80, 0.06, "lo que medía de estatua")


## Se mide por el ESQUELETO: la caja que calcula Godot para una malla con huesos
## se infla con las animaciones —la del brujo daba 3,95 m— y no dice cuánto
## ocupa en pantalla.
func _estatura(n: Node) -> float:
	var e := _esqueleto(n)
	if e == null:
		return 0.0
	var top := -1e9
	var bajo := 1e9
	for i in e.get_bone_count():
		var y: float = e.get_bone_global_rest(i).origin.y
		top = maxf(top, y)
		bajo = minf(bajo, y)
	return (top - bajo) * e.global_transform.basis.get_scale().y


func _esqueleto(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for h in n.get_children():
		var x := _esqueleto(h)
		if x != null:
			return x
	return null


# ─── Hacia dónde huye ────────────────────────────────────────────────────────

func test_huye_hacia_la_entrada_de_la_quebrada() -> void:
	var z := _zona()
	var entrada := Marker3D.new()
	entrada.name = "PlayerSpawn"
	z.add_child(entrada)
	entrada.position = Vector3(0, 0, 11.4)      # como en la escena de verdad
	var b := Node3D.new()
	z.add_child(b)
	b.position = Vector3(7.6, 1.0, -25.5)       # el sitio del brujo
	z.set("_brujo", b)

	var rumbo: Vector3 = z.call("_rumbo_de_huida")
	assert_almost_eq(rumbo.length(), 1.0, 0.01, "es una dirección, no un vector cualquiera")
	assert_almost_eq(rumbo.y, 0.0, 0.001, "sin subir ni bajar")
	assert_gt(rumbo.z, 0.8, "sale hacia la entrada, que está en +Z")


func test_un_marcador_manda_sobre_la_entrada() -> void:
	var z := _zona()
	var entrada := Marker3D.new()
	entrada.name = "PlayerSpawn"
	z.add_child(entrada)
	entrada.position = Vector3(0, 0, 11.4)
	var meta := Marker3D.new()
	meta.name = "PorAqui"
	z.add_child(meta)
	meta.position = Vector3(-40, 0, -25.5)      # al oeste, no a la entrada
	var b := Node3D.new()
	z.add_child(b)
	b.position = Vector3(7.6, 1.0, -25.5)
	z.set("_brujo", b)
	z.set("salida_del_brujo", NodePath("PorAqui"))

	var rumbo: Vector3 = z.call("_rumbo_de_huida")
	assert_lt(rumbo.x, -0.9, "si pusiste marcador, va hacia el marcador")


# ─── Cómo queda mirando ──────────────────────────────────────────────────────

func test_corre_de_frente_no_de_espaldas() -> void:
	var z := _zona()
	var b := Node3D.new()
	z.add_child(b)
	# El frente del rig es +Z: medido del talón a los dedos sobre el esqueleto.
	z.call("_orientar", b, Vector3(0, 0, 1))
	var frente: Vector3 = b.global_transform.basis.z
	assert_gt(frente.dot(Vector3(0, 0, 1)), 0.9,
		"su frente apunta adonde corre")


func test_el_giro_es_ajustable() -> void:
	var z := _zona()
	assert_almost_eq(float(z.get("brujo_giro")), 0.0, 0.01,
		"sin giro extra: el frente del rig ya es +Z, medido del talón a los dedos")


func test_lo_que_dura_cada_clip() -> void:
	var z := _zona()
	var b: Node3D = BRUJO.instantiate()
	z.add_child(b)
	z.set("_brujo", b)
	var t: float = z.call("_clip", b, "derrotado", false)
	assert_gt(t, 0.5, "la caída dura algo")
	var ap := _animador(b)
	assert_eq(ap.assigned_animation, "derrotado")
	assert_eq(ap.get_animation("derrotado").loop_mode, Animation.LOOP_NONE,
		"caerse se hace una vez")
	z.call("_clip", b, "correr_herido", true)
	assert_eq(ap.get_animation("correr_herido").loop_mode, Animation.LOOP_LINEAR,
		"correr se repite mientras huye")


func test_un_clip_que_no_existe_no_rompe_nada() -> void:
	var z := _zona()
	var b: Node3D = BRUJO.instantiate()
	z.add_child(b)
	assert_eq(float(z.call("_clip", b, "bailar_cueca", false)), 0.0)


# ─── Se va por el puente, no por encima de las rocas ─────────────────────────
#
# Iba en línea recta hacia la salida: cruzaba la quebrada por encima del vacío y
# de las piedras, mirando hacia otro lado y a 6,5 m/s con la animación de
# alguien herido. Ahora sigue un camino puesto en la escena, tramo por tramo.

func test_el_camino_son_los_marcadores_en_orden() -> void:
	var z := _zona()
	var camino := Node3D.new()
	camino.name = "PorAlla"
	z.add_child(camino)
	for sitio in [Vector3(3, 0, -19), Vector3(0, 0, -12), Vector3(0, 0, 4)]:
		var paso := Marker3D.new()
		camino.add_child(paso)
		paso.global_position = sitio
	z.set("salida_del_brujo", NodePath("PorAlla"))

	var pasos: Array = z.call("_camino_del_brujo")
	assert_eq(pasos.size(), 3, "tres tramos, no uno")
	assert_almost_eq(pasos[0], Vector3(3, 0, -19), Vector3.ONE * 0.01)
	assert_almost_eq(pasos[2], Vector3(0, 0, 4), Vector3.ONE * 0.01)


func test_sin_camino_sigue_tirando_hacia_la_salida() -> void:
	var z := _zona()
	assert_true((z.call("_camino_del_brujo") as Array).is_empty(),
		"sin marcadores no hay camino, y manda el rumbo de siempre")


func test_mira_hacia_donde_va_en_cada_tramo() -> void:
	var z := _zona()
	var b: Node3D = BRUJO.instantiate()
	z.add_child(b)
	z.set("_brujo", b)
	b.global_position = Vector3.ZERO

	# Hacia +X: el frente de este modelo es +Z, así que gira 90°.
	# Tramos cortos y esperados: sin esperar al primero, el segundo arranca a
	# medio camino y su rumbo ya no es el que se está midiendo.
	await z.call("_brujo_va_hasta", Vector3(1.5, 0, 0))
	assert_gt(b.global_transform.basis.z.x, 0.9, "mirando adonde camina")

	# Y hacia -Z: gira el tramo, gira él.
	await z.call("_brujo_va_hasta", Vector3(1.5, 0, -1.5))
	assert_lt(b.global_transform.basis.z.z, -0.9, "y al girar el tramo, gira él")


func test_va_despacio_porque_va_herido() -> void:
	var z := _zona()
	assert_lt(float(z.get("brujo_velocidad")), 3.0,
		"con la animación de herido, 6,5 m/s eran patines")


func test_el_camino_esta_puesto_en_la_quebrada() -> void:
	var st := (load("res://scenes/core/WorldAtacama.tscn") as PackedScene).get_state()
	var meta: Variant = null
	for i in st.get_node_count():
		if String(st.get_node_name(i)) != "Yastay":
			continue
		for j in st.get_node_property_count(i):
			if String(st.get_node_property_name(i, j)) == "salida_del_brujo":
				meta = st.get_node_property_value(i, j)
	assert_not_null(meta, "la quebrada sabe por dónde se va el brujo")
	var pasos := 0
	for i in st.get_node_count():
		if String(st.get_node_path(i, true)).ends_with(String(meta).get_file()):
			pasos += 1
	assert_gt(pasos, 2, "y el camino tiene tramos, no un punto suelto")


func test_ya_no_apunta_antes_de_caer() -> void:
	# Eran tres animaciones seguidas para decir una sola cosa —que perdió y se
	# va— y se hacía largo: el jugador está mirando al Yastay, no a él.
	var fuente := FileAccess.get_file_as_string(
		"res://scenes/actors/YastayEncounter.gd")
	assert_false('_clip(_brujo, "apuntando"' in fuente,
		"la escena del brujo ya no reproduce 'apuntando'")


func test_mira_bien_aunque_la_quebrada_este_girada() -> void:
	# EL FALLO DE VERDAD: el rumbo se calcula en coordenadas del mundo y
	# `rotation.y` se mide respecto del padre. La quebrada está girada 90° en la
	# escena, así que el brujo caminaba de lado, mirando a noventa grados de por
	# donde iba. Con la zona sin girar —como en los otros tests— no se veía.
	var z := _zona()
	z.rotation.y = PI * 0.5
	var b: Node3D = BRUJO.instantiate()
	z.add_child(b)
	z.set("_brujo", b)

	# Hacia +X del MUNDO.
	z.call("_orientar", b, Vector3(1, 0, 0))
	assert_gt(b.global_transform.basis.z.x, 0.95,
		"su frente apunta a donde va, en el mundo, no en la zona")

	# Y hacia -Z del mundo.
	z.call("_orientar", b, Vector3(0, 0, -1))
	assert_lt(b.global_transform.basis.z.z, -0.95, "y también aquí")
