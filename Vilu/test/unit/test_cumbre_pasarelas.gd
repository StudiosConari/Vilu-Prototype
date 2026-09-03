extends "res://addons/gut/test.gd"

## Qué plataformas de la cumbre matan y cuáles no.
##
## Regresión de un fallo que dejaba el prototipo sin terminar: en la escena hay
## DOS nodos llamados `camino_de_ladrillos_de_piedra3` —uno bajo "Plataforma",
## que es la pasarela trampa, y otro bajo "FinalTrigger", que es la plataforma
## del Guardián—. Las trampas se buscaban por nombre suelto con `find_child`,
## que recorre el árbol entero y devuelve el primero: salía el del Guardián.
##
## O sea que la trampa quedaba puesta en la plataforma final —pisarla para
## hablar con él te echaba al principio, y no había forma de cerrar el juego— y
## la pasarela mortal de verdad no hacía nada.

const CUMBRE := preload("res://scenes/puzzles/OjosDelSalado.tscn")


func after_all() -> void:
	GameManager.reset_progress()


func _cumbre() -> Node3D:
	GameManager.reset_progress()
	var c: Node3D = CUMBRE.instantiate()
	add_child_autofree(c)
	await wait_physics_frames(4)
	for e in get_errors():
		e.handled = true   # avisos del motor al montar la escena, no del puzle
	return c


func test_las_trampas_son_las_de_plataforma() -> void:
	var c := await _cumbre()
	var rutas: Array = []
	for p: Node3D in c._pasarelas:
		rutas.append(str(c.get_path_to(p)))
	rutas.sort()
	assert_eq(rutas, ["Plataforma/camino_de_ladrillos_de_piedra3",
			"Plataforma/camino_de_ladrillos_de_piedra4"],
		"las dos pasarelas trampa son las de 'Plataforma'")


## La que importa: sobre ésta hay que poder pararse a hablar con el Guardián.
func test_la_plataforma_del_guardian_no_es_trampa() -> void:
	var c := await _cumbre()
	var final: Node3D = c.get_node("FinalTrigger/camino_de_ladrillos_de_piedra3")
	assert_false(final in c._pasarelas,
		"la plataforma del Guardián no puede ser una trampa")


func test_hay_checkpoint_en_la_bifurcacion() -> void:
	var c := await _cumbre()
	var m: Node3D = c.get_node_or_null(c.CHECKPOINT)
	assert_not_null(m, "la cumbre tiene el marcador '%s'" % c.CHECKPOINT)
	if m == null:
		return
	# Tiene que estar entre medias, no en el arranque: si coincidiera con el
	# spawn, caer en la trampa devolvería al principio igual que antes.
	var sp: Node3D = c.get_node("PlayerSpawn")
	assert_gt(m.global_position.distance_to(sp.global_position), 10.0,
		"el checkpoint no es el punto de partida")
