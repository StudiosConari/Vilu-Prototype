extends "res://addons/gut/test.gd"

## Beat 6 — habilidades como estado del Player y arena de cazadores.
## Las habilidades ya no las da un AbilityGiver genérico: las otorgan las
## escenas narrativas (AlicantoRescate -> alas, YastayEncounter -> guanaco).

const PLAYER := preload("res://scenes/actors/Player.tscn")
const WAVE_ARENA := preload("res://scenes/actors/WaveArena.tscn")
const ENEMY_FAST := preload("res://scenes/enemies/EnemyFast.tscn")

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_wings_enables_glide_state() -> void:
	var p := PLAYER.instantiate()
	add_child_autofree(p)
	assert_false(p.can_glide, "sin alas no planea")
	GameManager.unlock("wings")
	assert_true(p.can_glide, "desbloquear alas activa el planeo (estado)")


func test_wings_only_for_melee() -> void:
	var emilia := PLAYER.instantiate()
	emilia.is_archer = false
	add_child_autofree(emilia)
	var benja := PLAYER.instantiate()
	benja.is_archer = true
	add_child_autofree(benja)
	GameManager.unlock("wings")
	assert_true(emilia.can_glide, "Emilia (melee) planea/doble salto con alas")
	assert_false(benja.can_glide, "Benjamín (arquero) NO obtiene alas")


func test_four_hit_combo() -> void:
	var emilia := PLAYER.instantiate()
	add_child_autofree(emilia)
	assert_eq(emilia.melee_damage.size(), 4, "el combo de Emilia es de 4 golpes")


func test_ai_mode_freeze_toggle() -> void:
	var p := PLAYER.instantiate()
	add_child_autofree(p)
	p.set_ai_mode(false)
	assert_eq(p.ai_mode, 1, "T deja al personaje FROZEN")
	p.set_ai_mode(true)
	assert_eq(p.ai_mode, 0, "R deja al personaje en IA COMBAT")


func test_hold_returns_to_post() -> void:
	var p := PLAYER.instantiate()
	add_child_autofree(p)
	p.global_position = Vector3.ZERO
	p.set_active(false)
	p.set_ai_mode(false)              # QUIETO: fija el puesto en (0,0,0)
	p.global_position = Vector3(5, 0, 0)   # lo desplazamos
	var dir: Vector3 = p._hold_behavior()
	assert_lt(dir.x, 0.0, "sin enemigos, vuelve hacia su puesto (-x)")


func test_guard_commits_to_target() -> void:
	GameManager.reset_progress()
	var emilia := PLAYER.instantiate()
	emilia.is_archer = false
	add_child_autofree(emilia)
	emilia.global_position = Vector3.ZERO
	emilia.set_active(false)
	emilia.set_ai_mode(false)             # guardia en (0,0,0)
	var enemy := preload("res://scenes/enemies/EnemyNormal.tscn").instantiate()
	add_child_autofree(enemy)
	enemy.global_position = Vector3(2, 0, 0)   # en rango de defensa, fuera de melee
	emilia._hold_behavior()
	var t: Node = emilia._guard_target
	assert_not_null(t, "el guardia adquiere el objetivo en rango")
	enemy.global_position = Vector3(6, 0, 0)   # se aleja, pero dentro de la correa (14)
	emilia._hold_behavior()
	assert_eq(emilia._guard_target, t, "lo persigue: mantiene el mismo objetivo hasta rematarlo")


func test_triple_arrow_needs_tirana_and_energy() -> void:
	var benja := PLAYER.instantiate()
	benja.is_archer = true
	add_child_autofree(benja)
	var e0: float = benja.energy
	benja._triple_arrow()   # sin la Tirana (has_bow) → no gasta
	assert_eq(benja.energy, e0, "sin la Tirana no dispara triple")
	GameManager.unlock("bow")
	benja.energy = 5.0
	benja._triple_arrow()   # con la Tirana pero sin energía → no gasta
	assert_eq(benja.energy, 5.0, "sin energía no dispara triple")


func test_ability_visuals_toggle() -> void:
	var p := PLAYER.instantiate()
	add_child_autofree(p)
	assert_false(p.get_node("Visual/Wings").visible, "alas ocultas por defecto")
	p.can_glide = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(p.get_node("Visual/Wings").visible, "alas visibles con can_glide")


## El cubo café Visual/Guanaco quedó obsoleto: la montura ahora es el
## GuanacoCompanion real, así que el placeholder no debe mostrarse nunca.
func test_guanaco_placeholder_stays_hidden() -> void:
	var p := PLAYER.instantiate()
	add_child_autofree(p)
	p.mounted = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(p.get_node("Visual/Guanaco").visible,
		"el cubo placeholder no se usa como montura")


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
