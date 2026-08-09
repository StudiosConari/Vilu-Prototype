extends Node3D

# Mundo cenital con camara orbital: clic derecho + arrastrar para rotar,
# rueda para acercar/alejar. La camara sigue a Emilia y el WASD se mantiene
# relativo a la orientacion actual de la camara.

@export var orbit_sensitivity: float = 0.4
@export var zoom_speed: float = 0.9
@export var min_distance: float = 3.5
@export var max_distance: float = 20.0
@export var min_pitch: float = 12.0
@export var max_pitch: float = 82.0
@export var cam_follow_speed: float = 8.0
# Modo verificacion: orbita sola y toma capturas desde 2 angulos.
@export var debug_orbit: bool = false
# Modo verificacion: rafaga de capturas (para ver el combo).
@export var debug_shots: bool = false
@export var debug_boss: bool = false

const ENEMY_SCRIPT := preload("res://scenes/Enemy.gd")
const PICKUP_SCRIPT := preload("res://scenes/Pickup.gd")
const PAUSE_SCRIPT := preload("res://scenes/PauseMenu.gd")
const PLAYER_SCRIPT := preload("res://scenes/Player.gd")
# Escenas-plantilla de enemigos (editables en el editor). Indice = tipo.
const KIND_SCENES := [
	preload("res://scenes/enemies/EnemyNormal.tscn"),   # 0 normal
	preload("res://scenes/enemies/EnemyFast.tscn"),      # 1 rapido
	preload("res://scenes/enemies/EnemyBig.tscn"),       # 2 grande
	preload("res://scenes/enemies/EnemyRanged.tscn"),    # 3 lanzador
]
const BOSS_GUARDIAN := preload("res://scenes/enemies/BossGuardian.tscn")
const ARENA := 22.0  # medio lado de la arena
const WIN_WAVE := 5  # superar esta oleada = victoria
# Tipos de enemigo: normal / rapido / grande
const KINDS := [
	{"hp": 40.0, "speed": 2.6, "dmg": 10.0, "range": 1.7, "scale": 1.0, "windup": 0.6, "color": Color(0.80, 0.25, 0.30)},
	{"hp": 22.0, "speed": 4.6, "dmg": 7.0, "range": 1.5, "scale": 0.72, "windup": 0.45, "color": Color(0.92, 0.78, 0.20)},
	{"hp": 95.0, "speed": 1.6, "dmg": 20.0, "range": 2.1, "scale": 1.55, "windup": 0.85, "color": Color(0.45, 0.25, 0.65)},
	{"hp": 26.0, "speed": 2.4, "dmg": 9.0, "range": 1.5, "scale": 0.95, "windup": 0.7, "ranged": true, "color": Color(0.40, 0.30, 0.85)},
]

var _cam: Camera3D
var _player: CharacterBody3D
var _benja: CharacterBody3D
var _active_char: CharacterBody3D
var _chars: Array = []
var _xp: int = 0
var _level: int = 1
var _levelup_timer: float = 0.0
var _r_prev: bool = false
var _npcs: Array = []  # [{node, name, dialogue, trainer}]
var _water_surface_y: float = 0.0
var _yaw: float = 45.0
var _pitch: float = 43.0
var _distance: float = 8.7
var _rotating: bool = false
var _wave: int = 0
var _score: int = 0
var _between_waves: bool = false
var _won: bool = false
var _banner_timer: float = 0.0
var _boss: Node3D = null
# Tutorial (pasillo secuencial)
var _zones: Dictionary = {}          # id de zona -> ya disparada
var _tutorial_boss: CharacterBody3D
var _boss_started := false
var _ledge_top := Vector3(92.5, 2.0, 0.0)
var _t_prev_main := false
var _hud_hp_fill: ColorRect
var _hud_sp_fill: ColorRect
var _hud_levelup: Label
var _hud_tutorial_bg: ColorRect
var _hud_tutorial_title: Label
var _hud_tutorial: Label
var _hud_label: Label
var _hud_banner: Label
var _hud_hint: Label
var _hud_dialogue: Label
var _hud_next: Label
var _hud_boss_bg: ColorRect
var _hud_boss_fill: ColorRect
var _hud_boss_label: Label
var _hud_defeat: Label
var _hud_victory: Label


func _ready() -> void:
	randomize()
	_player = $Player
	_player.position = Vector3(3, 0, 0)
	_active_char = _player
	_chars = [_player]
	_spawn_benja()
	_setup_environment()
	_setup_light()
	_setup_ground()
	_build_tutorial()
	_setup_camera()
	_setup_hud()
	add_child(PAUSE_SCRIPT.new())  # menu de pausa (Esc)
	if debug_shots:
		await _run_shot_burst()


