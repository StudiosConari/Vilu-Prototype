extends "res://addons/gut/test.gd"

## Beat 7 — Cumbre multinivel: la cima requiere a LOS DOS; llegar arriba arma la cuerda.

const CUMBRE := preload("res://scenes/puzzles/Cumbre.tscn")

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func _fake_player() -> Node3D:
	var n := Node3D.new()
	n.add_to_group("player")
	add_child_autofree(n)
	return n


func test_final_needs_both_to_solve() -> void:
	var c := CUMBRE.instantiate()
	add_child_autofree(c)
	watch_signals(c)
	c._on_final_enter(_fake_player())
	assert_false(c.is_solved(), "con un solo personaje en la cima no se resuelve")
	c._on_final_enter(_fake_player())
	assert_true(c.is_solved(), "con LOS DOS en la cima, resuelto")
	assert_signal_emitted(c, "reached_summit")
	assert_eq(GameManager.get_beat(), 7, "resolver entra al Beat 7")


func test_switch_activates_updraft2() -> void:
	var c := CUMBRE.instantiate()
	add_child_autofree(c)
	var updraft2 := c.get_node("Updraft2")
	assert_false(updraft2.active, "la corriente 2 arranca inactiva")
	var sw := c.get_node("ArrowSwitch")
	sw.activated.emit()   # simular acierto de flecha al cubo
	assert_true(updraft2.active, "acertar el cubo activa la corriente 2")


func test_reaching_platform1_arms_rope() -> void:
	var c := CUMBRE.instantiate()
	add_child_autofree(c)
	var rope1 := c.get_node("Rope1")
	assert_false(rope1.armed, "la cuerda arranca sin armar")
	c._on_platform1_reached(_fake_player())
	assert_true(rope1.armed, "llegar a Platform_1 arma la cuerda para el otro")
