extends GutTest

## El ocultista del pasillo de la mina.
##
## Está desde que entrás. A mitad del pasillo se da vuelta, camina hasta el
## tablón que esconde el talismán y se queda señalándolo. Sigue ahí con el
## primer obelisco encendido; al segundo, ya no.

const MINA := preload("res://scenes/actors/MinaCueva.gd")
const OCULTISTA := preload("res://models/personaje/ocultista_hombre.glb")
const OBELISCO := preload("res://scenes/actors/Obelisco.gd")


## Un tablonado de mentira: lo que lo identifica es lo que CONCEDE.
class TablonFalso extends Node3D:
	var otorga := "talisman_frag_1"


func _mina() -> Node3D:
	var m := Node3D.new()
	m.set_script(MINA)
	add_child_autofree(m)
	return m


func _animador(n: Node) -> AnimationPlayer:
	for h in n.get_children():
		if h is AnimationPlayer:
			return h
		var x := _animador(h)
		if x != null:
			return x
	return null


## La mina de prueba: el ocultista en el pasillo y el tablón al fondo.
func _montar(m: Node3D) -> Node3D:
	var o: Node3D = OCULTISTA.instantiate()
	o.name = "ocultista_hombre2"
	m.add_child(o)
	o.global_position = Vector3(0, 0, -25)
	var t := TablonFalso.new()
	t.name = "tablones_de_madera4"
	m.add_child(t)
	t.global_position = Vector3(0, 0, -37)
	return o


# ─── El modelo ───────────────────────────────────────────────────────────────

func test_trae_sus_tres_clips() -> void:
	var n: Node = OCULTISTA.instantiate()
	add_child_autofree(n)
	var ap := _animador(n)
	for c in ["vuelta_y_caminar", "caminar", "marcando"]:
		assert_true(ap.has_animation(c), "trae '%s'" % c)


# ─── A quién encuentra ───────────────────────────────────────────────────────

func test_encuentra_el_tablon_por_lo_que_concede() -> void:
	# Se llama "tablones_de_madera4" y hay cinco más iguales en la mina: por
	# nombre elegiría cualquiera.
	var m := _mina()
	_montar(m)
	var t: Node3D = m.call("_tablon_del_talisman")
	assert_not_null(t)
	assert_almost_eq(t.global_position.z, -37.0, 0.01)


func test_se_planta_a_un_paso_del_tablon() -> void:
	var m := _mina()
	var o := _montar(m)
	m.set("_ocultista", o)
	var sitio: Vector3 = m.call("_sitio_junto_al_tablon")
	assert_almost_eq(sitio.z, -35.4, 0.2, "a 1,6 m del tablón, no encima")
	assert_almost_eq(sitio.y, o.global_position.y, 0.01, "sin despegarse del suelo")


func test_mira_al_tablon_de_frente() -> void:
	var m := _mina()
	var o := _montar(m)
	m.set("_ocultista", o)
	m.call("_mirar_al_tablon")
	# El frente de estos modelos es +Z, y el tablón está en -Z desde él.
	assert_lt(o.global_transform.basis.z.z, -0.9, "lo señala de cara")


# ─── Según cuántos obeliscos lleves ──────────────────────────────────────────

func test_con_ninguno_espera_de_espaldas() -> void:
	var m := _mina()
	var o := _montar(m)
	m.call("_montar_al_ocultista")
	assert_true(is_instance_valid(o), "sigue ahí")
	assert_false(bool(m.get("_ocultista_en_marcha")), "todavía no arrancó")
	var ap := _animador(o)
	assert_eq(ap.assigned_animation, "vuelta_y_caminar", "de espaldas")
	assert_false(ap.is_playing(), "y quieto, no dándose vuelta solo")
	assert_almost_eq(ap.current_animation_position, 0.0, 0.01,
		"en el primer fotograma, que es el de espaldas")


# ─── Cuándo arranca ──────────────────────────────────────────────────────────

## Un jugador de mentira: lo único que mira la vigilancia es el grupo y dónde
## está.
func _jugador(m: Node3D, donde: Vector3) -> Node3D:
	var p := Node3D.new()
	p.add_to_group("player")
	m.add_child(p)
	p.global_position = donde
	return p


func test_arranca_al_acercarte() -> void:
	var m := _mina()
	var o := _montar(m)
	m.call("_montar_al_ocultista")

	# Lejos: ni se inmuta.
	_jugador(m, Vector3(0, 0, 0))
	await wait_frames(3)
	assert_false(bool(m.get("_ocultista_en_marcha")), "a 25 m no")

	# A tiro: se da vuelta.
	m.get_child(m.get_child_count() - 1).global_position = Vector3(0, 0, -16)
	await wait_frames(3)
	assert_true(bool(m.get("_ocultista_en_marcha")), "a 9 m sí")
	assert_eq(_animador(o).assigned_animation, "vuelta_y_caminar")
	assert_true(_animador(o).is_playing(), "y ahora sí se está dando vuelta")


func test_arranca_vengas_por_donde_vengas() -> void:
	# La caja de disparo de antes estaba puesta ocho metros hacia +Z: llegando
	# por el otro lado nunca saltaba y se quedaba de espaldas para siempre.
	var m := _mina()
	_montar(m)
	m.call("_montar_al_ocultista")
	_jugador(m, Vector3(0, 0, -33))
	await wait_frames(3)
	assert_true(bool(m.get("_ocultista_en_marcha")), "también desde el fondo")


func test_con_uno_encendido_ya_esta_en_el_tablon() -> void:
	var m := _mina()
	var o := _montar(m)
	var ob := Node3D.new()
	ob.set_script(OBELISCO)
	m.add_child(ob)
	ob.set("_activado", true)

	m.call("_montar_al_ocultista")
	assert_true(is_instance_valid(o), "volviste y sigue ahí")
	assert_almost_eq(o.global_position.z, -35.4, 0.2,
		"pero ya hizo el camino: está en el tablón")
	assert_eq(_animador(o).assigned_animation, "marcando")


func test_con_dos_encendidos_ya_no_esta() -> void:
	var m := _mina()
	var o := _montar(m)
	for i in 2:
		var ob := Node3D.new()
		ob.set_script(OBELISCO)
		m.add_child(ob)
		ob.set("_activado", true)

	m.call("_montar_al_ocultista")
	await wait_frames(2)
	assert_false(is_instance_valid(o), "se fue")


func test_al_encender_el_segundo_desaparece() -> void:
	var m := _mina()
	var o := _montar(m)
	var obs := []
	for i in 2:
		var ob := Node3D.new()
		ob.set_script(OBELISCO)
		m.add_child(ob)
		obs.append(ob)
	m.call("_montar_al_ocultista")

	# El primero no lo espanta.
	obs[0].set("_activado", true)
	m.call("_al_encender_obelisco")
	await wait_frames(2)
	assert_true(is_instance_valid(o), "con uno todavía está")

	# El segundo sí.
	obs[1].set("_activado", true)
	m.call("_al_encender_obelisco")
	await wait_frames(2)
	assert_false(is_instance_valid(o), "con dos ya no")


func test_sin_ocultista_en_la_escena_no_pasa_nada() -> void:
	var m := _mina()
	m.call("_montar_al_ocultista")
	assert_null(m.get("_ocultista"), "no se inventa uno")