func _spawn_benja() -> void:
	# Benja ahora es un nodo de la escena ($Benja): editable en el Inspector.
	var b: CharacterBody3D = $Benja
	b.set_follow(_player)
	_player.set_follow(b)
	_chars.append(b)
	_benja = b


func _swap_char() -> void:
	var other: CharacterBody3D = null
	for c in _chars:
		if c != _active_char and is_instance_valid(c) and not c.is_dead():
			other = c
			break
	if other == null:
		return
	_active_char.set_active(false)
	_active_char.set_follow(other)
	other.set_active(true)
	other.set_follow(_active_char)
	_active_char = other


func _all_dead() -> bool:
	for c in _chars:
		if is_instance_valid(c) and not c.is_dead():
			return false
	return true


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _setup_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -40.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	add_child(sun)


func _setup_ground() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 40.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.45, 0.30)
	mesh_inst.mesh = plane
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(76.0, 0.0, 0.0)
	body.add_child(mesh_inst)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 0.4, 40.0)
	col.shape = box
	col.position = Vector3(76.0, -0.2, 0.0)
	body.add_child(col)


func _setup_water() -> void:
	# Zona de agua: al entrar, el personaje nada. Un Area3D (deteccion) + un
	# bloque translucido azul (visual). Colocada a un lado del mapa.
	var center := Vector3(14.0, 1.0, 0.0)
	var size := Vector3(12.0, 4.0, 12.0)
	_water_surface_y = center.y + size.y * 0.5  # superficie = parte superior del bloque
	var area := Area3D.new()
	area.position = center
	add_child(area)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	area.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.4, 0.75, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.mesh = bm
	mi.material_override = mat
	area.add_child(mi)
	area.collision_mask = 2  # detectar al jugador (capa 2)
	area.body_entered.connect(_on_water_entered)
	area.body_exited.connect(_on_water_exited)


func _on_water_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("set_in_water"):
		body.set_in_water(true, _water_surface_y)


func _on_water_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("set_in_water"):
		body.set_in_water(false)


func _setup_walls() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.35, 0.34, 0.40)
	var h := 3.0
	var t := 1.0
	var s := ARENA
	# Perimetro
	_make_wall(Vector3(0, h * 0.5, -s), Vector3(s * 2 + t, h, t), wall_mat)
	_make_wall(Vector3(0, h * 0.5, s), Vector3(s * 2 + t, h, t), wall_mat)
	_make_wall(Vector3(-s, h * 0.5, 0), Vector3(t, h, s * 2 + t), wall_mat)
	_make_wall(Vector3(s, h * 0.5, 0), Vector3(t, h, s * 2 + t), wall_mat)
	# Obstaculos interiores (evitando la zona de agua en +X)
	_make_wall(Vector3(-8, 1.0, -6), Vector3(3, 2, 3), wall_mat)
	_make_wall(Vector3(-12, 1.0, 9), Vector3(2, 2, 7), wall_mat)
	_make_wall(Vector3(4, 1.0, -12), Vector3(6, 2, 2), wall_mat)
	_make_wall(Vector3(-2, 1.0, 6), Vector3(2, 2, 2), wall_mat)


func _make_wall(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)


# ============ TUTORIAL (pasillo secuencial) ============
const HW := 5.0   # medio ancho del pasillo
const WH := 4.5   # alto de muralla lateral


