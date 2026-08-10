extends "res://addons/gut/test.gd"

## Beat 5 — Ascenso (Plan B): la cima resuelve; la placa activa el puente.
## Swap de personaje a nivel de PlayerController.

const ASCENSO := preload("res://scenes/puzzles/Ascenso.tscn")
const PLAYER := preload("res://scenes/actors/Player.tscn")

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func _fake_player() -> Node3D:
	var n := Node3D.new()
	n.add_to_group("player")
	add_child_autofree(n)
	return n


func test_summit_reached_solves_beat5() -> void:
	var a := ASCENSO.instantiate()
	add_child_autofree(a)
	watch_signals(a)
	a._on_summit(_fake_player())
	assert_true(a.is_solved())
	assert_signal_emitted(a, "solved")
	assert_eq(GameManager.get_beat(), 5, "llegar a la cima entra al Beat 5")


func test_relay_two_plates_keeps_bridge() -> void:
	var a := ASCENSO.instantiate()
	add_child_autofree(a)
	var p1 := _fake_player()
	var p2 := _fake_player()
	var bridge_mesh := a.get_node("Bridge/Mesh") as Node3D
	a._on_plate_enter(p1)   # personaje en la placa cercana
	a._on_plate_enter(p2)   # el otro en la placa de enfrente
	assert_eq(a._on_plate, 2)
	a._on_plate_exit(p1)    # el primero se suelta para cruzar
	assert_eq(a._on_plate, 1)
	assert_true(bridge_mesh.visible, "el puente sigue arriba con la placa de enfrente")


func test_plate_toggles_bridge() -> void:
	var a := ASCENSO.instantiate()
	add_child_autofree(a)
	var p := _fake_player()
	var bridge_mesh := a.get_node("Bridge/Mesh") as Node3D

	a._on_plate_enter(p)
	assert_eq(a._on_plate, 1)
	assert_true(bridge_mesh.visible, "el puente aparece al sostener la placa")

	a._on_plate_exit(p)
	assert_eq(a._on_plate, 0)
	assert_false(bridge_mesh.visible, "el puente desaparece al soltar la placa")


func test_player_set_active_toggles() -> void:
	var p := PLAYER.instantiate()
	add_child_autofree(p)
	p.set_active(false)
	assert_false(p.active)
	p.set_active(true)
	assert_true(p.active)
