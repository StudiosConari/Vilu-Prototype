extends "res://addons/gut/test.gd"

## Las alas del Alicanto, ya con el modelo y el shader del artista.
##
## Antes eran una malla plana que se encendía y apagaba de golpe. Ahora son la
## malla de verdad, con sus huesos y sus tres animaciones, apareciendo y yéndose
## por disolución.

const PLAYER := preload("res://scenes/actors/Player.tscn")

## El valor que trae el shader por defecto. Corresponde al archivo del artista a
## escala 1:1 y NO sirve para el `.glb` que llega, que viene diez veces mayor.
const POR_DEFECTO_DEL_SHADER := 0.489


func _emilia() -> CharacterBody3D:
	var p: CharacterBody3D = PLAYER.instantiate()
	p.is_archer = false
	add_child_autofree(p)
	await wait_physics_frames(3)
	return p


func _alas(p: Node) -> Node3D:
	return p.get_node_or_null("Visual/Wings/AlasEspirituales")


func test_emilia_lleva_las_alas_y_benjamin_no() -> void:
	var p := await _emilia()
	assert_not_null(_alas(p), "Emilia monta las alas: son su habilidad")

	var b: CharacterBody3D = PLAYER.instantiate()
	b.is_archer = true
	add_child_autofree(b)
	await wait_physics_frames(3)
	assert_null(_alas(b), "el arquero no")


func test_arrancan_invisibles() -> void:
	var p := await _emilia()
	var a := _alas(p)
	assert_not_null(a)
	if a == null:
		return
	assert_false(a.visible,
		"sin volar no se ven, y encima no se dibujan: el shader es transparente")


## El barrido de la disolución divide `VERTEX.x` entre `semi_envergadura`, y
## `VERTEX` va en unidades de la MALLA, no en metros de mundo: no le afecta la
## escala del nodo. Con el 0,489 que trae el shader, la división se satura
## enseguida y el ala entera se disuelve a la vez en vez de barrerse de la base
## a la punta.
func test_la_envergadura_del_shader_sale_de_la_malla() -> void:
	var p := await _emilia()
	var a := _alas(p)
	assert_not_null(a)
	if a == null:
		return
	var m: MeshInstance3D = _buscar(a, "MeshInstance3D")
	assert_not_null(m, "las alas traen su malla")
	if m == null:
		return
	var mat := m.material_override as ShaderMaterial
	assert_not_null(mat, "y llevan el shader del artista, no el material del .glb")
	if mat == null:
		return
	var media: float = float(mat.get_shader_parameter("semi_envergadura"))
	assert_almost_eq(media, m.mesh.get_aabb().size.x * 0.5, 0.01,
		"la media envergadura es la de la malla")
	assert_gt(media, POR_DEFECTO_DEL_SHADER * 2.0,
		"y NO el valor por defecto del shader, que aquí se queda corto")


## Las tres animaciones que pide el guion tienen que venir en el .glb.
func test_estan_los_tres_clips() -> void:
	var p := await _emilia()
	var a := _alas(p)
	assert_not_null(a)
	if a == null:
		return
	var ap: AnimationPlayer = _buscar(a, "AnimationPlayer")
	assert_not_null(ap)
	if ap == null:
		return
	for clip in [a.CLIP_APARECER, a.CLIP_SOSTENER, a.CLIP_PLANEO]:
		assert_true(ap.has_animation(clip), "el modelo trae '%s'" % clip)


## Las alas van EN LA ESPALDA, y ése era el problema del doble salto.
##
## El `.glb` viene en el sistema del EMILIA_COMPLETA del artista: su raíz está a
## la altura de los pies y los hombros de las alas a 7,6 de los 10,345 que mide
## ese cuerpo. Soltando el modelo tal cual, esos 7,6 se convertían en 1,4 m por
## encima del enganche y las alas salían flotando entre 2,4 y 3,4 m del suelo,
## o sea sobre la cabeza de Emilia, que mide 1,9. Ahora se anclan por sus
## propios huesos: el punto medio de los dos hombros va al nodo `Visual/Wings`.
func test_van_en_la_espalda_y_no_sobre_la_cabeza() -> void:
	var p := await _emilia()
	var a := _alas(p)
	assert_not_null(a)
	if a == null:
		return
	var m: MeshInstance3D = _buscar(a, "MeshInstance3D")
	if m == null:
		return
	var caja: AABB = m.global_transform * m.get_aabb()
	var pies: float = p.global_position.y
	assert_between(caja.position.y - pies, 0.5, 1.4,
		"arrancan a la altura de la espalda")
	assert_lt(caja.position.y + caja.size.y - pies, p.ALTO_PERSONAJE + 0.4,
		"y no se van flotando por encima de la cabeza")


