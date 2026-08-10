extends "res://addons/gut/test.gd"

## Beat 4 — Isluga: el cubo del piso 1 activa el ASCENSOR del otro; arriba, los 4
## cubos de altura de cada uno; cuando LOS DOS terminan, se supera.

const ISLUGA := preload("res://scenes/puzzles/Isluga.tscn")

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_cube_activates_the_other_vert() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	assert_false(c.vert_active("BenjaminVert"), "arranca inactivo")
	c.get_node("EmiliaCube").activated.emit()   # Emilia activa el ascensor de Benjamín
	assert_true(c.vert_active("BenjaminVert"))
	assert_false(c.vert_active("EmiliaVert"))
	c.get_node("BenjaminCube").activated.emit()  # Benjamín activa el de Emilia
	assert_true(c.vert_active("EmiliaVert"))


func test_hitcube_activates_after_n_hits() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	var cube := c.get_node("EmiliaCube")   # 2 golpes
	watch_signals(cube)
	cube.take_damage()
	assert_false(cube.is_done())
	cube.take_damage()
	assert_true(cube.is_done())
	assert_signal_emitted(cube, "activated")


func test_both_finish_top_cubes_solves() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	watch_signals(c)
	for cube in c.get_node("EmiliaTopCubes").get_children():
		cube.activated.emit()
	assert_eq(c.emilia_progress(), 4)
	assert_false(c.is_solved(), "con los de Emilia solo no basta")
	for cube in c.get_node("BenjaminTopCubes").get_children():
		cube.activated.emit()
	assert_true(c.is_solved(), "con los 4 de cada uno, superado")
	assert_signal_emitted(c, "solved")
	assert_eq(GameManager.get_beat(), 4)
