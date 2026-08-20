extends Node3D

## Zona Mina Corrupta — 4 secciones + persecución del Chupacabras.
##
## S1 (Z=0→-15): entrada, viga baja + pilar
## S2 (Z=-15→-38): sala de combate, 5 mineros normales
## S3 (Z=-38→-56): pasillo de garras, diálogo y sonido inquietante
## S4 (Z=-59→-76): cámara del nido, Chupacabras a 8.5 m/s
##
## Durante la huida: 8 mineros normales + 4 bloques de derrumbe del techo.

const ENEMY_NORMAL    := preload("res://scenes/enemies/EnemyNormal.tscn")
const BALLOON         := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"
const TALISMAN_SCR    := preload("res://scenes/actors/TalismanFragment.gd")

const DIALOGUE_GARRAS := "~ start
Emilia: ¿Escuchaste eso?
Benjamín: Sí... ¿Y esas marcas en las paredes? Son garras.
Emilia: Sea lo que sea, está muy cerca.
=> END
"

@export var miner_color := Color(0.80, 0.15, 0.10)
@export var chupa_color := Color(0.07, 0.02, 0.14)

var _combat_cleared := false
var _claw_fired     := false
var _chase_active   := false
var _chupacabras: CharacterBody3D = null
var _chupa_vel      := Vector3.ZERO
var _stall_z        := 0.0
var _stall_frames   := 0
var _forced_players: Array = []
var _alive          := 0
var _chupa_hit_cd   := 0.0


func _ready() -> void:
	_build_cave()
	_setup_triggers()
	_spawn_talisman()


func _spawn_talisman() -> void:
	if GameManager.has_ability("talisman_frag_1"):
		return   # ya fue recogido en una sesión anterior
	var t := Area3D.new()
	t.set_script(TALISMAN_SCR)
	t.position = Vector3(0.0, 1.2, -44.0)   # S3, centro del pasillo de garras
	add_child(t)


func _process(delta: float) -> void:
	if not _chase_active:
		return
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get("active") == true:
			if p.global_position.z > -2.0:
				_stop_chase()
				return
	if is_instance_valid(_chupacabras):
		_move_chupacabras(delta)
		_check_chupa_hit(delta)


# ─── Triggers dinámicos ───────────────────────────────────────────────────────

func _setup_triggers() -> void:
	_make_trigger(Vector3(0.0, 2.0, -17.0), Vector3(14.0, 5.0,  4.0), _on_combat_enter)
	_make_trigger(Vector3(0.0, 2.0, -47.0), Vector3( 6.0, 4.0,  6.0), _on_claw_enter)
	_make_trigger(Vector3(0.0, 1.5, -60.0), Vector3(17.0, 8.0,  4.0), _on_nest_enter)


func _make_trigger(pos: Vector3, size: Vector3, callback: Callable) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask  = 2
	area.body_entered.connect(callback)
	add_child(area)
	area.global_position = pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	area.add_child(cs)


# ─── Combate (S2) ─────────────────────────────────────────────────────────────

func _on_combat_enter(body: Node3D) -> void:
	if body.is_in_group("player") and not _combat_cleared:
		_start_combat()


func _start_combat() -> void:
	_banner("¡Mineros corruptos en la mina!")
	var spawns: Array[Vector3] = [
		Vector3(-4.0, 0.5, -19.0),
		Vector3( 5.0, 0.5, -23.0),
		Vector3(-3.0, 0.5, -28.0),
		Vector3( 4.5, 0.5, -32.0),
		Vector3( 0.0, 0.5, -36.0),
	]
	_alive = spawns.size()
	for pos in spawns:
		var e: CharacterBody3D = ENEMY_NORMAL.instantiate()
		e.base_color = miner_color
		e.died.connect(_on_miner_died)
		add_child(e)
		e.global_position = pos


func _on_miner_died(_pos: Vector3, _xp: int) -> void:
	_alive -= 1
	if _alive <= 0:
		_combat_cleared = true
		_banner("Sector despejado… hay algo más abajo.", 3.0)
		if GameManager.get_beat() < 3:
			GameManager.set_beat(3)


