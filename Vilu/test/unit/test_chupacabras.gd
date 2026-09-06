extends "res://addons/gut/test.gd"

## La persecución de la Mina: el Chupacabras tiene que ALCANZARTE, estés donde
## estés dentro del túnel.
##
## Regresión de un fallo real: antes corría con velocidad fija (x=0, z=8), o sea
## en línea recta por el eje del túnel sin mirar dónde estaba el jugador. Si te
## apartabas del centro seguía de largo y terminaba incrustado contra el muro
## del fondo de la cámara de entrada, en z=12.38, saltando para siempre.
##
## El caso de prueba es el que lo destapaba: jugador fuera del eje, del lado en
## el que los bloques de z=-15.5 estrechan el paso a x=-3..3.

const MINA := preload("res://scenes/regions/Mina.tscn")
## Cuadros de física de margen. Cruzar la mina entera le lleva unos 320.
const CUADROS := 600
## A esta distancia ya se considera alcanzado (el golpe salta a 2.0 m).
const CERCA := 3.0


func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_alcanza_al_jugador_fuera_del_eje() -> void:
	# El tablonado de z=-37 se rompe ANTES de armar la mina.
	#
	# No es un detalle del montaje: ese tablonado tapa el túnel de pared a pared
	# y es justo lo que hay que romper para llevarse el primer fragmento del
	# talismán. Romperlo es lo que dispara la huida, así que cuando el
	# Chupacabras sale de su nido el paso YA está abierto. Empezando la
	# persecución con los tablones puestos, la bestia nace emparedada en el
	# fondo: no hay ruta que encontrar y el fallo no es suyo.
	#
	# El prop arranca roto solo si la habilidad ya está concedida al construirse
	# la escena, de ahí que esto vaya antes del instantiate.
	GameManager.unlock("talisman_frag_1")

	var m := MINA.instantiate()
	add_child_autofree(m)
	await wait_physics_frames(4)

	var cueva: Node = m
	for n in m.get_children():
		if n.get_script() != null \
				and String(n.get_script().resource_path).ends_with("MinaCueva.gd"):
			cueva = n

	# Jugador quieto en la cámara de entrada, fuera del eje del túnel.
	var jugador := Node3D.new()
	jugador.add_to_group("player")
	add_child_autofree(jugador)
	jugador.global_position = Vector3(5.0, 0.0, 3.0)

	# Sin la entrada de los ojos: acá se prueba la persecución, no la puesta en
	# escena, y esperar sus dos segundos por test alargaría la batería entera.
	cueva.set("ojos_en_la_sombra", 0.05)
	cueva._combat_cleared = true
	cueva._start_chase()
	await wait_seconds(0.3)
	await wait_physics_frames(2)

	var c = cueva._chupacabras
	assert_not_null(c, "la persecución crea al Chupacabras")

	var mejor := INF
	var alcanzado := false
	for i in CUADROS:
		await wait_physics_frames(1)
		if not is_instance_valid(c):
			break
		mejor = minf(mejor, c.global_position.distance_to(jugador.global_position))
		if mejor < CERCA:
			alcanzado = true
			break

	cueva._chase_active = false   # que no siga corriendo tras el test
	assert_true(alcanzado,
		"el Chupacabras debe alcanzar al jugador; se quedó a %.1f m" % mejor)


# ─── Que se mueva como un bicho, no como una estatua ─────────────────────────
#
# El modelo trae siete clips —Idle, Walk, Run, Sneak, Howl, Bite y Death— y no
# usaba ninguno: perseguía deslizándose con las patas clavadas.

