extends "res://addons/gut/test.gd"

## Diagnóstico: al viajar al Ascenso, ¿se agrega el compañero al party (2 chars)?

const GAME := preload("res://scenes/core/Game.tscn")

func after_all() -> void:
	GameManager.reset_progress()


func test_ascenso_adds_companion_to_party() -> void:
	GameManager.reset_progress()
	var game := GAME.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.party.size(), 1, "arranca con 1 personaje")
	GameManager.set_beat(4)
	await game.go_to("AscensoOjos")
	await get_tree().process_frame
	assert_eq(game.party.size(), 2, "el Ascenso debe agregar el compañero (2 chars)")
	assert_true(TravelManager.current_region == "AscensoOjos")

	# Cámara: solo la del personaje activo debe estar current tras agregar al compañero.
	var active_cam := game.party[0].get_node("Camera") as Camera3D
	var other_cam := game.party[1].get_node("Camera") as Camera3D
	assert_true(active_cam.current, "la cámara del activo está current")
	assert_false(other_cam.current, "la cámara del inactivo NO está current")

	# Swap: al cambiar, se invierte quién tiene la cámara.
	game.swap_character()
	assert_false(active_cam.current, "tras swap, el antes-activo ya no")
	assert_true(other_cam.current, "tras swap, el compañero toma la cámara")