func _build_tutorial() -> void:
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.35, 0.34, 0.40)
	# Murallas laterales continuas (techo abierto) + tapas de fondo y final.
	_make_wall(Vector3(76, WH * 0.5, -(HW + 0.5)), Vector3(158, WH, 1.0), wall)
	_make_wall(Vector3(76, WH * 0.5, (HW + 0.5)), Vector3(158, WH, 1.0), wall)
	_make_wall(Vector3(-2, WH * 0.5, 0), Vector3(1.0, WH, (HW + 0.5) * 2), wall)
	_make_wall(Vector3(155, WH * 0.5 + 1.0, 0), Vector3(1.0, WH + 2.0, (HW + 0.5) * 2), wall)

	# 1) Movimiento (flechas en el suelo + mensaje en el panel)
	_floor_arrows(Vector3(8, 0, 2.6))
	_tutorial_zone(6, 0, "Movimiento", "Muévete con W A S D.\nSigue el pasillo hacia adelante.")

	# 2) Salto (muro saltable de extremo a extremo) + aviso de cambiar a Benja
	_tutorial_zone(11, 0, "Salto y cambio", "Pulsa ESPACIO para saltar la muralla.\n\nPulsa R para cambiar entre EMILIA y BENJA. ¡Practica con ambos!")
	_make_wall(Vector3(15, 0.55, 0), Vector3(1.0, 1.1, (HW + 0.5) * 2), wall)

	# 3) NPC Maestro: golpe y arco
	_tutorial_zone(20, 0, "El Maestro", "Acércate al Maestro y pulsa T para hablar.")
	_make_npc(Vector3(23, 0, 3.2), "Maestro", Color(0.30, 0.70, 0.90),
		"Emilia pelea con los puños; Benja con el arco. Cambia de personaje con R y practiquen.",
		"basics")
	_tutorial_zone(28, 0, "Ataques", "EMILIA:  Click izq = golpe (encadena hasta 4).\nCorrer + Click = patada voladora.\n\nBENJA (R):  Click izq = flecha.\nMantén Click = flecha PERFORANTE.")

	# 4) Combate 1 -> subir a nivel 2
	_tutorial_zone(35, 0, "Combate", "¡Derrota a los enemigos para ganar experiencia y subir de nivel!")
	_make_zone("combat1", 34.0, 0.0)

	# 5) Camara + agua (laberinto, techo abierto)
	_tutorial_zone(49, 0, "La cámara", "Mantén CLIC DERECHO y arrastra para girar la cámara y ver el camino en el agua.")
	_make_water(Vector3(63, 0, 0), Vector3(20, 2.6, (HW + 0.4) * 2))
	_make_wall(Vector3(58, 2.4, -2.0), Vector3(1.0, 4.8, 6.2), wall)
	_make_wall(Vector3(64, 2.4, 2.0), Vector3(1.0, 4.8, 6.2), wall)
	_make_wall(Vector3(69, 2.4, -2.0), Vector3(1.0, 4.8, 6.2), wall)

	# 6) Gatear (muro con hueco abajo)
	_tutorial_zone(74, 0, "Agacharse", "Pulsa C para agacharte y pasar por el hueco de la muralla.")
	_make_wall(Vector3(77, 2.5, 0), Vector3(1.0, 3.0, (HW + 0.5) * 2), wall)  # hueco y 0..1.0

	# 7) NPC Entrenadora: doble salto + guanaco
	_tutorial_zone(81, 0, "La Entrenadora", "Acércate a la Entrenadora y pulsa T para recibir un poder.")
	_make_npc(Vector3(84, 0, 3.2), "Entrenadora", Color(0.90, 0.55, 0.25),
		"Emilia: DOBLE SALTO. Benja: invoca un GUANACO espectral. ¡Cuestan energia (SP)!",
		"trainer")
	_tutorial_zone(88, 0, "Nuevos poderes", "EMILIA:  Espacio en el aire = DOBLE SALTO (alas).\n\nBENJA:  Q invoca guanaco | Q otra vez embiste | E monta.")

	# 8) Desnivel: Emilia sube y ayuda a Benja
	_make_platform(Vector3(123, 1.0, 0), Vector3(64, 2.0, (HW + 0.5) * 2))
	_tutorial_zone(90, 0, "El desnivel", "EMILIA sube con su DOBLE SALTO.\nLuego, con BENJA (R): acércate a Emilia arriba y pulsa T para que te impulse.")

	# 9) Combate 2 (sobre la plataforma) -> subir a nivel 5
	_tutorial_zone(99, 2.0, "Combate", "¡Derrota a todos para seguir fortaleciéndote!")
	_make_zone("combat2", 97.0, 2.0)

	# 10) NPC Sabia: resto de habilidades
	_tutorial_zone(117, 2.0, "La Sabia", "Acércate a la Sabia y pulsa T para el último poder.")
	_make_npc(Vector3(121, 2.0, 3.2), "Sabia", Color(0.85, 0.30, 0.55),
		"Ultimo poder. Emilia: PUÑOS DE FUEGO y LAVA. Benja: ENREDADERAS, FLECHA TRIPLE y ESTAMPIDA.",
		"master")
	_tutorial_zone(126, 2.0, "Habilidades finales", "EMILIA:  G = puños de fuego  |  F = embestida de LAVA.\n\nBENJA:  F = enredaderas  |  G = flecha TRIPLE.")

	# 11) Jefe final
	_tutorial_zone(133, 2.0, "¡JEFE FINAL!", "Derrota al Guardián. Sus ataques MARCADOS (destello rojo) no se pueden interrumpir, ¡pero puedes esquivarlos saliendo del área!")
	_make_zone("boss", 132.0, 2.0)


func _tutorial_zone(x: float, y: float, title: String, text: String) -> void:
	# Trigger que muestra un mensaje en el panel de tutorial (izquierda) al entrar.
	var area := Area3D.new()
	area.position = Vector3(x, y + 1.2, 0)
	add_child(area)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, (HW + 0.5) * 2)
	col.shape = box
	area.add_child(col)
	area.collision_mask = 2
	area.body_entered.connect(_on_tutorial_zone.bind(title, text))


func _on_tutorial_zone(body: Node3D, title: String, text: String) -> void:
	# Solo el personaje CONTROLADO cambia el mensaje (no el aliado que sigue detras).
	if body != _active_char:
		return
	_hud_tutorial_bg.visible = true
	_hud_tutorial_title.visible = true
	_hud_tutorial.visible = true
	_hud_tutorial_title.text = title
	_hud_tutorial.text = text


