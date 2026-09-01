extends "res://addons/gut/test.gd"

## Caer a la lava del Isluga tiene que devolverte, no dejarte atravesar.
##
## Regresión de un fallo real: el umbral de caída era un valor absoluto (y=-8)
## para todo el juego. El cráter del Isluga vive a y≈300, así que no se cruzaba
## nunca: se atravesaba la lava y se quedaba uno de pie sobre la cáscara del
## volcán, con el cráter de techo y sin forma de volver.

const GAME := preload("res://scenes/core/Game.tscn")

var _errores_antes = null


func before_all() -> void:
	# Terrain3D llama a una función que Godot 4.7 marcó obsoleta; es una
	# GDExtension y no se puede arreglar desde el proyecto.
	_errores_antes = gut.error_tracker.treat_engine_errors_as
	gut.error_tracker.treat_engine_errors_as = GutUtils.TREAT_AS.NOTHING

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	if _errores_antes != null:
		gut.error_tracker.treat_engine_errors_as = _errores_antes
	GameManager.reset_progress()


func _juego() -> Node:
	var g := GAME.instantiate()
	add_child_autofree(g)
	await get_tree().process_frame
	await get_tree().process_frame
	return g


func test_en_el_mundo_abierto_sigue_valiendo_el_umbral_de_siempre() -> void:
	var g := await _juego()
	assert_eq(g._limite_de_caida(), g.fall_limit,
		"fuera de un interior no cambia nada")


func test_el_isluga_declara_su_propio_umbral() -> void:
	var g := await _juego()
	await g.enter_interior("Isluga")
	await wait_physics_frames(2)
	assert_eq(g._limite_de_caida(), 285.0,
		"dentro del cráter manda el umbral de la región")
	assert_ne(g._limite_de_caida(), g.fall_limit,
		"y no el absoluto del mundo, que ahí no se cruza jamás")


func test_caer_a_la_lava_devuelve_al_punto_seguro() -> void:
	var g := await _juego()
	await g.enter_interior("Isluga")
	await wait_physics_frames(2)
	var antes: float = g.party[0].global_position.y
	# Hundirse por debajo del manto de nubes
	g.party[0].global_position = Vector3(0, 270, 0)
	g._check_fall()
	await wait_physics_frames(2)
	assert_gt(g.party[0].global_position.y, 285.0,
		"vuelve por encima del umbral")
	assert_almost_eq(g.party[0].global_position.y, antes, 3.0,
		"y a la altura en la que apareció, no al fondo del volcán")
