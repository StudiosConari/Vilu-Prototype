extends "res://addons/gut/test.gd"

## Viajar de un interior a otro con el mapa del Guardián.
##
## Dos fallos reales, de la misma raíz — `go_to` mandaba a `enter_interior` sin
## contarle de dónde venía ni cómo:
##
##   1. El viaje rápido caía en el `PlayerSpawn` del puzle en vez del
##      `TravelSpawn`, que es el que está junto al guardián: llegabas al
##      principio del Isluga y había que resolverlo entero otra vez.
##   2. `_pos_antes_interior` guarda dónde estabas EN EL MUNDO antes de entrar,
##      y se reescribía con la posición dentro del interior anterior. Como el
##      Ojos del Salado está a 110 m de altura, al salir del Isluga te dejaba en
##      la cima del volcán en vez de en su entrada.

const GAME := preload("res://scenes/core/Game.tscn")
const ISLUGA := preload("res://scenes/puzzles/Isluga.tscn")


func after_all() -> void:
	GameManager.reset_progress()


func _juego() -> Node:
	GameManager.reset_progress()
	var g: Node = GAME.instantiate()
	add_child_autofree(g)
	await wait_physics_frames(6)
	for e in get_errors():
		e.handled = true   # avisos del motor al montar el mundo
	return g


## El Isluga tiene que traer los dos marcadores, y separados: si fueran el mismo
## sitio, el viaje rápido no ahorraría nada.
func test_el_isluga_tiene_los_dos_puntos_de_entrada() -> void:
	var r: Node = ISLUGA.instantiate()
	add_child_autofree(r)
	await wait_physics_frames(2)
	var inicio: Node3D = r.find_child("PlayerSpawn", true, false)
	var viaje: Node3D = r.find_child("TravelSpawn", true, false)
	assert_not_null(inicio, "el Isluga trae PlayerSpawn")
	assert_not_null(viaje, "el Isluga trae TravelSpawn")
	if inicio == null or viaje == null:
		return
	assert_gt(inicio.global_position.distance_to(viaje.global_position), 5.0,
		"los dos puntos de entrada están en sitios distintos")


func test_el_viaje_rapido_entra_por_el_travelspawn() -> void:
	var g := await _juego()
	await g.go_to("Isluga", true)
	await wait_physics_frames(4)
	var r: Node = g._region_holder.get_child(0)
	var viaje: Node3D = r.find_child("TravelSpawn", true, false)
	var inicio: Node3D = r.find_child("PlayerSpawn", true, false)
	var p: Node3D = g.active_character()
	assert_not_null(p, "hay personaje activo")
	if p == null or viaje == null or inicio == null:
		return
	var d_viaje: float = p.global_position.distance_to(viaje.global_position)
	var d_inicio: float = p.global_position.distance_to(inicio.global_position)
	assert_lt(d_viaje, d_inicio,
		"el viaje rápido deja al party junto al guardián, no al principio del puzle")


## El fallo 2: la posición del mundo NO se pisa al saltar de interior a interior.
func test_saltar_de_interior_a_interior_no_pisa_la_salida() -> void:
	var g := await _juego()
	await g.go_to("OjosDelSalado", true)
	await wait_physics_frames(4)
	var afuera: Vector3 = g._pos_antes_interior

	# El Ojos del Salado transcurre a ~110 m de altura: si esto se colara como
	# "sitio del mundo", al salir del siguiente interior aparecerías por el aire.
	var dentro: Vector3 = g.active_character().global_position
	assert_gt(absf(dentro.y - afuera.y), 20.0,
		"dentro del puzle se está muy por encima del mundo: el caso que fallaba")

	await g.go_to("Isluga", true)
	await wait_physics_frames(4)
	assert_almost_eq(g._pos_antes_interior, afuera, Vector3.ONE * 0.01,
		"saltar de un interior a otro conserva el sitio del MUNDO al que se vuelve")