func _animador(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for h in n.get_children():
		var x := _animador(h)
		if x != null:
			return x
	return null


func _cueva_con_persecucion() -> Node:
	GameManager.unlock("talisman_frag_1")
	var m := MINA.instantiate()
	add_child_autofree(m)
	await wait_physics_frames(4)
	var cueva: Node = m
	for n in m.get_children():
		if n.get_script() != null \
				and String(n.get_script().resource_path).ends_with("MinaCueva.gd"):
			cueva = n
	cueva.set("ojos_en_la_sombra", 0.05)
	cueva._combat_cleared = true
	cueva._start_chase()
	await wait_seconds(0.3)
	await wait_physics_frames(2)
	return cueva


func test_persigue_corriendo() -> void:
	var cueva := await _cueva_con_persecucion()
	var ap := _animador(cueva._chupacabras)
	assert_not_null(ap, "el modelo trae su reproductor")
	assert_eq(ap.assigned_animation, "Run", "corre, no se desliza")
	assert_true(ap.is_playing())


func test_al_morder_muerde() -> void:
	var cueva := await _cueva_con_persecucion()
	var jugador := Node3D.new()
	jugador.add_to_group("player")
	add_child_autofree(jugador)
	jugador.global_position = cueva._chupacabras.global_position

	cueva._morder()
	await wait_frames(1)
	assert_eq(_animador(cueva._chupacabras).assigned_animation, "Bite",
		"la dentellada se ve")


func test_sus_clips_caminan_en_el_sitio() -> void:
	# Si alguno arrastrara el esqueleto, el bicho se despegaría de su cuerpo de
	# colisión: quien lo mueve es el código.
	var n: Node3D = (load("res://models/personaje/chupacabras.glb") as PackedScene).instantiate()
	add_child_autofree(n)
	await wait_frames(2)
	var ap := _animador(n)
	var esq: Skeleton3D = null
	var pend: Array[Node] = [n]
	while not pend.is_empty():
		var x: Node = pend.pop_back()
		if x is Skeleton3D:
			esq = x
			break
		pend.append_array(x.get_children())
	assert_not_null(esq)
	for clip in ["Run", "Bite", "Idle"]:
		var a := ap.get_animation(clip)
		ap.play(clip)
		ap.seek(0.0, true)
		var d0: Vector3 = esq.get_bone_global_pose(0).origin
		ap.seek(a.length, true)
		var d: Vector3 = esq.get_bone_global_pose(0).origin - d0
		d.y = 0.0
		assert_lt(d.length(), 0.1, "'%s' no arrastra el cuerpo" % clip)


# ─── Los ojos en la oscuridad ────────────────────────────────────────────────
#
# Aparecía de golpe en su nido y salía corriendo: el bicho más importante de la
# mina entraba en escena sin entrar en escena.

## Un doble del nodo del juego que sólo anota adónde le mandan la cámara.
class JuegoFalso extends Node3D:
	var mirado: Node3D = null
	var soltadas := 0

	func focus_camera_on(n: Node3D, _dur := 0.0, _dist := 0.0, _alt := 1.5) -> void:
		mirado = n

	func clear_camera_focus() -> void:
		mirado = null
		soltadas += 1


func test_antes_de_salir_se_le_ven_los_ojos() -> void:
	GameManager.unlock("talisman_frag_1")
	var m := MINA.instantiate()
	add_child_autofree(m)
	await wait_physics_frames(4)
	var cueva: Node = m
	for n in m.get_children():
		if n.get_script() != null \
				and String(n.get_script().resource_path).ends_with("MinaCueva.gd"):
			cueva = n
	var j := JuegoFalso.new()
	j.add_to_group("game")
	add_child_autofree(j)

	cueva.set("ojos_en_la_sombra", 0.4)
	cueva._combat_cleared = true
	cueva._start_chase()
	await wait_frames(3)

	var ojos: Node = cueva.get_node_or_null("OjosEnLaOscuridad")
	assert_not_null(ojos, "se encienden los ojos en el nido")
	assert_eq(j.mirado, ojos, "y la cámara se va a ellos")
	assert_null(cueva.get("_chupacabras"), "todavía no ha salido")
	# En el sitio por el que sale, no en cualquier lado.
	assert_almost_eq(ojos.global_position,
		cueva.call("_sitio_del_nido") + Vector3(0, cueva.get("alto_de_los_ojos"), 0),
		Vector3.ONE * 0.05, "en el nido")

	await wait_seconds(1.0)
	assert_false(is_instance_valid(ojos), "se apagan")
	assert_gt(j.soltadas, 0, "y la cámara vuelve al jugador")
	assert_not_null(cueva.get("_chupacabras"), "recién entonces sale")
