extends "res://addons/gut/test.gd"

## Beat 5 — AscensoOjos (rediseño): rompecabezas de letras VILU. Hay que hacer
## calzar las 4 letras azules con sus fantasmas rojos (posición + rotación).

const ASCENSO := preload("res://scenes/puzzles/Ascenso.tscn")
const PLAYER := preload("res://scenes/actors/Player.tscn")

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_has_four_letters_and_targets() -> void:
	var a := ASCENSO.instantiate()
	add_child_autofree(a)
	for g in ["V", "I", "L", "U"]:
		assert_not_null(a.letter(g), "existe la letra %s" % g)
		assert_true(a._targets.has(g), "existe el objetivo de %s" % g)


func test_all_letters_placed_solves_beat5() -> void:
	var a := ASCENSO.instantiate()
	add_child_autofree(a)
	watch_signals(a)
	for g in ["V", "I", "L", "U"]:
		a.place_at_target(g)
	a._check()
	assert_true(a.is_solved())
	assert_signal_emitted(a, "solved")
	assert_eq(GameManager.get_beat(), 5, "completar VILU entra al Beat 5")


func test_not_solved_when_one_missing() -> void:
	var a := ASCENSO.instantiate()
	add_child_autofree(a)
	for g in ["V", "I", "L"]:
		a.place_at_target(g)
	a._check()
	assert_false(a.is_solved(), "con una letra fuera de lugar no se resuelve")


func test_face_move_maps_directions() -> void:
	var a := ASCENSO.instantiate()
	add_child_autofree(a)
	var c := Vector3.ZERO
	assert_eq(a._face_move(Vector3(5, 0, 0), c), Vector3(1, 0, 0), "cara este -> derecha")
	assert_eq(a._face_move(Vector3(-5, 0, 0), c), Vector3(-1, 0, 0), "cara oeste -> izquierda")
	assert_eq(a._face_move(Vector3(0, 0, 5), c), Vector3(0, 0, 1), "cara sur -> abajo")
	assert_eq(a._face_move(Vector3(0, 0, -5), c), Vector3(0, 0, -1), "cara norte -> arriba")


func test_player_set_active_toggles() -> void:
	var p := PLAYER.instantiate()
	add_child_autofree(p)
	p.set_active(false)
	assert_false(p.active)
	p.set_active(true)
	assert_true(p.active)
