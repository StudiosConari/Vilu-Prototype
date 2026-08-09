extends "res://addons/gut/test.gd"

## Lógica del arena de oleadas (Beat 3): despejar avanza el beat y emite cleared.

const WAVE_ARENA := preload("res://scenes/actors/WaveArena.tscn")

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_spawns_expected_count() -> void:
	var arena := WAVE_ARENA.instantiate()
	add_child_autofree(arena)
	arena.waves = [2]
	arena.start()
	assert_eq(arena.alive_count(), 2)
	assert_eq(arena.get_current_enemies().size(), 2)


func test_clearing_advances_beat_and_emits() -> void:
	var arena := WAVE_ARENA.instantiate()
	add_child_autofree(arena)
	arena.waves = [1]
	watch_signals(arena)
	arena.start()

	var enemies: Array = arena.get_current_enemies()
	assert_eq(enemies.size(), 1)
	# Simular muerte del enemigo (dispara el conteo de la oleada).
	enemies[0].died.emit(Vector3.ZERO, 0)

	assert_true(arena.is_cleared(), "el arena debe quedar despejado")
	assert_signal_emitted(arena, "cleared")
	assert_eq(GameManager.get_beat(), 3, "despejar entra al Beat 3")


func test_two_waves_need_both_cleared() -> void:
	var arena := WAVE_ARENA.instantiate()
	add_child_autofree(arena)
	arena.waves = [1, 1]
	arena.start()

	# Primera oleada
	arena.get_current_enemies()[0].died.emit(Vector3.ZERO, 0)
	assert_false(arena.is_cleared(), "tras la 1a oleada aun no despeja")
	# Segunda oleada (se respawnea)
	assert_eq(arena.alive_count(), 1)
	arena.get_current_enemies()[0].died.emit(Vector3.ZERO, 0)
	assert_true(arena.is_cleared(), "tras la 2a oleada despeja")
