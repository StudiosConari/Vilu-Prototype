extends "res://addons/gut/test.gd"

## Lógica del puzzle de Isluga (Beat 4): requiere combo + flecha para abrir el paso.

const ISLUGA := preload("res://scenes/puzzles/Isluga.tscn")

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_needs_both_parts_to_solve() -> void:
	var p := ISLUGA.instantiate()
	add_child_autofree(p)
	watch_signals(p)
	p._mark_combo_done()
	assert_false(p.is_solved(), "solo el combo no resuelve")
	p._on_target_hit()
	assert_true(p.is_solved(), "combo + flecha resuelven")
	assert_signal_emitted(p, "solved")
	assert_eq(GameManager.get_beat(), 4, "resolver entra al Beat 4")


func test_target_alone_not_enough() -> void:
	var p := ISLUGA.instantiate()
	add_child_autofree(p)
	p._on_target_hit()
	assert_false(p.is_solved(), "solo la flecha no resuelve")


func test_timed_target_mark_hit() -> void:
	var p := ISLUGA.instantiate()
	add_child_autofree(p)
	var target := p.get_node("TimedTarget")
	watch_signals(target)
	target.mark_hit()
	assert_true(target.is_done())
	assert_signal_emitted(target, "hit_while_active")
