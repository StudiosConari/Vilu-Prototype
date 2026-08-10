extends "res://addons/gut/test.gd"

## Beat 4 — Isluga cooperativo: el cubo de cada uno activa el ASCENSOR del otro;
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


func test_cube_activates_the_other_vert() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	assert_false(c.vert_active("BenjaminVert1"), "arranca inactivo")
	c.get_node("EmiliaCube1").activated.emit()   # Emilia activa el ascensor de Benjamín
	assert_true(c.vert_active("BenjaminVert1"))
	assert_false(c.vert_active("EmiliaVert1"))
	c.get_node("BenjaminCube1").activated.emit()  # Benjamín activa el de Emilia
	assert_true(c.vert_active("EmiliaVert1"))


func test_hitcube_activates_after_n_hits() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	var cube := c.get_node("EmiliaCube1")   # 2 golpes
	watch_signals(cube)
	cube.take_damage()
	assert_false(cube.is_done(), "con 1 golpe aún no")
	cube.take_damage()
	assert_true(cube.is_done(), "al 2º golpe se activa")
	assert_signal_emitted(cube, "activated")


func test_both_on_top_solves() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	watch_signals(c)
	c._on_top_enter(_fake_player())
	assert_false(c.is_solved(), "con uno solo arriba no")
	c._on_top_enter(_fake_player())
	assert_true(c.is_solved(), "con los dos arriba, superado")
	assert_signal_emitted(c, "solved")
	assert_eq(GameManager.get_beat(), 4)