# ─── Pasillo de Garras (S3) ───────────────────────────────────────────────────

func _on_claw_enter(body: Node3D) -> void:
	if body.is_in_group("player") and _combat_cleared and not _claw_fired:
		_trigger_claw_dialogue()


func _trigger_claw_dialogue() -> void:
	_claw_fired = true
	Sfx.play("boss", -4.0, 0.30)
	var res := DialogueManager.create_resource_from_text(DIALOGUE_GARRAS)
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


# ─── Nido / Persecución (S4) ──────────────────────────────────────────────────

func _on_nest_enter(body: Node3D) -> void:
	if body.is_in_group("player") and _combat_cleared and not _chase_active:
		_start_chase()


func _start_chase() -> void:
	_chase_active = true
	_banner("¡HUYE!")
	Sfx.play("boss", 3.0, 0.55)

	var c := CharacterBody3D.new()
	c.collision_layer = 4
	c.collision_mask  = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = chupa_color
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.65
	cm.height = 2.4
	mi.mesh = cm
	mi.position.y = 1.2
	mi.set_surface_override_material(0, mat)
	c.add_child(mi)

	var lbl := Label3D.new()
	lbl.text = "CHUPACABRAS"
	lbl.position.y = 3.0
	lbl.pixel_size = 0.009
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.9, 0.3, 1.0, 1)
	lbl.font_size = 22
	lbl.outline_size = 8
	c.add_child(lbl)

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.62
	cap.height = 1.3
	cs.shape = cap
	cs.position.y = 1.2
	c.add_child(cs)

	add_child(c)
	c.global_position = Vector3(0.0, -1.5, -70.0)
	_chupacabras = c
	_chupa_vel   = Vector3.ZERO
	_stall_z     = c.global_position.z
	_stall_frames = 0

	# 8 mineros de escape (solo normales, unkillable)
	var escape_pos: Array[Vector3] = [
		Vector3( 2.5, 0.5, -52.0),
		Vector3(-2.0, 0.5, -46.0),
		Vector3( 3.0, 0.5, -39.0),
		Vector3(-3.5, 0.5, -31.0),
		Vector3( 2.0, 0.5, -24.0),
		Vector3(-2.5, 0.5, -17.0),
		Vector3( 1.5, 0.5, -10.0),
		Vector3(-1.5, 0.5,  -5.0),
	]
	for pos in escape_pos:
		var m: CharacterBody3D = ENEMY_NORMAL.instantiate()
		m.base_color = miner_color
		m.speed      = 1.5
		m.max_health = 999.0
		add_child(m)
		m.global_position = pos
		m.remove_from_group("enemies")  # el compañero no los ataca durante la huida

	# Bloques de derrumbe del techo (staggered)
	var debris_z  := [-45.0, -35.0, -24.0, -10.0]
	var delays    := [ 1.5,   3.5,   5.5,   7.0]
	for i in debris_z.size():
		get_tree().create_timer(delays[i]).timeout.connect(
			func() -> void: _spawn_debris(debris_z[i]))

	# Forzar huida en +Z — el activo arranca de inmediato, el compañero 0.6s después
	# para que el jugador lidere la salida y se vean correr juntos.
	for p in get_tree().get_nodes_in_group("player"):
		if "forced_run_dir" in p:
			_forced_players.append(p)
			if p.get("active") == true:
				p.forced_run_dir = Vector3(0.0, 0.0, 1.0)
			else:
				get_tree().create_timer(0.6).timeout.connect(
					func() -> void:
						if is_instance_valid(p) and "forced_run_dir" in p:
							p.forced_run_dir = Vector3(0.0, 0.0, 1.0))


