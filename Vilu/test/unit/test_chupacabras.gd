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

	cueva._combat_cleared = true
	cueva._start_chase()
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
