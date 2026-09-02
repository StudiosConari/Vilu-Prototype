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


## Las alas sólo se ven mientras se USAN: del segundo salto hasta tocar suelo, y
## planeando. Tener la habilidad no basta; antes aparecían al desbloquearla y ya
## no se guardaban nunca, ni caminando.
func test_ability_visuals_toggle() -> void:
	var p := PLAYER.instantiate()
	add_child_autofree(p)
	var alas: Node3D = p.get_node("Visual/Wings")
	assert_false(alas.visible, "alas ocultas por defecto")

	p.can_glide = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(alas.visible, "con la habilidad pero sin usarlas, siguen guardadas")

	p._jumps_done = 2                      # acaba de hacer el salto doble
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(alas.visible, "en el salto doble se despliegan")

	p._jumps_done = 0                      # tocó suelo
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(alas.visible, "al aterrizar se guardan")


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


## El compañero acompaña, no pelea.
##
## Antes tenía una IA de combate que perseguía y remataba sola. Se quitó a
## propósito: las peleas son del personaje que estás llevando.
func test_el_companero_se_pone_atras_y_al_costado() -> void:
	var lider := PLAYER.instantiate()
	lider.is_archer = false
	add_child_autofree(lider)
	lider.global_position = Vector3.ZERO
	lider.set_active(true)

	var comp := PLAYER.instantiate()
	comp.is_archer = true
	add_child_autofree(comp)
	comp.set_active(false)
	comp.set_ai_mode(true)                      # R: te sigue
	comp.global_position = Vector3(0, 0, 20)    # lejos, detrás

	var dir: Vector3 = comp._ai_behavior()
	assert_gt(dir.length(), 0.5, "estando lejos, va hacia su sitio")

	# Ya colocado en su sitio, se queda quieto y no tiembla pegado al líder.
	var frente: Vector3 = -(lider as Node3D).global_transform.basis.z
	var derecha: Vector3 = Vector3.UP.cross(frente).normalized()
	var atras: float = comp.seguir_atras
	var costado: float = comp.seguir_costado
	comp.global_position = (lider as Node3D).global_position - frente * atras \
		+ derecha * costado
	assert_almost_eq(comp._ai_behavior().length(), 0.0, 0.01,
		"en su sitio no se mueve")


func test_el_companero_no_ataca_aunque_tenga_un_enemigo_encima() -> void:
	var comp := PLAYER.instantiate()
	comp.is_archer = false
	add_child_autofree(comp)
	comp.global_position = Vector3.ZERO
	comp.set_active(false)
	comp.set_ai_mode(true)
	var enemigo := preload("res://scenes/enemies/EnemyNormal.tscn").instantiate()
	add_child_autofree(enemigo)
	enemigo.global_position = Vector3(0.5, 0, 0)   # pegado
	var vida: float = float(enemigo.health)
	comp._ai_behavior()
	assert_eq(enemigo.health, vida, "no le pega: el combate es del activo")


func test_el_companero_no_recibe_dano() -> void:
	var comp := PLAYER.instantiate()
	comp.is_archer = false
	add_child_autofree(comp)
	comp.set_active(false)
	var vida: int = int(comp.health)
	comp.take_damage(40.0)
	assert_eq(comp.health, vida, "al que no llevás no se le puede pegar")

	comp.set_active(true)
	comp.take_damage(40.0)
	assert_lt(comp.health, vida, "al activo sí")


func test_quieto_no_pelea_solo_vuelve_a_su_puesto() -> void:
	var comp := PLAYER.instantiate()
	comp.is_archer = false
	add_child_autofree(comp)
	comp.global_position = Vector3.ZERO
	comp.set_active(false)
	comp.set_ai_mode(false)                        # T: se queda quieto
	var enemigo := preload("res://scenes/enemies/EnemyNormal.tscn").instantiate()
	add_child_autofree(enemigo)
	enemigo.global_position = Vector3(2, 0, 0)     # dentro del viejo rango de defensa
	var vida: float = float(enemigo.health)
	var dir: Vector3 = comp._hold_behavior()
	assert_eq(enemigo.health, vida, "ya no defiende el puesto a golpes")
	assert_almost_eq(dir.length(), 0.0, 0.01, "y estando en su puesto no se mueve")