func _spawn_debris(z: float) -> void:
	if not _chase_active:
		return
	var body := RigidBody3D.new()
	body.collision_layer = 1
	body.collision_mask  = 1
	body.contact_monitor = true
	body.max_contacts_reported = 2
	add_child(body)
	body.global_position = Vector3(0.0, 5.0, z)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.6, 1.4)
	cs.shape = box
	body.add_child(cs)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 0.6, 1.4)
	mi.mesh = bm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.27, 0.20, 0.15)
	mi.set_surface_override_material(0, dmat)
	body.add_child(mi)

	# Zona de daño para jugadores
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask  = 2
	body.add_child(area)
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(1.6, 0.8, 1.6)
	acs.shape = abox
	area.add_child(acs)
	area.body_entered.connect(func(hit: Node3D) -> void:
		if hit.is_in_group("player") and hit.has_method("take_damage"):
			hit.take_damage(20))


func _move_chupacabras(delta: float) -> void:
	var c := _chupacabras
	if not is_instance_valid(c):
		return

	_chupa_vel.x = 0.0
	_chupa_vel.z = 8.0

	if c.is_on_floor():
		if _chupa_vel.y < 0.0:
			_chupa_vel.y = 0.0
	else:
		_chupa_vel.y -= 22.0 * delta

	if c.is_on_floor():
		var should_jump := false
		var space := c.get_world_3d().direct_space_state
		for ry in [0.15, 0.5, 0.9]:
			var origin := c.global_position + Vector3(0.0, ry, 0.0)
			var fwd    := origin + Vector3(0.0, 0.0, 1.4)
			var params := PhysicsRayQueryParameters3D.create(origin, fwd)
			params.collision_mask = 1
			params.exclude = [c.get_rid()]
			if not space.intersect_ray(params).is_empty():
				should_jump = true
				break
		if absf(c.global_position.z - _stall_z) < 0.06:
			_stall_frames += 1
			if _stall_frames >= 8:
				should_jump = true
				_stall_frames = 0
		else:
			_stall_z = c.global_position.z
			_stall_frames = 0

		if should_jump:
			_chupa_vel.y = 9.5

	c.velocity = _chupa_vel
	c.move_and_slide()


func _check_chupa_hit(delta: float) -> void:
	_chupa_hit_cd = max(0.0, _chupa_hit_cd - delta)
	if not is_instance_valid(_chupacabras) or _chupa_hit_cd > 0.0:
		return
	var cpos := _chupacabras.global_position
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		if cpos.distance_to(p.global_position) < 2.0:
			_chupa_hit_cd = 999.0   # evitar múltiples triggers
			_banner("¡El Chupacabras te atrapó!")
			# Matar a ambos jugadores → game over
			for pp in get_tree().get_nodes_in_group("player"):
				if is_instance_valid(pp) and pp.has_method("take_damage"):
					pp.take_damage(9999.0)
			get_tree().create_timer(2.0).timeout.connect(
				func() -> void: get_tree().reload_current_scene())
			return


func _stop_chase() -> void:
	if not _chase_active:
		return
	_chase_active = false
	for p in _forced_players:
		if not is_instance_valid(p) or not ("forced_run_dir" in p):
			continue
		if p.get("active") == true:
			p.forced_run_dir = Vector3.ZERO
		else:
			# El compañero puede estar a pocos metros de la salida — lo dejamos correr
			# 2 s más para que salga antes de que su IA de combate tome el control.
			get_tree().create_timer(2.0).timeout.connect(
				func() -> void:
					if is_instance_valid(p) and "forced_run_dir" in p:
						p.forced_run_dir = Vector3.ZERO)
	_forced_players.clear()
	if is_instance_valid(_chupacabras):
		_chupacabras.queue_free()
		_chupacabras = null
	_banner("El Chupacabras se esconde en las sombras… La salida está cerca.", 4.0)


# ─── Geometría CSG ───────────────────────────────────────────────────────────
#
# Eje Z: Z=0 boca de la cueva, interior hacia Z negativo.
#
# S1 Entrada       Z= 0 → -15   ancho 7m   alto 4m
# S2 Combate       Z=-15 → -38   ancho 13m  alto 5m
# S3 Garras        Z=-38 → -56   ancho 5m   alto 4m
# Rampa            Z=-56 → -59   descenso a Y=-2
# S4 Nido          Z=-59 → -76   ancho 16m  alto 7m (piso Y=-2)