func _floor_arrow(pos: Vector3, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.5, 0.06, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.25)
	mat.emission_energy_multiplier = 0.6
	mi.mesh = pm
	mi.material_override = mat
	mi.rotation_degrees = Vector3(0, yaw, 0)
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.05, 0)


func _floor_arrows(center: Vector3) -> void:
	_floor_arrow(center + Vector3(0, 0, -1.0), 0.0)     # adelante (+X? el prism apunta +Z)
	_floor_arrow(center + Vector3(0, 0, 1.0), 180.0)
	_floor_arrow(center + Vector3(-1.0, 0, 0), 90.0)
	_floor_arrow(center + Vector3(1.0, 0, 0), 270.0)


func _make_platform(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	add_child(body)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.42, 0.28)
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(col)


func _make_water(center: Vector3, size: Vector3) -> void:
	_water_surface_y = center.y + size.y * 0.5
	var area := Area3D.new()
	area.position = center
	add_child(area)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	area.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.4, 0.75, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.mesh = bm
	mi.material_override = mat
	area.add_child(mi)
	area.collision_mask = 2
	area.body_entered.connect(_on_water_entered)
	area.body_exited.connect(_on_water_exited)


func _make_zone(id: String, x: float, y: float) -> void:
	var area := Area3D.new()
	area.position = Vector3(x, y + 1.2, 0)
	add_child(area)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 3.0, (HW + 0.5) * 2)
	col.shape = box
	area.add_child(col)
	area.collision_mask = 2
	area.body_entered.connect(_on_zone_entered.bind(id))


func _on_zone_entered(body: Node3D, id: String) -> void:
	if not body.is_in_group("player") or _zones.has(id):
		return
	_zones[id] = true
	match id:
		"combat1":
			_spawn_group(Vector3(42, 0, 0), 3, [0, 1, 1])
		"combat2":
			_spawn_group(Vector3(106, 2, 0), 12, [0, 1, 3, 0, 1, 2])
		"boss":
			_start_tutorial_boss()


func _spawn_group(center: Vector3, count: int, kinds: Array) -> void:
	for i in count:
		var off := Vector3(randf_range(-2.0, 9.0), 0.0, randf_range(-3.5, 3.5))
		_spawn_enemy_at(center + off, kinds[i % kinds.size()])


func _spawn_enemy_at(pos: Vector3, kind_index: int) -> void:
	# Instancia la escena-plantilla del tipo (sus stats se editan en el editor).
	var e: CharacterBody3D = KIND_SCENES[kind_index].instantiate()
	e.position = pos + Vector3(0, 0.2, 0)
	e.died.connect(_on_enemy_died)
	add_child(e)
	e.setup(_player)


func _start_tutorial_boss() -> void:
	# Instancia la escena del jefe (editable en scenes/enemies/BossGuardian.tscn).
	var e: CharacterBody3D = BOSS_GUARDIAN.instantiate()
	e.position = Vector3(145, 2.2, 0)
	e.died.connect(_on_enemy_died)
	add_child(e)
	e.setup(_player)
	_boss = e
	_tutorial_boss = e
	_boss_started = true


func _next_wave() -> void:
	_wave += 1
	Save.record_wave(_wave)
	_between_waves = false
	_banner_timer = 2.4
	_hud_next.visible = false
	if _wave % 3 == 0:
		_spawn_boss()
		for i in (2 + int(_wave / 2.0)):
			_spawn_enemy()
	else:
		for i in (3 + _wave):
			_spawn_enemy()


func _spawn_boss() -> void:
	var kind := (int(_wave / 3.0) + 1) % 2  # alterna: Embestidor, Aplastador, ...
	var e := CharacterBody3D.new()
	e.set_script(ENEMY_SCRIPT)
	e.is_boss = true
	e.boss_kind = kind
	if kind == 0:
		e.boss_name = "EMBESTIDOR"
		e.base_color = Color(0.35, 0.10, 0.45)
		e.max_health = 300.0 + _wave * 60.0
		e.scale_factor = 2.6
		e.damage = 28.0
	else:
		e.boss_name = "APLASTADOR"
		e.base_color = Color(0.55, 0.20, 0.10)
		e.max_health = 380.0 + _wave * 70.0
		e.scale_factor = 3.0
		e.damage = 32.0
	e.speed = 1.7
	e.attack_range = 2.6
	e.burn_dps = 16.0
	e.windup_time = 1.0
	e.position = _find_spawn_pos() + Vector3(0, 0.3, 0)
	e.died.connect(_on_enemy_died)
	add_child(e)
	e.setup(_player)
	_boss = e


