extends "res://addons/gut/test.gd"

## Beat 6 — criaturas otorgan habilidades (estados) y arena de cazadores.

const GIVER := preload("res://scenes/actors/AbilityGiver.tscn")
const PLAYER := preload("res://scenes/actors/Player.tscn")
const WAVE_ARENA := preload("res://scenes/actors/WaveArena.tscn")
const ENEMY_FAST := preload("res://scenes/enemies/EnemyFast.tscn")

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_giver_unlocks_ability() -> void:
	var g := GIVER.instantiate()
	add_child_autofree(g)
	g.ability = "guanaco"
	assert_false(GameManager.has_ability("guanaco"))
	g._on_interacted(null)
	assert_true(GameManager.has_ability("guanaco"))


func test_wings_enables_glide_state() -> void:
	var p := PLAYER.instantiate()
	add_child_autofree(p)
	assert_false(p.can_glide, "sin alas no planea")
	GameManager.unlock("wings")
	assert_true(p.can_glide, "desbloquear alas activa el planeo (estado)")


func test_arena_uses_configured_enemy_and_color() -> void:
	var arena := WAVE_ARENA.instantiate()
	add_child_autofree(arena)
	arena.enemy_a = ENEMY_FAST
	arena.enemy_color = Color(1, 0.55, 0.1)
	arena.waves = [1]
	arena.b_every = 0   # solo tipo A
	arena.start()
	var e = arena.get_current_enemies()[0]
	assert_almost_eq(e.base_color.r, 1.0, 0.02)
	assert_almost_eq(e.base_color.g, 0.55, 0.02)
