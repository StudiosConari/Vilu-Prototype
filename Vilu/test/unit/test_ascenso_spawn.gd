extends "res://addons/gut/test.gd"

## Dos protagonistas persistentes (melee + arquero), swap con cámara correcta.

const GAME := preload("res://scenes/core/Game.tscn")

func after_all() -> void:
	GameManager.reset_progress()


func test_spawns_two_distinct_characters() -> void:
	GameManager.reset_progress()
	var game := GAME.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(game.party.size(), 2, "arranca con 2 personajes")
	assert_false(game.party[0].is_archer, "el 1º es melee")
	assert_true(game.party[1].is_archer, "el 2º es arquero")

	var cam_a := game.party[0].get_node("Camera") as Camera3D
	var cam_b := game.party[1].get_node("Camera") as Camera3D
	assert_true(cam_a.current, "el activo (melee) tiene la cámara")
	assert_false(cam_b.current, "el inactivo no")

	game.swap_character()
	assert_false(cam_a.current, "tras R, el melee suelta la cámara")
	assert_true(cam_b.current, "tras R, el arquero toma la cámara")


func test_party_persists_through_travel() -> void:
	GameManager.reset_progress()
	var game := GAME.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	GameManager.set_beat(4)
	await game.go_to("AscensoOjos")
	await get_tree().process_frame
	assert_eq(game.party.size(), 2, "los 2 personajes persisten al viajar")
	assert_true(TravelManager.current_region == "AscensoOjos")