func _spawn_enemy() -> void:
	var pos := _find_spawn_pos()
	var cfg: Dictionary = KINDS[_pick_kind()]
	var e := CharacterBody3D.new()
	e.set_script(ENEMY_SCRIPT)
	e.base_color = cfg["color"]
	e.max_health = float(cfg["hp"]) + _wave * 5.0
	e.speed = cfg["speed"]
	e.damage = cfg["dmg"]
	e.attack_range = cfg["range"]
	e.scale_factor = cfg["scale"]
	e.windup_time = cfg["windup"]
	e.ranged = cfg.get("ranged", false)
	e.position = pos + Vector3(0, 0.2, 0)
	e.died.connect(_on_enemy_died)
	add_child(e)
	e.setup(_player)


func _pick_kind() -> int:
	var r := randf()
	if _wave >= 3 and r < 0.15:
		return 2  # grande
	elif _wave >= 2 and r < 0.35:
		return 3  # lanzador (a distancia)
	elif r < 0.55:
		return 1  # rapido
	return 0  # normal


func _find_spawn_pos() -> Vector3:
	for _try in 20:
		var x := randf_range(-ARENA + 3.0, ARENA - 3.0)
		var z := randf_range(-ARENA + 3.0, ARENA - 3.0)
		var p := Vector3(x, 0.0, z)
		if p.distance_to(_player.global_position) < 8.0:
			continue
		if x > 7.0 and absf(z) < 7.0:  # zona de agua
			continue
		return p
	return Vector3(-15.0, 0.0, randf_range(-15.0, 15.0))


func _on_enemy_died(pos: Vector3, xp: int) -> void:
	_score += 1
	_add_xp(xp)
	# Orbes: de vida (verde) y de energia (azul).
	if randf() < 0.30:
		_spawn_pickup(pos + Vector3(-0.4, 0, 0), "health")
	if randf() < 0.32:
		_spawn_pickup(pos + Vector3(0.4, 0, 0), "energy")


func _spawn_pickup(pos: Vector3, kind: String) -> void:
	var p := Area3D.new()
	p.set_script(PICKUP_SCRIPT)
	p.kind = kind  # se lee en _ready, por eso antes de add_child
	p.position = Vector3(pos.x, 0.0, pos.z)
	add_child(p)


func _xp_needed() -> int:
	return _level * 140


func _add_xp(amount: int) -> void:
	_xp += amount
	while _xp >= _xp_needed():
		_xp -= _xp_needed()
		_level += 1
		_on_level_up()


func _on_level_up() -> void:
	_levelup_timer = 3.0
	var mult := 1.0 + (_level - 1) * 0.12
	for c in _chars:
		if is_instance_valid(c):
			c.set_power(mult)
	# Los poderes los entregan los NPCs del tutorial; el nivel solo da potencia.
	var msg := "¡NIVEL %d!   Potencia +%d%%" % [_level, int(round((mult - 1.0) * 100.0))]
	if _hud_levelup != null:
		_hud_levelup.text = msg
	Sfx.play("jump", -2.0, 1.4)


func _setup_npcs() -> void:
	_make_npc(Vector3(-15.0, 0.0, -14.0), "Aldeano", Color(0.30, 0.70, 0.90),
		"¡Cuidado, Emilia! No dejan de venir. Corre y usa Shift+Clic para la patada voladora.",
		"")
	_make_npc(Vector3(15.0, 0.0, -14.0), "Entrenadora", Color(0.90, 0.55, 0.25),
		"Emilia: DOBLE SALTO con ALAS (Espacio en el aire). Benja: GUANACO (Q invoca, Q otra vez embiste, E monta). Gastan energia (SP).",
		"trainer")
	_make_npc(Vector3(-15.0, 0.0, 14.0), "Mercader", Color(0.55, 0.80, 0.40),
		"Orbes VERDES curan, orbes AZULES recargan energia. Sube de NIVEL matando enemigos para potenciar y desbloquear habilidades.",
		"")
	_make_npc(Vector3(15.0, 0.0, 14.0), "Hechicera", Color(0.85, 0.30, 0.55),
		"Emilia: PUNOS DE FUEGO (G para activar, gasta SP) y mas adelante LAVA. Benja: ENREDADERAS (F) que ralentizan.",
		"mage")