func _build_cave() -> void:
	var rock := _mat(Color(0.27, 0.20, 0.15))
	var dark := _mat(Color(0.15, 0.11, 0.08))

	# ── Plataforma exterior (Z = -2 a +13) ───────────────────────────────────
	_box(Vector3(0.0, -0.5, 5.5), Vector3(14.0, 1.0, 15.0), rock)
	_ceil( 0.0, 4.5,  5.5, 14.0, 15.0, rock)
	_box(Vector3( 0.0, 2.5, 13.5), Vector3(14.0, 6.0, 1.0), rock)
	_box(Vector3(-7.0, 2.5,  5.5), Vector3(1.0,  6.0, 16.0), rock)
	_box(Vector3( 7.0, 2.5,  5.5), Vector3(1.0,  6.0, 16.0), rock)

	# ── Dintel / boca de la cueva (Z ≈ 0) ───────────────────────────────────
	_box(Vector3( 0.0, 3.8,  1.0), Vector3(9.0, 2.4, 2.2), rock)
	_box(Vector3(-5.0, 1.5,  1.0), Vector3(3.0, 4.0, 2.2), rock)
	_box(Vector3( 5.0, 1.5,  1.0), Vector3(3.0, 4.0, 2.2), rock)
	_box(Vector3(-5.0, 4.1,  1.0), Vector3(3.0, 1.2, 2.2), rock)
	_box(Vector3( 5.0, 4.1,  1.0), Vector3(3.0, 1.2, 2.2), rock)

	# ── S1 Entrada (Z=0 → -15, ancho 7, alto 4) ──────────────────────────
	_floor( 0.0, 0.0, -7.5,  7.0, 15.0, rock)
	_ceil(  0.0, 4.0, -7.5,  7.0, 15.0, rock)
	_wall(-3.5, 2.0,  -7.5, 15.0, rock)
	_wall( 3.5, 2.0,  -7.5, 15.0, rock)

	# S1 obstáculos de entrada
	# Viga baja Z=-7: saltar (borde inferior Y=0, tope Y=1.1)
	_box(Vector3(0.0, 0.55, -7.0), Vector3(7.0, 1.1, 1.4), rock)
	# Pilar derecho Z=-12: esquivar por la izquierda
	_box(Vector3(2.0, 1.8, -12.0), Vector3(2.5, 3.6, 1.6), rock)

	# ── Transición S1→S2 (rellena jambas del ensanche) ───────────────────
	_box(Vector3(-5.0, 2.5, -15.5), Vector3(4.0, 6.0, 2.0), rock)
	_box(Vector3( 5.0, 2.5, -15.5), Vector3(4.0, 6.0, 2.0), rock)

	# ── S2 Sala de combate (Z=-15 → -38, ancho 13, alto 5) ───────────────
	_floor( 0.0, 0.0, -26.5, 13.0, 23.0, rock)
	_ceil(  0.0, 5.0, -26.5, 13.0, 23.0, rock)
	_wall(-6.5, 2.5,  -26.5, 23.0, rock)
	_wall( 6.5, 2.5,  -26.5, 23.0, rock)

	# Columnas de cobertura en S2
	_box(Vector3(-4.0, 2.0, -22.0), Vector3(1.5, 4.5, 1.5), rock)
	_box(Vector3( 4.0, 2.0, -31.0), Vector3(1.5, 4.5, 1.5), rock)

	# ── Transición S2→S3 (estrecha de 13m a 5m) ──────────────────────────
	_box(Vector3(-4.5, 2.5, -39.0), Vector3(4.0, 6.0, 3.0), rock)
	_box(Vector3( 4.5, 2.5, -39.0), Vector3(4.0, 6.0, 3.0), rock)

	# ── S3 Pasillo de garras (Z=-38 → -56, ancho 5, alto 4) ──────────────
	_floor( 0.0, 0.0, -47.0, 5.0, 18.0, rock)
	_ceil(  0.0, 4.0, -47.0, 5.0, 18.0, rock)
	_wall(-2.5, 2.0,  -47.0, 18.0, rock)
	_wall( 2.5, 2.0,  -47.0, 18.0, rock)

	# Marcas de garras en las paredes (4 por lado, color rojo sangre)
	var red_mark := _mat(Color(0.70, 0.05, 0.05))
	for z_pos: float in [-40.0, -44.0, -48.0, -52.0]:
		_box(Vector3(-1.95, 1.5, z_pos), Vector3(0.15, 1.5, 1.5), red_mark)
		_box(Vector3( 1.95, 1.5, z_pos), Vector3(0.15, 1.5, 1.5), red_mark)

	# ── Rampa S3→S4 (Z=-56 → -59, desciende a Y=-2) ──────────────────────
	_box(Vector3(0.0, -1.0, -57.5), Vector3(5.0, 1.0, 3.0), dark)
	_box(Vector3(0.0,  4.0, -57.5), Vector3(5.0, 1.0, 3.0), dark)
	_wall(-2.5, 1.0, -57.5, 3.0, dark)
	_wall( 2.5, 1.0, -57.5, 3.0, dark)

	# Relleno transición S3→S4 (ensanche de 5m a 16m)
	_box(Vector3(-5.75, 2.5, -57.5), Vector3(6.5, 8.0, 5.0), dark)
	_box(Vector3( 5.75, 2.5, -57.5), Vector3(6.5, 8.0, 5.0), dark)

	# ── S4 Cámara del nido (Z=-59 → -76, piso Y=-2, alto 7m) ─────────────
	_box(Vector3(0.0, -2.5, -67.5), Vector3(16.0, 1.0, 17.0), dark)  # suelo
	_box(Vector3(0.0,  5.5, -67.5), Vector3(16.0, 1.0, 17.0), dark)  # techo
	_box(Vector3(-8.5, 1.5, -67.5), Vector3(1.0,  9.0, 17.0), dark)  # pared izq
	_box(Vector3( 8.5, 1.5, -67.5), Vector3(1.0,  9.0, 17.0), dark)  # pared der
	_box(Vector3( 0.0, 1.5, -77.0), Vector3(18.0, 9.0,  1.0), dark)  # fondo

	# ── Iluminación ───────────────────────────────────────────────────────
	_lamp(-2.0, 2.5,  -4.0, Color(0.95, 0.60, 0.20), 8.0)
	_lamp( 2.0, 2.5, -12.0, Color(0.90, 0.55, 0.15), 7.0)
	_lamp(-4.0, 3.0, -22.0, Color(0.90, 0.50, 0.15), 9.0)
	_lamp( 4.0, 3.0, -32.0, Color(0.85, 0.45, 0.10), 8.0)
	_lamp( 0.0, 2.5, -47.0, Color(0.60, 0.10, 0.10), 7.0)  # pasillo garras
	_lamp( 0.0, 2.0, -67.0, Color(0.22, 0.05, 0.45), 14.0) # nido violeta


