extends "res://addons/gut/test.gd"

## Beat 4 — Isluga colaborativo: los cubos de cada uno abren la salida del OTRO;
## cuando LOS DOS llegan a la cima, superan el desafío.

const ISLUGA := preload("res://scenes/puzzles/Isluga.tscn")

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func _fake_player() -> Node3D:
	var n := Node3D.new()
	n.add_to_group("player")
	add_child_autofree(n)
	return n


func test_hitcube_activates_after_n_hits() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	var cube := c.get_node("EmiliaCubes/Cube3")   # necesita 3 golpes
	watch_signals(cube)
	cube.take_damage()
	cube.take_damage()
	assert_false(cube.is_done(), "con 2 golpes aún no se activa")
	cube.take_damage()
	assert_true(cube.is_done(), "al 3er golpe se activa")
	assert_signal_emitted(cube, "activated")


func test_both_must_finish_and_meet_on_top() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	watch_signals(c)
	# Los 4 cubos de Emilia -> abre la salida de Benjamín.
	for cube in c.get_node("EmiliaCubes").get_children():
		cube.activated.emit()
	assert_eq(c.emilia_progress(), 4)
	# Los 4 de Benjamín -> abre la de Emilia.
	for cube in c.get_node("BenjaminCubes").get_children():
		cube.activated.emit()
	assert_eq(c.benja_progress(), 4)
	# Ambos suben a la cima.
	c._on_top_enter(_fake_player())
	assert_false(c.is_solved(), "con uno solo arriba no se resuelve")
	c._on_top_enter(_fake_player())
	assert_true(c.is_solved(), "con los dos arriba, superado")
	assert_signal_emitted(c, "solved")
	assert_eq(GameManager.get_beat(), 4)