## Y hacia ATRÁS. Los modelos de este proyecto miran a +Z y el juego avanza
## hacia -Z: sin darles la vuelta, las alas barrían hacia el pecho.
func test_barren_hacia_atras_y_no_hacia_el_pecho() -> void:
	var p := await _emilia()
	var a := _alas(p)
	assert_not_null(a)
	if a == null:
		return
	var m: MeshInstance3D = _buscar(a, "MeshInstance3D")
	if m == null:
		return
	var vis: Node3D = p.get_node("Visual")
	var atras: Vector3 = vis.global_transform.basis.z    # el modelo mira a -Z
	var caja: AABB = m.global_transform * m.get_aabb()
	var centro: Vector3 = caja.get_center() - p.global_position
	assert_gt(centro.dot(atras), 0.15,
		"el grueso del ala queda por detrás (centro en %s)" % centro)


## Y ACOMPAÑAN al cuerpo.
##
## Colgaban de `Visual/Wings`, que está quieto: en el salto doble Emilia se
## dobla hacia adelante y las alas se quedaban donde habría estado su espalda de
## pie. Ahora cuelgan de su columna.
func test_acompanan_al_cuerpo_cuando_se_dobla() -> void:
	var p := await _emilia()
	for i in 20:
		await get_tree().process_frame
	var a := _alas(p)
	assert_not_null(a)
	if a == null:
		return
	var esq: Skeleton3D = _buscar(p.get_node("Visual/Animador"), "Skeleton3D")
	assert_not_null(esq, "Emilia trae su esqueleto")
	if esq == null:
		return
	var h := esq.find_bone(a.hueso_espalda)
	assert_gt(h, -1, "y su hueso '%s'" % a.hueso_espalda)
	if h < 0:
		return

	var antes: Vector3 = a.global_position
	# Se dobla la columna a mano y se pide el reenganche en el mismo cuadro: si
	# se esperase, la animación devolvería el hueso a su sitio.
	esq.set_bone_pose_rotation(h, esq.get_bone_pose_rotation(h)
		* Quaternion(Vector3.RIGHT, deg_to_rad(50.0)))
	a._seguir_la_espalda()
	assert_gt(antes.distance_to(a.global_position), 0.08,
		"al doblar la columna, las alas se mueven con ella")


## Y no cuelgan a un palmo de la espalda: `Visual/Wings` estaba en z = +0,28 con
## la columna en z = -0,08, o sea 36 cm por detrás. Ese hueco lo pedía la malla
## plana del greybox, no las alas de verdad.
func test_van_pegadas_a_la_espalda() -> void:
	var p := await _emilia()
	for i in 20:
		await get_tree().process_frame
	var a := _alas(p)
	var esq: Skeleton3D = _buscar(p.get_node("Visual/Animador"), "Skeleton3D")
	if a == null or esq == null:
		return
	var h := esq.find_bone(a.hueso_espalda)
	if h < 0:
		return
	var col: Vector3 = (esq.global_transform * esq.get_bone_global_pose(h)).origin
	var sep: float = a.global_position.distance_to(col)
	assert_between(sep, 0.05, 0.20,
		"el enganche va pegado a la columna (%.3f m)" % sep)


## Que quepan en el personaje: son alas, no un ala delta.
func test_el_tamano_es_razonable() -> void:
	var p := await _emilia()
	var a := _alas(p)
	assert_not_null(a)
	if a == null:
		return
	var m: MeshInstance3D = _buscar(a, "MeshInstance3D")
	if m == null:
		return
	var envergadura: float = m.mesh.get_aabb().size.x * (a.get_child(0) as Node3D).scale.x
	assert_between(envergadura, 1.0, 3.0,
		"envergadura en metros, para un personaje de %.2f m" % p.ALTO_PERSONAJE)


func _buscar(n: Node, clase: String) -> Node:
	if n.is_class(clase):
		return n
	for h in n.get_children():
		var x := _buscar(h, clase)
		if x != null:
			return x
	return null


func test_la_estatura_no_toca_el_cuerpo_de_colision() -> void:
	# Emilia y Benjamín se agrandaron de 1,9 a 2,2 m. Es sólo lo que se ve: la
	# cápsula sigue midiendo 1,6, y de ella dependen los saltos medidos del
	# Isluga y la viga baja de la mina. Si algún día alguien la escala con el
	# modelo, esto avisa.
	var esc := load("res://scenes/actors/Player.tscn") as PackedScene
	var st := esc.get_state()
	var alto := -1.0
	for i in st.get_node_count():
		if String(st.get_node_name(i)) != "Collision":
			continue
		for j in st.get_node_property_count(i):
			if String(st.get_node_property_name(i, j)) == "shape":
				var f := st.get_node_property_value(i, j) as CapsuleShape3D
				if f != null:
					alto = f.height
	assert_almost_eq(alto, 1.6, 0.01, "la cápsula del jugador sigue siendo la de siempre")
