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

	assert_true(game.party[0].active, "el melee arranca activo")
	assert_false(game.party[1].active, "el arquero arranca inactivo")

	game.swap_character()
	assert_false(game.party[0].active, "tras R, el melee deja de ser activo")
	assert_true(game.party[1].active, "tras R, el arquero pasa a activo")
	assert_eq(game.active_index, 1)


func test_debug_start_zone() -> void:
	GameManager.reset_progress()
	GameManager.debug_start_zone = "Cumbre"
	var game := GAME.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	assert_eq(TravelManager.current_region, "Cumbre", "Game arranca en la zona de debug")
	assert_eq(GameManager.debug_start_zone, "", "se limpia tras usarla")


func test_fall_resets_zone() -> void:
	GameManager.reset_progress()
	var game := GAME.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	game.party[0].global_position = Vector3(0, -50, 0)   # cae al vacío
	game._check_fall()
	assert_gt(game.party[0].global_position.y, game.fall_limit, "tras caer se reubica arriba del límite")


func test_party_persists_through_travel() -> void:
	GameManager.reset_progress()
	var game := GAME.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	GameManager.set_beat(4)
	await game.go_to("Poblado")
	await get_tree().process_frame
	assert_eq(game.party.size(), 2, "los 2 personajes persisten al viajar")
	assert_true(TravelManager.current_region == "Poblado")
