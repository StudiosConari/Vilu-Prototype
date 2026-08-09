extends "res://addons/gut/test.gd"

## Beat 7 — cumbre: el objetivo libera la barrera; llegar a la cima entra al Beat 7.

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


func test_summit_reaches_beat7() -> void:
	var c := CUMBRE.instantiate()
	add_child_autofree(c)
	watch_signals(c)
	c._on_summit(_fake_player())
	assert_true(c.is_solved())
	assert_signal_emitted(c, "reached_summit")
	assert_eq(GameManager.get_beat(), 7, "llegar a la cima entra al Beat 7")


func test_target_frees_barrier() -> void:
	var c := CUMBRE.instantiate()
	add_child_autofree(c)
	assert_not_null(c.get_node_or_null("Barrier2"))
	c._on_target_hit()
	assert_null(c._barrier, "acertar el objetivo libera la barrera")