func _make_npc(pos: Vector3, npc_name: String, color: Color, dialogue: String, grant: String) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.mesh = cap
	mi.material_override = mat
	mi.position = Vector3(0, 0.85, 0)
	body.add_child(mi)
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.05, 0.05, 0.05)
	for sx in [-0.13, 0.13]:
		var eye := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.07
		s.height = 0.14
		eye.mesh = s
		eye.material_override = em
		eye.position = Vector3(sx, 1.3, 0.34)
		body.add_child(eye)
	var lbl := Label3D.new()
	lbl.text = npc_name
	lbl.position = Vector3(0, 2.2, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 8
	lbl.pixel_size = 0.008
	body.add_child(lbl)
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.4
	cs.height = 1.6
	col.shape = cs
	col.position = Vector3(0, 0.85, 0)
	body.add_child(col)
	_npcs.append({"node": body, "name": npc_name, "dialogue": dialogue, "grant": grant})


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# Panel de tutorial a la izquierda.
	_hud_tutorial_bg = ColorRect.new()
	_hud_tutorial_bg.color = Color(0.03, 0.05, 0.10, 0.72)
	_hud_tutorial_bg.position = Vector2(16, 120)
	_hud_tutorial_bg.size = Vector2(360, 250)
	_hud_tutorial_bg.visible = false
	layer.add_child(_hud_tutorial_bg)
	_hud_tutorial_title = Label.new()
	_hud_tutorial_title.position = Vector2(30, 130)
	_hud_tutorial_title.size = Vector2(332, 26)
	_hud_tutorial_title.add_theme_font_size_override("font_size", 20)
	_style_label(_hud_tutorial_title, 5, Color(1.0, 0.9, 0.45))
	_hud_tutorial_title.text = "TUTORIAL"
	_hud_tutorial_title.visible = false
	layer.add_child(_hud_tutorial_title)
	_hud_tutorial = Label.new()
	_hud_tutorial.position = Vector2(30, 162)
	_hud_tutorial.size = Vector2(332, 198)
	_hud_tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_hud_tutorial, 4, Color(0.95, 0.97, 1.0))
	_hud_tutorial.visible = false
	layer.add_child(_hud_tutorial)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.position = Vector2(20, 20)
	bg.size = Vector2(264, 18)
	layer.add_child(bg)
	_hud_hp_fill = ColorRect.new()
	_hud_hp_fill.color = Color(0.25, 0.8, 0.35)
	_hud_hp_fill.position = Vector2(22, 22)
	_hud_hp_fill.size = Vector2(260, 16)
	layer.add_child(_hud_hp_fill)
	# Barra de energia (SP), azul, debajo de la vida.
	var sp_bg := ColorRect.new()
	sp_bg.color = Color(0, 0, 0, 0.55)
	sp_bg.position = Vector2(20, 40)
	sp_bg.size = Vector2(264, 14)
	layer.add_child(sp_bg)
	_hud_sp_fill = ColorRect.new()
	_hud_sp_fill.color = Color(0.35, 0.65, 1.0)
	_hud_sp_fill.position = Vector2(22, 42)
	_hud_sp_fill.size = Vector2(260, 10)
	layer.add_child(_hud_sp_fill)
	_hud_label = Label.new()
	_hud_label.position = Vector2(22, 58)
	_style_label(_hud_label, 4)
	layer.add_child(_hud_label)
	# Cartel de subida de nivel (centro-arriba)
	_hud_levelup = Label.new()
	_hud_levelup.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_levelup.position.y = 130
	_hud_levelup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_levelup.add_theme_font_size_override("font_size", 30)
	_style_label(_hud_levelup, 8, Color(1.0, 0.9, 0.4))
	_hud_levelup.visible = false
	layer.add_child(_hud_levelup)
	# Cartel de oleada (centrado arriba)
	_hud_banner = Label.new()
	_hud_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_banner.position.y = 70
	_hud_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_banner.add_theme_font_size_override("font_size", 44)
	_style_label(_hud_banner, 8, Color(1.0, 0.95, 0.5))
	_hud_banner.visible = false
	layer.add_child(_hud_banner)
	# Dialogo del NPC (abajo)
	_hud_dialogue = Label.new()
	_hud_dialogue.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_dialogue.position.y = 560
	_hud_dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_hud_dialogue, 6)
	_hud_dialogue.visible = false
	layer.add_child(_hud_dialogue)
	# Pista de interaccion
	_hud_hint = Label.new()
	_hud_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_hint.position.y = 610
	_hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_hud_hint, 5, Color(0.85, 0.95, 1.0))
	_hud_hint.visible = false
	layer.add_child(_hud_hint)
	# Aviso entre oleadas (centro)
	_hud_next = Label.new()
	_hud_next.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_next.position.y = 300
	_hud_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_next.add_theme_font_size_override("font_size", 30)
	_style_label(_hud_next, 7, Color(0.6, 1.0, 0.7))
	_hud_next.visible = false
	layer.add_child(_hud_next)
	# Barra de vida del jefe (centro-arriba)
	_hud_boss_bg = ColorRect.new()
	_set_centered(_hud_boss_bg, -210, 210, 44, 70)
	_hud_boss_bg.color = Color(0, 0, 0, 0.6)
	_hud_boss_bg.visible = false
	layer.add_child(_hud_boss_bg)
	_hud_boss_fill = ColorRect.new()
	_set_centered(_hud_boss_fill, -206, 206, 46, 68)
	_hud_boss_fill.color = Color(0.8, 0.2, 0.25)
	_hud_boss_fill.visible = false
	layer.add_child(_hud_boss_fill)
	_hud_boss_label = Label.new()
	_hud_boss_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_boss_label.position.y = 16
	_hud_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_hud_boss_label, 5, Color(1.0, 0.5, 0.4))
	_hud_boss_label.visible = false
	layer.add_child(_hud_boss_label)
	# Cartel de derrota (centro)
	_hud_defeat = Label.new()
	_hud_defeat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_defeat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_defeat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_defeat.add_theme_font_size_override("font_size", 52)
	_style_label(_hud_defeat, 10, Color(1.0, 0.35, 0.35))
	_hud_defeat.visible = false
	layer.add_child(_hud_defeat)
	# Cartel de victoria
	_hud_victory = Label.new()
	_hud_victory.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_victory.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_victory.add_theme_font_size_override("font_size", 52)
	_style_label(_hud_victory, 10, Color(0.6, 1.0, 0.55))
	_hud_victory.visible = false
	layer.add_child(_hud_victory)


