extends GutTest

## El puntero aparece con el juego en pausa.
##
## EL FALLO. `_mandar_el_raton()` colgaba del `_process` de Game, que es
## pausable. Al abrir el menú de pausa Game deja de procesar y la línea que
## suelta el puntero no corre nunca: la condición `get_tree().paused` estaba
## escrita ahí y era inalcanzable. El ratón se quedaba capturado justo en el
## único momento en que hay algo que pulsar.

const JUEGO := preload("res://scenes/core/Game.gd")


func test_el_mando_del_raton_corre_en_pausa() -> void:
	var m: Node = JUEGO.MandoDelRaton.new()
	assert_eq(m.process_mode, Node.PROCESS_MODE_ALWAYS,
		"si se pausara con el resto, no habría quien soltase el puntero")
	m.free()


func test_no_arrastra_a_nadie_a_correr_en_pausa() -> void:
	# POR QUÉ UN HIJO Y NO PROCESS_MODE_ALWAYS EN GAME: el modo de proceso lo
	# heredan los hijos. Puesto en Game seguirían corriendo el mundo, los
	# enemigos y el party, o sea que la pausa dejaría de pausar. Este nodo tiene
	# que quedarse sin hijos.
	var m: Node = JUEGO.MandoDelRaton.new()
	assert_eq(m.get_child_count(), 0, "nodo hoja: no arrastra a nadie")
	m.free()


func test_le_pide_al_padre_que_mande_el_raton() -> void:
	var padre := Espia.new()
	var m: Node = JUEGO.MandoDelRaton.new()
	padre.add_child(m)
	add_child_autofree(padre)
	# `process_frame` y no `wait_frames`: éste es un `_process`, y en headless el
	# cuadro de idle no lo trae el de física.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(padre.veces, 0, "cada cuadro le pasa la pregunta al juego")


func test_con_el_padre_mudo_no_revienta() -> void:
	# Se comprueba el método antes de llamarlo: en un test o a medio montar, el
	# padre puede no ser Game todavía.
	var padre := Node.new()
	var m: Node = JUEGO.MandoDelRaton.new()
	padre.add_child(m)
	add_child_autofree(padre)
	await get_tree().process_frame
	await get_tree().process_frame
	pass_test("sobrevive a un padre que no sabe mandar el ratón")


class Espia extends Node:
	var veces := 0
	func _mandar_el_raton() -> void:
		veces += 1
