extends "res://addons/gut/test.gd"

## Beat 4 — Isluga: cada uno activa con [E] su obelisco, que pone en marcha el
## ASCENSOR del otro; arriba, hablar con el guardián supera el desafío.

const ISLUGA := preload("res://scenes/puzzles/Isluga.tscn")

## Los nodos se buscan por NOMBRE en todo el árbol, igual que hace el juego.
## Con rutas fijas, agrupar el cráter bajo un nodo `Crater` rompía los tests sin
## que nada estuviera mal en la lógica.

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_cube_activates_the_other_vert() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	assert_false(c.vert_active("BenjaminVert"), "arranca inactivo")
	c.find_child("EmiliaCube", true, false).activated.emit()   # Emilia activa el ascensor de Benjamín
	assert_true(c.vert_active("BenjaminVert"))
	assert_false(c.vert_active("EmiliaVert"))
	c.find_child("BenjaminCube", true, false).activated.emit()  # Benjamín activa el de Emilia
	assert_true(c.vert_active("EmiliaVert"))


func test_el_obelisco_no_se_acciona_a_golpes() -> void:
	# El diseño cambió: estos se accionan con [E]. El test viejo los golpeaba dos
	# veces y esperaba que se activaran, que es justo lo que ya no debe pasar.
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	var cube := c.find_child("EmiliaCube", true, false)
	watch_signals(cube)
	cube.take_damage()
	cube.take_damage()
	cube.take_damage()
	assert_false(cube.is_done(), "los golpes no lo accionan")
	assert_signal_not_emitted(cube, "activated")


func test_el_obelisco_se_acciona_al_interactuar() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	var cube := c.find_child("EmiliaCube", true, false)
	watch_signals(cube)
	cube._al_interactuar(null)
	assert_true(cube.is_done(), "con [E] queda accionado de una")
	assert_signal_emitted(cube, "activated")


func test_hablar_con_el_guardian_supera_el_desafio() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	watch_signals(c)
	assert_false(c.is_solved(), "arranca sin superar")
	c.superar()
	assert_true(c.is_solved())
	assert_signal_emitted(c, "solved")
	assert_true(GameManager.tiene_logro("isluga"), "concede el logro de la zona")
	assert_eq(GameManager.get_beat(), 4, "y avanza el beat")


func test_superar_dos_veces_no_repite() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	c.superar()
	watch_signals(c)
	c.superar()
	assert_signal_not_emitted(c, "solved", "la segunda charla no vuelve a superarlo")


func test_no_depende_de_los_cubos_de_altura_que_ya_no_estan() -> void:
	# Regresión de un fallo real: la condición de superado exigía cuatro "cubos
	# de altura" por personaje. Ese piso se quitó del nivel y nadie tocó la
	# condición, así que el desafío quedó IMPOSIBLE y el beat 4 no avanzaba.
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	assert_null(c.get_node_or_null("EmiliaTopCubes"), "ese piso ya no existe")
	assert_null(c.get_node_or_null("BenjaminTopCubes"))
	c.superar()
	assert_true(c.is_solved(), "y aun así se supera")