func _set_centered(c: Control, off_l: float, off_r: float, off_t: float, off_b: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = off_l
	c.offset_right = off_r
	c.offset_top = off_t
	c.offset_bottom = off_b


func _style_label(l: Label, outline: int, col: Color = Color.WHITE) -> void:
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)


func _update_hud() -> void:
	if _hud_hp_fill == null or not is_instance_valid(_active_char):
		return
	var f: float = clampf(_active_char.health / _active_char.max_health, 0.0, 1.0)
	_hud_hp_fill.size.x = 260.0 * f
	_hud_hp_fill.color = Color(0.85, 0.3, 0.3) if f < 0.3 else Color(0.25, 0.8, 0.35)
	var ef: float = clampf(_active_char.energy / _active_char.max_energy, 0.0, 1.0)
	_hud_sp_fill.size.x = 260.0 * ef
	var is_emilia := _active_char == _player
	var who := "Emilia" if is_emilia else "Benja"
	var alive := get_tree().get_nodes_in_group("enemies").size()
	_hud_label.text = "%s   Vida %d   SP %d   Nivel %d (%d/%d)   Enemigos: %d   [R cambia personaje]" % [who, int(_active_char.health), int(_active_char.energy), _level, _xp, _xp_needed(), alive]


func _setup_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)
	_cam.global_position = _active_char.global_position + _compute_offset()
	_cam.look_at(_active_char.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_cam.current = true


func _compute_offset() -> Vector3:
	var yaw_r := deg_to_rad(_yaw)
	var pitch_r := deg_to_rad(_pitch)
	var horizontal := _distance * cos(pitch_r)
	var y := _distance * sin(pitch_r)
	return Vector3(sin(yaw_r) * horizontal, y, cos(yaw_r) * horizontal)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_rotating = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_distance = clampf(_distance - zoom_speed, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_distance = clampf(_distance + zoom_speed, min_distance, max_distance)
	elif event is InputEventMouseMotion and _rotating:
		var mm := event as InputEventMouseMotion
		_yaw = wrapf(_yaw - mm.relative.x * orbit_sensitivity, 0.0, 360.0)
		_pitch = clampf(_pitch + mm.relative.y * orbit_sensitivity, min_pitch, max_pitch)


func _process(delta: float) -> void:
	# Si la escena se esta recargando (R), Main y sus hijos salen del arbol:
	# acceder a global_transform de cualquiera de ellos falla. Salimos.
	if not is_inside_tree() or _cam == null or _player == null:
		return
	if not is_instance_valid(_active_char) or not _active_char.is_inside_tree():
		return
	# Camara con stick derecho del mando.
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(rx) > 0.2:
		_yaw = wrapf(_yaw - rx * 140.0 * delta, 0.0, 360.0)
	if absf(ry) > 0.2:
		_pitch = clampf(_pitch + ry * 90.0 * delta, min_pitch, max_pitch)

	# Cambio de personaje con R (o si el activo muere, pasa al vivo).
	var rk := Input.is_physical_key_pressed(KEY_R) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_STICK)
	var r_just := rk and not _r_prev
	_r_prev = rk
	if is_instance_valid(_active_char) and _active_char.is_dead() and not _all_dead():
		_swap_char()
	elif r_just and not _won and not _all_dead():
		_swap_char()

	# Camara y control relativos al personaje ACTIVO.
	_active_char.cam_yaw_deg = _yaw
	var target := _active_char.global_position + _compute_offset()
	_cam.global_position = _cam.global_position.lerp(target, cam_follow_speed * delta)
	_cam.look_at(_active_char.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)

	_update_hud()

	# Impulso: Benja activo, cerca del desnivel y de Emilia (arriba) -> pulsa T y sube.
	var t_now := Input.is_physical_key_pressed(KEY_T)
	var t_just := t_now and not _t_prev_main
	_t_prev_main = t_now
	var ledge_hint := ""
	if _active_char == _benja and is_instance_valid(_benja) and is_instance_valid(_player):
		var at_ledge: bool = absf(_benja.global_position.x - _ledge_top.x) < 3.5 and _benja.global_position.y < 1.2
		var emilia_up: bool = _player.global_position.y > _ledge_top.y - 0.6
		var emilia_near: bool = Vector2(_player.global_position.x - _benja.global_position.x, _player.global_position.z - _benja.global_position.z).length() < 6.0
		if at_ledge and emilia_up and emilia_near:
			ledge_hint = "Pulsa T: Emilia te impulsa arriba"
			if t_just:
				_benja.boost_up(Vector3(_ledge_top.x + 1.6, _ledge_top.y + 0.1, _player.global_position.z))

	# Objetivo del tutorial: derrotar al jefe final.
	if _boss_started and not is_instance_valid(_tutorial_boss):
		_won = true
	if _won:
		_hud_victory.visible = true
		_hud_victory.text = "¡TUTORIAL COMPLETADO!\nDerrotaste al Guardian\n\nPulsa  R  para reiniciar"
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
			return
	else:
		_hud_victory.visible = false

	# Cartel de subida de nivel
	if _levelup_timer > 0.0:
		_levelup_timer -= delta
		_hud_levelup.visible = true
		_hud_levelup.modulate.a = clampf(_levelup_timer, 0.0, 1.0)
	else:
		_hud_levelup.visible = false

	# NPCs: pista, dialogo y (entrenadora) desbloqueo del doble salto
	var near = null
	for npc in _npcs:
		if _active_char.global_position.distance_to(npc["node"].global_position) < 3.3:
			near = npc
			break
	if ledge_hint != "":
		_hud_hint.visible = true
		_hud_hint.text = ledge_hint
	else:
		_hud_hint.visible = near != null and not _active_char.is_talking()
		if near != null:
			_hud_hint.text = "Pulsa T para hablar con %s" % near["name"]
	if near != null and _active_char.is_talking():
		_hud_dialogue.visible = true
		var extra := ""
		var g: String = near["grant"]
		var is_emilia := _active_char == _player
		if g == "trainer":
			if is_emilia:
				_active_char.grant_double_jump()
				extra = "   [DOBLE SALTO desbloqueado]"
			else:
				_active_char.grant_guanaco()
				extra = "   [GUANACO - Q invoca, Q embiste, E monta]"
		elif g == "master":
			if is_emilia:
				_active_char.grant_fire()
				_active_char.unlock("lava")
				extra = "   [FUEGO (G) + LAVA (F)]"
			else:
				_active_char.grant_vines()
				_active_char.unlock("triple")
				_active_char.unlock("stampede")
				extra = "   [ENREDADERAS (F) + FLECHA TRIPLE (G) + ESTAMPIDA]"
		# "basics": solo tutorial, sin poder nuevo (ambos ya pueden atacar).
		_hud_dialogue.text = "%s: %s%s" % [near["name"], near["dialogue"], extra]
	else:
		_hud_dialogue.visible = false

	# Barra de vida del jefe
	var boss_alive := is_instance_valid(_boss)
	_hud_boss_bg.visible = boss_alive
	_hud_boss_fill.visible = boss_alive
	_hud_boss_label.visible = boss_alive
	if boss_alive:
		var bf: float = clampf(_boss.health / _boss.max_health, 0.0, 1.0)
		_hud_boss_fill.offset_right = -206.0 + 412.0 * bf
		_hud_boss_label.text = "◆ %s ◆" % _boss.boss_name
	else:
		_boss = null

	# Derrota / reinicio (cuando TODOS los personajes caen)
	if _all_dead():
		_hud_defeat.visible = true
		_hud_defeat.text = "HAS CAIDO\n\nPulsa  R  para reiniciar"
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
			return
	else:
		_hud_defeat.visible = false


func _run_orbit_demo() -> void:
	await get_tree().create_timer(0.8).timeout
	_screenshot("user://emilia_cam_a.png")
	# Orbitar 110 grados como si se arrastrara el raton.
	var start := _yaw
	for i in 60:
		_yaw = wrapf(start - float(i + 1) * (110.0 / 60.0), 0.0, 360.0)
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	_screenshot("user://emilia_cam_b.png")


func _run_shot_burst() -> void:
	# El combo arranca ~1.0s (debug_auto_combo). Capturamos varias fases.
	var times := [0.5, 1.0, 1.5, 2.0, 2.5]
	var prev := 0.0
	for i in times.size():
		await get_tree().create_timer(times[i] - prev).timeout
		prev = times[i]
		_screenshot("user://combo_%d.png" % (i + 1))


func _screenshot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Screenshot: ", ProjectSettings.globalize_path(path))