# ── Helpers de geometría ─────────────────────────────────────────────────────

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _floor(x: float, y: float, z: float, w: float, l: float, mat: Material) -> void:
	_box(Vector3(x, y - 0.5, z), Vector3(w, 1.0, l), mat)


func _ceil(x: float, y: float, z: float, w: float, l: float, mat: Material) -> void:
	_box(Vector3(x, y + 0.5, z), Vector3(w, 1.0, l), mat)


func _wall(x: float, y: float, z: float, length: float, mat: Material) -> void:
	_box(Vector3(x, y, z), Vector3(1.0, 6.0, length), mat)


func _box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material_override = mat
	b.use_collision = true
	add_child(b)


func _lamp(x: float, y: float, z: float, color: Color, range_: float) -> void:
	var l := OmniLight3D.new()
	l.position = Vector3(x, y, z)
	l.light_color = color
	l.omni_range = range_
	l.light_energy = 1.8
	add_child(l)


# ── HUD ──────────────────────────────────────────────────────────────────────

func _banner(text: String, auto_clear := 0.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud or not hud.has_method("show_banner"):
		return
	hud.show_banner(text)
	if auto_clear > 0.0:
		get_tree().create_timer(auto_clear).timeout.connect(func() -> void:
			if is_instance_valid(hud) and hud.has_method("clear_banner"):
				hud.clear_banner())
