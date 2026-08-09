extends CharacterBody3D

# Emilia: personaje jugable (base Mixamo, un solo rig) con combate.
# Mover WASD | Shift correr | C gatear | T hablar | K tumbarse
# Clic izq combo (flying kick si corres) | Espacio saltar / nadar arriba
# Zona de agua -> nadar.

# Un solo script parametrizado sirve a Emilia y a Benja. La casilla "Is Archer"
# (grupo Personaje) decide el estilo: cuerpo a cuerpo (Emilia) o arco (Benja).
# Cada nodo del editor tiene SUS PROPIOS valores (son independientes).

@export_group("Personaje")
@export var is_archer: bool = false      # true = arquero (Benja); false = peleador (Emilia)
@export var active: bool = true          # controlado por el jugador (si no, IA aliada)
@export var max_health: float = 100.0
@export var max_energy: float = 100.0
@export var attack_speed: float = 1.8    # velocidad de las animaciones de ataque (ambos)
@export var texture_path: String = ""    # textura del modelo (vacio = la de Emilia)
@export var idle_override_path: String = ""  # idle propio (vacio = idle compartido)
@export var model_scene: PackedScene     # malla si se crea por codigo (normalmente vacio)

@export_group("Movimiento")
@export var speed: float = 4.0
@export var run_speed: float = 7.5
@export var crawl_speed: float = 2.0
@export var crawl_lift: float = 0.12
@export var jump_velocity: float = 7.2
@export var accel: float = 14.0
@export var rot_speed: float = 12.0
@export var gravity: float = 18.0

@export_group("Nado")
@export var swim_speed: float = 3.0
@export var swim_up_speed: float = 3.5
@export var swim_sink_speed: float = 1.0
@export var swim_surface_offset: float = 0.4

@export_group("Cuerpo a cuerpo (Emilia)")
@export var attack_range: float = 2.3
@export var combo_cancel_ratio: float = 0.5
@export var flykick_jump: float = 6.0      # impulso vertical de la patada voladora desde el suelo
@export var kick_land_brake: float = 20.0  # frenado al aterrizar la patada (sin patinar)

@export_group("Embestida de lava (Emilia)")
@export var lava_dash_speed: float = 11.0   # velocidad de la embestida de lava
@export var lava_dash_time: float = 0.42    # duracion de la embestida de lava

@export_group("Camara y ajustes")
@export var cam_yaw_deg: float = 45.0
@export var facing_offset_deg: float = 0.0
@export var target_height: float = 1.65
## Ajuste fino del jinete sobre el guanaco (sentado). Negativo = mas abajo sobre el lomo.
@export var ride_seat_offset: Vector3 = Vector3(0.0, -0.2, -0.8)

@export_group("Debug")
@export var debug_auto_walk: bool = false
@export var debug_auto_combo: bool = false
@export var debug_cycle: bool = false
@export var debug_crawl: bool = false
@export var debug_swim: bool = false
@export var debug_fire: bool = false
@export var debug_power: bool = false

const TEXTURE := "res://models/emilia_basecolor.png"
# Golpes: "frac" = momento (0-1) de la anim en que conecta; "dmg" dano;
# "force" knockback; "range" alcance de ese golpe.
const HIT := {
	"punch": {"frac": 0.28, "dmg": 12.0, "force": 3.0, "range": 2.2},
	"cross": {"frac": 0.28, "dmg": 12.0, "force": 3.0, "range": 2.2},
	"knee_kick": {"frac": 0.34, "dmg": 14.0, "force": 4.5, "range": 3.0},
	"mma_kick": {"frac": 0.55, "dmg": 22.0, "force": 10.0, "range": 2.8},
	"flying_kick": {"frac": 0.40, "dmg": 26.0, "force": 9.0, "range": 2.8},
	"shoot": {"frac": 0.45, "dmg": 18.0, "force": 4.0, "range": 0.0},
}

const ANIMS := {
	"idle": "res://models/mix_idle.fbx", "walk": "res://models/mix_walk.fbx",
	"run": "res://models/mix_run.fbx", "crawl": "res://models/mix_crawl.fbx",
	"swim": "res://models/mix_swim.fbx", "punch": "res://models/mix_punch.fbx",
	"cross": "res://models/mix_cross.fbx", "knee_kick": "res://models/mix_knee.fbx",
	"mma_kick": "res://models/mix_mma.fbx", "flying_kick": "res://models/mix_flykick.fbx",
	"jump": "res://models/mix_jump.fbx", "running_jump": "res://models/mix_runjump.fbx",
	"kip_up": "res://models/mix_kipup.fbx", "talking": "res://models/mix_talking.fbx",
	"shoot": "res://models/benja_shoot.fbx",
}
# Animaciones de arquero (solo Benja): tensar, apuntar, soltar, apuntar-caminando.
const ARCHER_ANIMS := {
	"a_draw": "res://models/benja_draw.fbx",       # tensar el arco
	"a_aim": "res://models/benja_aim.fbx",         # tensado al maximo (apuntar, quieto)
	"a_recoil": "res://models/benja_recoil.fbx",   # soltar/disparar
	"a_walk": "res://models/benja_aimwalk.fbx",    # apuntar mientras camina
	"a_seat": "res://models/benja_seat.fbx",       # sentado (montado en el guanaco)
}
const ARROW := preload("res://scenes/Arrow.gd")
const GUANACO := preload("res://scenes/Guanaco.gd")
const VINEFIELD := preload("res://scenes/VineField.gd")
const LAVAPATCH := preload("res://scenes/LavaPatch.gd")
const WINGS_MODEL := "res://models/wings.fbx"
const WINGS_TEX := "res://models/wings_color.jpg"
const WINGS_SIZE := 1.6     # envergadura objetivo (m); se calibra
const WINGS_YAW := 0.0      # orientacion base del modelo (se calibra por captura)
const WINGS_PITCH := 0.0
const WINGS_FLAP_AMP := 0.6 # amplitud del aleteo (rad)
const MAX_CHARGE := 1.1   # segundos para carga maxima (perforante)
# Costos de energia (SP) de cada habilidad
const DJ_COST := 18.0        # doble salto (alas)
const FIRE_DRAIN := 14.0     # por segundo con puños de fuego activos
const LAVA_COST := 35.0      # embestida de lava
const GUANACO_COST := 30.0   # invocar guanaco
const VINES_COST := 25.0     # enredaderas
const TRIPLE_COST := 22.0    # flecha triple
const LOOPING := ["idle", "walk", "run", "crawl", "swim", "talking"]
const FLATTEN_ROOT := ["walk", "run", "crawl", "swim", "flying_kick"]
const FLATTEN_FULL := ["jump", "running_jump"]  # saltos: sin traslacion de raiz (el cuerpo salta de verdad)
const COMBO := ["punch", "cross", "knee_kick", "mma_kick"]
const CYCLE := ["crawl", "swim", "talking", "flying_kick", "kip_up"]

enum St { IDLE, WALK, ACTION }

var health: float
var _anim: AnimationPlayer
var _visual: Node3D
var _body_mat: StandardMaterial3D
var _state: int = St.IDLE
var _combo_index: int = -1
var _attack_queued := false
var _is_combo := false
var _kick_momentum := false   # la flying kick conserva el impulso hasta terminar
var _strike_name := ""        # golpe cuyo impacto esta pendiente (timing)
var _strike_at := 0.0
var _strike_dmg := 0.0
var _strike_force := 0.0
var _strike_range := 2.3
var _strike_done := false
var _jumps_used := 0
var _has_double_jump := false
var _has_fire := false
var _dead := false
var _skel: Skeleton3D
var _fire_l: GPUParticles3D
var _fire_r: GPUParticles3D
var _hand_l := -1
var _hand_r := -1
var _crawling := false
var _crawl_col_state := false
var _col: CollisionShape3D
var _talking := false
var _talk_lock := 0.0         # bloquea la charla al usar el impulso (T sube desnivel)
var _downed := false
var _downed_timer := 0.0
var _in_water := false
var _water_surface := 0.0
var _visual_base_y := 0.0
var _hit_flash := 0.0
var _follow: Node3D           # personaje a seguir cuando es IA
var _ai_dir := Vector3.ZERO
var _ai_shoot_cd := 0.0
var _dodge_timer := 0.0       # IA: esquivando un ataque marcado
var _dodge_cd := 0.0          # IA: espera antes de volver a decidir esquivar
var _dodge_dir := Vector3.ZERO
var _bow: Node3D              # modelo del arco (arquero)
var _charging := false        # tensando el arco
var _charge_time := 0.0
var _has_guanaco := false     # poder de Benja (Entrenadora)
var _has_vines := false       # poder de Benja (Hechicera)
var _riding := false          # montado en el guanaco
var _guanaco: Node3D          # instancia del guanaco (beside/charge/ride)
var _guanaco_beside := false  # invocado y esperando a tu costado
var _q_prev := false
var _f_prev := false
var _e_prev := false
var _g_prev := false
# Energia (SP), potencia por nivel y desbloqueos
var energy: float
var _energy_regen := 16.0
var _power := 1.0             # multiplicador de dano por nivel
var _fire_on := false         # puños de fuego activos (drenan energia)
var _has_lava := false        # embestida de lava desbloqueada
var _unlock_triple := false   # flecha triple desbloqueada
var _unlock_stampede := false # estampida de guanacos desbloqueada
# Embestida de lava (Emilia)
var _lava_dash := false
var _lava_time := 0.0
var _lava_spawn_acc := 0.0
var _lava_hit: Array = []
# Alas espirituales (visual del doble salto)
var _wings: Node3D
var _wings_pivot: Node3D
var _wings_mats: Array[StandardMaterial3D] = []
var _wings_time := 0.0
var _wings_flap := 0.0
var _demo_g := false
var _demo_mount := false
var _demo_dis := false
var _demo_charge := false
var _demo_v := false
var _demo_v2 := false
var _lmb_prev := false
var _space_prev := false
var _c_prev := false
var _t_prev := false
var _k_prev := false
var _demo_time := 0.0
var _demo_clicks := 0
var _demo_rj := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4  # entorno + enemigos
	health = max_health
	energy = max_energy
	var cols := find_children("*", "CollisionShape3D", false, false)
	if not cols.is_empty():
		_col = cols[0] as CollisionShape3D
	# Modelo: usa el hijo del tscn que tenga esqueleto (Emilia o Benja),
	# o instancia model_scene si se creo por codigo.
	for c in get_children():
		if c is Node3D and not (c is CollisionShape3D):
			if (c as Node3D).find_children("*", "Skeleton3D", true, false).size() > 0:
				_visual = c
				break
	if _visual == null and model_scene != null:
		_visual = model_scene.instantiate()
		add_child(_visual)
	_anim = (find_children("*", "AnimationPlayer", true, false)[0]) as AnimationPlayer
	_apply_texture()
	_scale_to_height()
	_visual_base_y = _visual.position.y
	_load_anims()
	_anim.animation_finished.connect(_on_anim_finished)
	_play("idle", 0.0)
	if is_archer:
		_build_bow()
	if debug_fire:
		grant_fire()


func _orient_y(dir: Vector3) -> Basis:
	# Devuelve una base cuyo eje Y local apunta a "dir" (para orientar cilindros).
	var y := dir.normalized()
	var up := Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x := up.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _build_bow() -> void:
	# Arco en "D": arco vertical curvo (belly hacia el objetivo) + cuerda recta
	# entre las puntas. El grip (centro) queda en el origen = mano.
	_hand_l = _skel.find_bone("mixamorig_LeftHand")
	_bow = Node3D.new()
	add_child(_bow)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.26, 0.11)
	wood.roughness = 0.55
	var R := 0.42
	var span := deg_to_rad(80.0)
	var segs := 9
	var pts: Array[Vector3] = []
	for i in range(segs + 1):
		var a: float = lerpf(-span, span, float(i) / float(segs))
		pts.append(Vector3(0.0, R * sin(a), R * cos(a) - R))  # a=0 en el origen
	for i in range(segs):
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var thick: float = 0.026 - 0.011 * (absf(float(i) - float(segs) * 0.5) / (float(segs) * 0.5))
		cyl.top_radius = thick
		cyl.bottom_radius = thick
		cyl.height = p0.distance_to(p1)
		seg.mesh = cyl
		seg.material_override = wood
		seg.transform = Transform3D(_orient_y((p1 - p0).normalized()), (p0 + p1) * 0.5)
		_bow.add_child(seg)
	# Cuerda recta entre las dos puntas.
	var string_mat := StandardMaterial3D.new()
	string_mat.albedo_color = Color(0.92, 0.92, 0.85)
	string_mat.emission_enabled = true
	string_mat.emission = Color(0.8, 0.8, 0.7)
	string_mat.emission_energy_multiplier = 0.4
	var strg := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.006
	sc.bottom_radius = 0.006
	sc.height = pts[0].distance_to(pts[segs])
	strg.mesh = sc
	strg.material_override = string_mat
	strg.transform = Transform3D(_orient_y((pts[segs] - pts[0]).normalized()), (pts[0] + pts[segs]) * 0.5)
	_bow.add_child(strg)
	# Empunadura central.
	var grip := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.03
	gm.bottom_radius = 0.03
	gm.height = 0.16
	grip.mesh = gm
	grip.material_override = wood
	grip.position = Vector3(0, 0, 0.006)
	_bow.add_child(grip)


func set_active(v: bool) -> void:
	active = v


func boost_up(pos: Vector3) -> void:
	# Emilia impulsa a Benja hasta un saliente: sube a su lado.
	global_position = pos
	velocity = Vector3.ZERO
	_jumps_used = 0
	_talking = false          # no quedarse en la anim de hablar
	_talk_lock = 0.4          # y no re-activarla con la misma pulsacion de T
	if _anim:
		_anim.play("jump", 0.05)


func _set_crawl_collision(on: bool) -> void:
	# Al gatear, encoge la capsula para pasar por huecos bajos.
	if _col == null:
		return
	var cap := _col.shape as CapsuleShape3D
	if cap == null:
		return
	if on:
		cap.height = 0.6
		cap.radius = 0.3
		_col.position.y = 0.3
	else:
		cap.height = 1.6
		cap.radius = 0.35
		_col.position.y = 0.8


func set_follow(n: Node3D) -> void:
	_follow = n


func is_talking() -> bool:
	return _talking


func set_in_water(v: bool, surface_y: float = 0.0) -> void:
	_in_water = v
	if v:
		_water_surface = surface_y
		_crawling = false
		_talking = false


# --- Combate ---

func is_dead() -> bool:
	return _dead


func take_damage(dmg: float, from_pos: Vector3) -> void:
	if _downed or _dead:
		return
	health -= dmg
	_hit_flash = 0.15
	var dir := global_position - from_pos
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x += dir.x * 4.0
		velocity.z += dir.z * 4.0
	if health <= 0.0:
		health = 0.0
		_dead = true
		_knock_down()
		_downed_timer = 0.0  # no se levanta: derrota


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	_hit_flash = 0.0
	if is_instance_valid(_body_mat):
		_body_mat.albedo_color = Color(0.6, 1.0, 0.6)  # destello verde breve


func _knock_down() -> void:
	_downed = true
	_downed_timer = 1.3
	_crawling = false
	_talking = false
	_state = St.IDLE
	_is_combo = false
	velocity.x = 0.0
	velocity.z = 0.0
	_anim.play("kip_up")
	_anim.seek(0.0, true)
	_anim.pause()


func _deal_damage(dmg: float, force: float, rng: float) -> void:
	var fdmg: float = dmg * _power * (1.6 if _fire_on else 1.0)  # fuego = +60% dano; nivel escala
	var fwd := Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if absf(e.global_position.y - global_position.y) > 1.6:
			continue  # distinta altura (plataforma): no se golpean
		var v: Vector3 = e.global_position - global_position
		v.y = 0.0
		var d := v.length()
		if d <= rng and (d < 0.6 or fwd.dot(v / d) > 0.15):
			if e.has_method("take_damage"):
				e.take_damage(fdmg, global_position, force, _fire_on)
				_spawn_spark(e.global_position + Vector3(0, 1.0, 0), _fire_on)


func _spawn_spark(pos: Vector3, fire: bool) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.3
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, -7, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.8
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.13, 0.13)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(1.0, 0.55, 0.15) if fire else Color(1.0, 1.0, 0.6)
	qm.material = mat
	p.draw_pass_1 = qm
	var host := get_tree().current_scene
	if host:
		host.add_child(p)
		p.global_position = pos
		p.emitting = true
		p.finished.connect(p.queue_free)


func _schedule_strike(strike_name: String) -> void:
	# Programa el impacto para que ocurra a mitad de la animacion, no al inicio.
	var a := _anim.get_animation(strike_name)
	var cfg: Dictionary = HIT[strike_name]
	_strike_name = strike_name
	_strike_at = (a.length if a else 0.3) * float(cfg["frac"])
	_strike_dmg = cfg["dmg"]
	_strike_force = cfg["force"]
	_strike_range = cfg["range"]
	_strike_done = false


func _update_strike() -> void:
	if _strike_name == "" or _strike_done:
		return
	if _anim.current_animation != _strike_name:
		return
	if _anim.current_animation_position >= _strike_at:
		_strike_done = true
		if _strike_name == "shoot":
			_shoot_arrow()
			return
		_face_nearest_enemy()  # re-encara justo antes de conectar
		_deal_damage(_strike_dmg, _strike_force, _strike_range)
		if _has_fire:
			Sfx.play_at("fire", global_position, -5.0)


# --- Carga ---

func _apply_texture() -> void:
	_body_mat = StandardMaterial3D.new()
	var tex := texture_path if texture_path != "" else TEXTURE
	_body_mat.albedo_texture = load(tex)
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var cnt: int = m.mesh.get_surface_count() if m.mesh else 1
		for s in maxi(cnt, 1):
			m.set_surface_override_material(s, _body_mat)


func _scale_to_height() -> void:
	var sk := (_visual.find_children("*", "Skeleton3D", true, false)[0]) as Skeleton3D
	var box := AABB()
	for i in sk.get_bone_count():
		var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
		if i == 0: box = AABB(p, Vector3.ZERO)
		else: box = box.expand(p)
	var h: float = box.size.y
	if h <= 0.0:
		return
	var f: float = target_height / h
	_visual.scale = Vector3(f, f, f)
	_visual.position.y = -box.position.y * f
	_skel = sk


func _lib() -> AnimationLibrary:
	var lib := _anim.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		_anim.add_animation_library("", lib)
	return lib


func _load_anims() -> void:
	var lib := _lib()
	for key in ANIMS:
		# Permite un idle propio por personaje (Benja) sin afectar a los demas.
		var path: String = ANIMS[key]
		if key == "idle" and idle_override_path != "":
			path = idle_override_path
		var ps := load(path) as PackedScene
		if ps == null:
			continue
		var inst := ps.instantiate()
		var aps := inst.find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty():
			var src := aps[0] as AnimationPlayer
			var names := src.get_animation_list()
			if not names.is_empty():
				var a := src.get_animation(names[0]).duplicate() as Animation
				a.loop_mode = Animation.LOOP_LINEAR if key in LOOPING else Animation.LOOP_NONE
				# El idle propio (override) puede venir a otra escala de cadera y
				# elevar al personaje: le quitamos la posicion de la cadera para
				# que quede apoyado (las rotaciones -respiracion- se conservan).
				var is_override: bool = (key == "idle" and idle_override_path != "")
				if is_override:
					_strip_root_position(a)
				elif key in FLATTEN_FULL:
					_flatten_root(a, true)
				elif key in FLATTEN_ROOT:
					_flatten_root(a, false)
				if lib.has_animation(key):
					lib.remove_animation(key)
				lib.add_animation(key, a)
		inst.free()
	if is_archer:
		for key in ARCHER_ANIMS:
			var ps := load(ARCHER_ANIMS[key]) as PackedScene
			if ps == null:
				continue
			var inst := ps.instantiate()
			var aps := inst.find_children("*", "AnimationPlayer", true, false)
			if not aps.is_empty():
				var src := aps[0] as AnimationPlayer
				var names := src.get_animation_list()
				if not names.is_empty():
					var a := src.get_animation(names[0]).duplicate() as Animation
					a.loop_mode = Animation.LOOP_LINEAR if key in ["a_aim", "a_walk", "a_seat"] else Animation.LOOP_NONE
					_strip_root_position(a)  # en el sitio y apoyado (misma correccion del idle)
					if lib.has_animation(key):
						lib.remove_animation(key)
					lib.add_animation(key, a)
			inst.free()
	print("Animaciones: ", _anim.get_animation_list())


func _strip_root_position(anim: Animation) -> void:
	# Quita las pistas de POSICION de la cadera (deja la cadera en reposo).
	for t in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).contains("Hips"):
			anim.remove_track(t)


func _flatten_root(anim: Animation, full: bool) -> void:
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if not str(anim.track_get_path(t)).contains("Hips"):
			continue
		var kc := anim.track_get_key_count(t)
		if kc == 0:
			continue
		var first: Vector3 = anim.track_get_key_value(t, 0)
		for k in kc:
			var v: Vector3 = anim.track_get_key_value(t, k)
			var ny: float = first.y if full else v.y
			anim.track_set_key_value(t, k, Vector3(first.x, ny, first.z))


# --- Acciones ---

func _play(anim_name: String, blend: float = 0.15) -> void:
	if _anim and _anim.current_animation != anim_name:
		_anim.play(anim_name, blend)


func _can_start() -> bool:
	return _state != St.ACTION and not _downed and not _talking and not _crawling and not _in_water


func _face_nearest_enemy(max_dist: float = 6.0) -> void:
	var best: Node3D = null
	var bd := max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	if best != null:
		var v: Vector3 = best.global_position - global_position
		_visual.rotation.y = atan2(v.x, v.z) + deg_to_rad(facing_offset_deg)


func _combo_hit(index: int) -> void:
	_combo_index = index
	_face_nearest_enemy()
	_anim.play(COMBO[index], 0.07, attack_speed)
	_schedule_strike(COMBO[index])
	var snd := "punch" if COMBO[index] in ["punch", "cross"] else "kick"
	Sfx.play_at(snd, global_position, -2.0, randf_range(0.95, 1.1))


func _on_anim_finished(_n: String) -> void:
	if _state != St.ACTION:
		return
	if _is_combo and _attack_queued and _combo_index < COMBO.size() - 1:
		_attack_queued = false
		_combo_hit(_combo_index + 1)
	else:
		_end_action()


func grant_double_jump() -> void:
	_has_double_jump = true


func grant_fire() -> void:
	if _has_fire:
		return
	_has_fire = true
	_hand_l = _skel.find_bone("mixamorig_LeftHand")
	_hand_r = _skel.find_bone("mixamorig_RightHand")
	_fire_l = _make_fire()
	_fire_r = _make_fire()


# --- Energia / progresion ---

func add_energy(v: float) -> void:
	energy = minf(max_energy, energy + v)


func _spend(cost: float) -> bool:
	# Gasta energia si alcanza; si no, no ejecuta la habilidad.
	if energy < cost:
		return false
	energy -= cost
	return true


func set_power(m: float) -> void:
	_power = m


func unlock(which: String) -> void:
	match which:
		"triple":
			_unlock_triple = true
		"stampede":
			_unlock_stampede = true
		"lava":
			_has_lava = true


func has_power(which: String) -> bool:
	match which:
		"double_jump": return _has_double_jump
		"fire": return _has_fire
		"lava": return _has_lava
		"guanaco": return _has_guanaco
		"vines": return _has_vines
		"triple": return _unlock_triple
		"stampede": return _unlock_stampede
	return false


func _set_fire(on: bool) -> void:
	if on and not _has_fire:
		return
	_fire_on = on


func _toggle_fire() -> void:
	if not _has_fire:
		return
	_set_fire(not _fire_on)
	if _fire_on:
		Sfx.play_at("fire", global_position, -3.0, 1.0)


# --- Alas espirituales (doble salto) ---

func _spawn_wings() -> void:
	if is_instance_valid(_wings):
		_wings.queue_free()
	_wings_mats.clear()
	_wings = Node3D.new()
	add_child(_wings)
	# Pivote a la altura de las escapulas: aqui se aplica el aleteo.
	_wings_pivot = Node3D.new()
	_wings_pivot.position = Vector3(0.0, 1.3, -0.16)
	_wings.add_child(_wings_pivot)
	var ps := load(WINGS_MODEL) as PackedScene
	if ps != null:
		var model := ps.instantiate()
		_wings_pivot.add_child(model)
		_fit_wings(model)
	else:
		_build_feather_wings(_wings_pivot)  # respaldo
	_wings.global_position = global_position
	_wings.rotation.y = _visual.rotation.y
	_wings_time = 1.4
	_wings_flap = 0.0


func _fit_wings(model: Node3D) -> void:
	var tex := load(WINGS_TEX)
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var rel := _rel_xform(m, model)
		var mab: AABB = rel * m.mesh.get_aabb()
		if first:
			aabb = mab
			first = false
		else:
			aabb = aabb.merge(mab)
		var mat := StandardMaterial3D.new()
		if tex != null:
			mat.albedo_texture = tex
			mat.emission_texture = tex
		mat.albedo_color = Color(0.85, 0.95, 1.0, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.9, 1.0)
		mat.emission_energy_multiplier = 0.8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for s in maxi(m.mesh.get_surface_count(), 1):
			m.set_surface_override_material(s, mat)
		_wings_mats.append(mat)
	if first:
		return
	var size := aabb.size
	var longest: float = maxf(size.x, maxf(size.y, size.z))
	var f: float = WINGS_SIZE / longest if longest > 0.0 else 1.0
	model.scale = Vector3(f, f, f)
	# Centrar el modelo en el pivote.
	model.position = -(aabb.position + size * 0.5) * f
	model.rotation = Vector3(deg_to_rad(WINGS_PITCH), deg_to_rad(WINGS_YAW), 0.0)


func _rel_xform(node: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node3D = node
	while n != null and n != top:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t


func _build_feather_wings(parent: Node3D) -> void:
	# Respaldo con plumas de cajas si no cargo el modelo.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.85, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wings_mats.append(mat)
	for sgn in [-1.0, 1.0]:
		for i in range(4):
			var feather := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.07, 0.52 - i * 0.08, 0.02)
			feather.mesh = bm
			feather.material_override = mat
			var reach: float = 0.12 + i * 0.13
			feather.position = Vector3(sgn * reach, i * 0.05, 0.0)
			feather.rotation = Vector3(0, 0, deg_to_rad(sgn * (34.0 + i * 12.0)))
			parent.add_child(feather)


# --- Embestida de lava (Emilia, fuego mejorado) ---

func _begin_lava_dash() -> void:
	if not _has_lava or not _can_start():
		return
	if not _spend(LAVA_COST):
		return
	_face_nearest_enemy(40.0)
	_lava_dash = true
	_lava_time = lava_dash_time
	_lava_spawn_acc = 0.0
	_lava_hit.clear()
	_state = St.ACTION
	_is_combo = false
	_anim.play("flying_kick", 0.08, attack_speed)
	Sfx.play_at("fire", global_position, -1.0, 0.7)


func _lava_process(delta: float) -> void:
	_lava_time -= delta
	var fwd := Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y))
	velocity.x = fwd.x * lava_dash_speed
	velocity.z = fwd.z * lava_dash_speed
	_lava_spawn_acc += delta
	if _lava_spawn_acc >= 0.08:
		_lava_spawn_acc = 0.0
		_spawn_lava_patch()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e in _lava_hit:
			continue
		if global_position.distance_to(e.global_position) < 2.0:
			_lava_hit.append(e)
			if e.has_method("take_damage"):
				e.take_damage(20.0 * _power, global_position, 9.0, true)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	_play("flying_kick", 0.1)
	if _lava_time <= 0.0:
		# Frena en seco al terminar: no se sigue deslizando.
		velocity.x = 0.0
		velocity.z = 0.0
		_lava_dash = false
		_lava_hit.clear()
		_end_action()


func _spawn_lava_patch() -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var lp := Area3D.new()
	lp.set_script(LAVAPATCH)
	host.add_child(lp)
	lp.global_position = global_position  # a la altura del personaje (suelo o plataforma)


func _make_fire() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 20
	p.lifetime = 0.30
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	# Bolita de fuego pegada al puno: pequena, apenas sube.
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 16.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.28
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.35
	pm.scale_max = 0.8
	pm.color = Color(1.0, 0.55, 0.15)
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(1.0, 0.5, 0.12)
	qm.material = mat
	p.draw_pass_1 = qm
	p.emitting = false  # se enciende al activar los puños (tecla G)
	add_child(p)
	return p


func _begin_combo() -> void:
	_state = St.ACTION
	_is_combo = true
	_attack_queued = false
	velocity.x = 0.0
	velocity.z = 0.0
	_combo_hit(0)


func _begin_shoot() -> void:
	_state = St.ACTION
	_is_combo = false
	velocity.x = 0.0
	velocity.z = 0.0
	_face_nearest_enemy(30.0)
	_anim.play("shoot", 0.08, attack_speed)
	_schedule_strike("shoot")
	Sfx.play_at("fire", global_position, -4.0, 0.8)


func _shoot_arrow(dmg: float = -1.0, spd: float = 24.0, pierce: bool = false, ang_deg: float = 0.0) -> void:
	if dmg < 0.0:
		dmg = float(HIT["shoot"]["dmg"]) * _power
	var yaw := _visual.rotation.y + deg_to_rad(ang_deg)
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var host := get_tree().current_scene
	if host == null:
		return
	var a := Area3D.new()
	a.set_script(ARROW)
	host.add_child(a)
	a.global_position = global_position + Vector3(0.0, 1.2, 0.0) + fwd * 0.4
	a.setup(fwd, spd, dmg, pierce)


func _play_shot_anim() -> void:
	# Animacion de soltar/disparar (recoil del arquero).
	if _anim.has_animation("a_recoil"):
		_anim.play("a_recoil", 0.04, attack_speed * 1.2)
	else:
		_anim.play("shoot", 0.05, attack_speed)


func _triple_shot() -> void:
	# Flecha triple en abanico (desbloqueada por nivel).
	if not _spend(TRIPLE_COST):
		return
	_charging = false
	_state = St.ACTION
	_is_combo = false
	velocity.x = 0.0
	velocity.z = 0.0
	_face_nearest_enemy(40.0)
	_play_shot_anim()
	var dmg: float = float(HIT["shoot"]["dmg"]) * _power * 1.1
	for ang in [-16.0, 0.0, 16.0]:
		_shoot_arrow(dmg, 27.0, false, ang)
	Sfx.play_at("kick", global_position, -2.0, 1.3)


func _start_draw() -> void:
	# Empieza a tensar el arco SIN bloquear: puede seguir caminando. La animacion
	# de apuntar (a_aim / a_walk) la pone la seccion de animacion segun se mueva.
	_charging = true
	_charge_time = 0.0
	_is_combo = false
	Sfx.play_at("fire", global_position, -8.0, 1.5)


func _release_shot() -> void:
	_charging = false
	var c: float = _charge_time / MAX_CHARGE
	var dmg: float = float(HIT["shoot"]["dmg"]) * _power * (1.0 + c * 2.0)
	var spd: float = 24.0 + c * 26.0
	var pierce: bool = c >= 0.9
	_face_nearest_enemy(30.0)
	_shoot_arrow(dmg, spd, pierce)
	_state = St.ACTION
	_is_combo = false
	_play_shot_anim()
	Sfx.play_at("kick", global_position, -3.0, 1.4)


func grant_guanaco() -> void:
	_has_guanaco = true


func grant_vines() -> void:
	_has_vines = true


func _guanaco_side_pos() -> Vector3:
	# Punto al costado derecho del jinete, a su misma altura (suelo o plataforma).
	var right := Vector3(cos(_visual.rotation.y), 0.0, -sin(_visual.rotation.y))
	return global_position + right * 1.5


func _summon_guanaco_beside() -> void:
	# 1ª pulsacion: el guanaco aparece a tu costado y espera.
	var host := get_tree().current_scene
	if host == null:
		return
	var g := CharacterBody3D.new()
	g.set_script(GUANACO)
	host.add_child(g)
	g.global_position = _guanaco_side_pos()
	g.setup_beside(self)
	g.face_dir(Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y)))
	_guanaco = g
	_guanaco_beside = true
	Sfx.play_at("boss", global_position, -3.0, 1.8)


func _spawn_charging_guanaco(pos: Vector3, dir: Vector3) -> Node3D:
	var host := get_tree().current_scene
	if host == null:
		return null
	var g := CharacterBody3D.new()
	g.set_script(GUANACO)
	host.add_child(g)
	g.global_position = pos  # conserva la altura (suelo o plataforma)
	g.setup_beside(self)  # necesita rider para el fade; el modo cambia enseguida
	g.start_charge(dir)
	return g


func _guanaco_charge() -> void:
	# 2ª pulsacion (con el guanaco al costado): embiste y DESAPARECE al terminar.
	# Con estampida desbloqueada, salen 3 guanacos en linea.
	if not is_instance_valid(_guanaco):
		return
	_face_nearest_enemy(40.0)
	var fwd := Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y))
	var base := global_position
	_guanaco.global_position = base + fwd * 0.6
	_guanaco.start_charge(fwd)
	_guanaco_beside = false
	if _unlock_stampede:
		var right := Vector3(cos(_visual.rotation.y), 0.0, -sin(_visual.rotation.y))
		for off in [-1.8, 1.8]:
			_spawn_charging_guanaco(base + right * off + fwd * 0.6, fwd)
	_guanaco = null  # ya embiste; se libera solo al terminar
	Sfx.play_at("boss", global_position, -1.0, 1.4)


func _mount_guanaco() -> void:
	# Montar el guanaco (solo si esta invocado a tu costado).
	if not is_instance_valid(_guanaco) or not _guanaco_beside:
		return
	_guanaco.set_ride(self)
	_guanaco_beside = false
	_riding = true
	_charging = false
	_state = St.IDLE
	_play("a_seat" if _anim.has_animation("a_seat") else "idle", 0.1)
	Sfx.play_at("boss", global_position, -1.0, 1.2)


func dismount() -> void:
	# Al bajar, el guanaco DESAPARECE (hay que reinvocarlo).
	_riding = false
	_state = St.IDLE
	_play("idle", 0.1)
	if is_instance_valid(_guanaco):
		_guanaco.queue_free()
	_guanaco = null
	_guanaco_beside = false


func _ride_process(_delta: float) -> void:
	if not is_instance_valid(_guanaco):
		_riding = false
		_guanaco = null
		_state = St.IDLE
		return
	var mv := Vector3.ZERO
	if active:
		var raw := _input_dir()
		if raw.length() > 0.01:
			mv = raw.normalized().rotated(Vector3.UP, deg_to_rad(cam_yaw_deg))
		var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
		var lmb_just := lmb and not _lmb_prev
		_lmb_prev = lmb
		if lmb_just:
			_face_nearest_enemy(40.0)
			_shoot_arrow(float(HIT["shoot"]["dmg"]), 28.0, false)
			Sfx.play_at("fire", global_position, -4.0, 1.1)
		var ek := Input.is_physical_key_pressed(KEY_E) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK)
		var e_just := ek and not _e_prev
		_e_prev = ek
		if e_just:
			dismount()
			return
	else:
		# IA montada: se mueve hacia el enemigo mas cercano.
		var en := _nearest_enemy()
		if en != null:
			var to: Vector3 = en.global_position - global_position
			to.y = 0.0
			if to.length() > 3.0:
				mv = to.normalized()
	# El guanaco se mueve por fisica (colisiona con murallas); el jinete lo sigue.
	_guanaco.ride_velocity = mv * 8.5
	if mv.length() > 0.01:
		_guanaco.face_dir(mv)
		_visual.rotation.y = atan2(mv.x, mv.z) + deg_to_rad(facing_offset_deg)
	# Sentado sobre el lomo: base + ajuste fino (adelante/lateral segun el rumbo del jinete).
	var _yaw := _visual.rotation.y
	var _fwd := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var _rgt := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	global_position = _guanaco.global_position \
		+ Vector3(0.0, _guanaco.mount_offset + ride_seat_offset.y, 0.0) \
		+ _fwd * ride_seat_offset.z + _rgt * ride_seat_offset.x
	velocity = Vector3.ZERO
	_play("a_seat" if _anim.has_animation("a_seat") else "idle", 0.2)


func _cast_vines() -> void:
	var fwd := Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y))
	var host := get_tree().current_scene
	if host == null:
		return
	var v := Area3D.new()
	v.set_script(VINEFIELD)
	host.add_child(v)
	v.global_position = global_position + fwd * 3.0
	Sfx.play_at("fire", global_position, -3.0, 0.6)


func _begin_flying_kick() -> void:
	# Patada voladora: si esta en el suelo, DESPEGA (parabola); si ya esta en el
	# aire, sigue su parabola actual. Conserva el impulso horizontal y solo frena
	# suavemente al TOCAR el suelo (no al empezar, no patina).
	_state = St.ACTION
	_is_combo = false
	_kick_momentum = true
	if is_on_floor():
		velocity.y = flykick_jump
	_anim.play("flying_kick", 0.1, attack_speed)
	_schedule_strike("flying_kick")
	Sfx.play_at("kick", global_position, -1.0, 0.9)


func _try_jump() -> void:
	# Salto real (con altura). En el aire, salto extra si tiene doble salto.
	if is_on_floor():
		velocity.y = jump_velocity
		_jumps_used = 1
		_anim.play("jump", 0.05)
		Sfx.play("jump", -8.0)
	elif _has_double_jump and _jumps_used < 2 and _spend(DJ_COST):
		# 2º salto: alas espirituales que dan el impulso.
		velocity.y = jump_velocity
		_jumps_used = 2
		_spawn_wings()
		_anim.play("jump", 0.05)
		Sfx.play("jump", -7.0, 1.2)


func _toggle_downed() -> void:
	if _downed:
		_get_up()
	else:
		_downed = true
		_downed_timer = 0.0
		_crawling = false
		_talking = false
		velocity.x = 0.0
		velocity.z = 0.0
		_anim.play("kip_up")
		_anim.seek(0.0, true)
		_anim.pause()


func _get_up() -> void:
	_downed = false
	_downed_timer = 0.0
	_state = St.ACTION
	_is_combo = false
	_anim.play("kip_up", 0.05)


func _end_action() -> void:
	_state = St.IDLE
	_combo_index = -1
	_attack_queued = false
	_is_combo = false
	_kick_momentum = false
	_strike_name = ""
	_play("idle", 0.15)


func _try_cancel_advance() -> void:
	if _state != St.ACTION or not _is_combo or not _attack_queued:
		return
	if _combo_index >= COMBO.size() - 1:
		return
	var cur := _anim.current_animation
	if cur == "" or not _anim.is_playing():
		return
	var a := _anim.get_animation(cur)
	if a == null or a.length <= 0.0:
		return
	if _anim.current_animation_position >= a.length * combo_cancel_ratio:
		_attack_queued = false
		_combo_hit(_combo_index + 1)


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _nearest_threat() -> Node3D:
	# Enemigo cercano que esta AVISANDO un ataque (dentro de su area de peligro).
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if not e.has_method("is_telegraphing") or not e.is_telegraphing():
			continue
		var d := global_position.distance_to(e.global_position)
		if d < e.danger_radius() + 1.5:
			return e
	return null


func _ai_decide(delta: float) -> void:
	# IA aliada: el arquero dispara a distancia; el peleador se acerca y golpea.
	# Ambos siguen al personaje activo cuando no hay enemigos cerca.
	_ai_dir = Vector3.ZERO
	_ai_shoot_cd = maxf(0.0, _ai_shoot_cd - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	if _state == St.ACTION or _downed or _talking:
		return
	# A veces (no siempre) esquiva un ataque marcado tomando distancia.
	if _dodge_timer <= 0.0 and _dodge_cd <= 0.0:
		var threat := _nearest_threat()
		if threat != null:
			_dodge_cd = 0.9  # no volver a decidir de inmediato
			if randf() < 0.6:
				_dodge_timer = 0.75
				var away: Vector3 = global_position - threat.global_position
				away.y = 0.0
				_dodge_dir = away.normalized() if away.length() > 0.1 else Vector3(0, 0, 1)
	if _dodge_timer > 0.0:
		_ai_dir = _dodge_dir
		return
	var enemy := _nearest_enemy()
	var to_enemy := Vector3.ZERO
	var de := 1e9
	if enemy != null:
		to_enemy = enemy.global_position - global_position
		to_enemy.y = 0.0
		de = to_enemy.length()
	if is_archer:
		if enemy != null and de <= 16.0 and _ai_shoot_cd <= 0.0:
			_ai_shoot_cd = 1.1
			_begin_shoot()
			return
		if enemy != null and de < 5.0:
			_ai_dir = (-to_enemy).normalized()  # se aleja para tener distancia
		elif _follow != null and global_position.distance_to(_follow.global_position) > 5.0:
			_ai_dir = _to_follow()
	else:
		if enemy != null and de > 2.2:
			_ai_dir = to_enemy.normalized()
		elif enemy != null and _can_start():
			_begin_combo()
		elif _follow != null and global_position.distance_to(_follow.global_position) > 4.0:
			_ai_dir = _to_follow()


func _to_follow() -> Vector3:
	var v := _follow.global_position - global_position
	v.y = 0.0
	return v.normalized() if v.length() > 0.1 else Vector3.ZERO


func _input_dir() -> Vector3:
	if debug_auto_walk and _demo_time > 1.5 and _demo_time < 6.0:
		return Vector3(1, 0, 0)
	var d := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): d.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): d.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): d.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): d.x += 1.0
	# Mando: stick izquierdo.
	var jx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var jy := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(jx) > 0.2: d.x += jx
	if absf(jy) > 0.2: d.z += jy
	return d


func _physics_process(delta: float) -> void:
	_demo_time += delta

	if debug_cycle:
		var i := clampi(int((_demo_time - 1.0) / 0.6), 0, CYCLE.size() - 1)
		_play(CYCLE[i], 0.1)
		return

	# Fuego en las manos (sigue a los huesos; emite solo si esta activo)
	if _has_fire and _fire_l != null:
		_fire_l.emitting = _fire_on
		_fire_r.emitting = _fire_on
		if _hand_l >= 0:
			_fire_l.global_position = _skel.global_transform * _skel.get_bone_global_pose(_hand_l).origin
		if _hand_r >= 0:
			_fire_r.global_position = _skel.global_transform * _skel.get_bone_global_pose(_hand_r).origin

	# Arco en la mano izquierda: se coloca en el hueso de la mano pero se orienta
	# al frente del personaje (mas estable que copiar el giro del hueso).
	if _bow != null and _hand_l >= 0 and _skel != null:
		var hp: Vector3 = (_skel.global_transform * _skel.get_bone_global_pose(_hand_l)).origin
		_bow.global_position = hp
		_bow.rotation = Vector3(0.0, _visual.rotation.y + deg_to_rad(facing_offset_deg), 0.0)

	if _dead:
		return

	_talk_lock = maxf(0.0, _talk_lock - delta)

	# Energia (SP): los puños de fuego drenan; si no, regenera.
	if _fire_on:
		energy = maxf(0.0, energy - FIRE_DRAIN * delta)
		if energy <= 0.0:
			_set_fire(false)
	else:
		energy = minf(max_energy, energy + _energy_regen * delta)

	# Alas espirituales: siguen al personaje, aletean y se desvanecen. Se quitan
	# al aterrizar (o al agotarse el tiempo maximo de seguridad).
	if is_instance_valid(_wings):
		_wings.global_position = global_position
		_wings.rotation.y = _visual.rotation.y
		_wings_time -= delta
		_wings_flap += delta * 13.0
		if is_instance_valid(_wings_pivot):
			# Aleteo simetrico: el par sube y baja (cabeceo), sin girar de lado.
			var flap: float = sin(_wings_flap)
			_wings_pivot.rotation.x = deg_to_rad(-6.0) + flap * WINGS_FLAP_AMP
		var wa: float = clampf(_wings_time, 0.0, 1.0)
		for wm in _wings_mats:
			wm.albedo_color = Color(0.85, 0.95, 1.0, 0.85 * wa)
			wm.emission_energy_multiplier = 0.9 * wa
		var landed: bool = is_on_floor() and velocity.y <= 0.05
		if _wings_time <= 0.0 or landed:
			_wings.queue_free()

	# Embestida de lava (Emilia): avanza dejando magma y quema a su paso.
	if _lava_dash:
		_lava_process(delta)
		return

	if debug_power:
		energy = max_energy
		if is_archer:
			_has_guanaco = true
			_has_vines = true
			_unlock_triple = true
			_unlock_stampede = true
			if _demo_time > 1.3 and not _demo_g:
				_demo_g = true
				_summon_guanaco_beside()
			if _demo_time > 2.6 and not _demo_charge:
				_demo_charge = true
				_guanaco_charge()  # estampida (3 guanacos)
			if _demo_time > 4.2 and not _demo_v:
				_demo_v = true
				_cast_vines()
			if _demo_time > 5.6 and not _demo_mount:
				_demo_mount = true
				_summon_guanaco_beside()
			if _demo_time > 6.2 and not _demo_dis:
				_demo_dis = true
				_mount_guanaco()
			if _demo_time > 7.6 and not _demo_v2:
				_demo_v2 = true
				_triple_shot()
		else:
			_has_double_jump = true
			grant_fire()
			_has_lava = true
			if _demo_time > 1.3 and not _demo_g:
				_demo_g = true
				_toggle_fire()
			if _demo_time > 2.4 and not _demo_mount:
				_demo_mount = true
				_try_jump()
			if _demo_time > 2.75 and not _demo_charge:
				_demo_charge = true
				_try_jump()  # doble salto -> alas espirituales
			if _demo_time > 5.0 and not _demo_v:
				_demo_v = true
				_begin_lava_dash()

	# Si el guanaco desaparecio (fin de embestida o tiempo), resetea estado.
	if _guanaco != null and not is_instance_valid(_guanaco):
		_guanaco = null
		_guanaco_beside = false
		if _riding:
			_riding = false
			_state = St.IDLE

	# Guanaco esperando: se acerca a tu costado (con colision).
	if _guanaco_beside and is_instance_valid(_guanaco):
		_guanaco.beside_target = _guanaco_side_pos()
		_guanaco.face_dir(Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y)))

	# Montado en el guanaco: solo dispara, no se mueve por si mismo.
	if _riding:
		_ride_process(delta)
		return

	if _charging:
		_charge_time = minf(MAX_CHARGE, _charge_time + delta)
		if Vector2(velocity.x, velocity.z).length() < 0.6:
			_face_nearest_enemy(30.0)  # apunta al enemigo solo si esta quieto

	# Flash de dano
	if _hit_flash > 0.0:
		_hit_flash -= delta
		_body_mat.albedo_color = Color(1.0, 0.5, 0.5)
	else:
		_body_mat.albedo_color = Color.WHITE

	# Levantarse automatico tras knockdown
	if _downed and _downed_timer > 0.0:
		_downed_timer -= delta
		if _downed_timer <= 0.0:
			_get_up()

	var moving := false
	var running := false
	var move_world := Vector3.ZERO

	if active:
		# --- Entrada del jugador (teclado + mando) ---
		var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
		var lmb_just := lmb and not _lmb_prev
		var lmb_released := (not lmb) and _lmb_prev
		_lmb_prev = lmb
		var qk := Input.is_physical_key_pressed(KEY_Q)
		var q_just := qk and not _q_prev
		_q_prev = qk
		var fk := Input.is_physical_key_pressed(KEY_F)
		var f_just := fk and not _f_prev
		_f_prev = fk
		var ek := Input.is_physical_key_pressed(KEY_E) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK)
		var e_just := ek and not _e_prev
		_e_prev = ek
		var gk := Input.is_physical_key_pressed(KEY_G) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP)
		var g_just := gk and not _g_prev
		_g_prev = gk
		var sp := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
		var sp_just := sp and not _space_prev
		_space_prev = sp
		var ck := Input.is_physical_key_pressed(KEY_C) or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
		var c_just := ck and not _c_prev
		_c_prev = ck
		var tk := Input.is_physical_key_pressed(KEY_T) or Input.is_joy_button_pressed(0, JOY_BUTTON_Y)
		var t_just := tk and not _t_prev
		_t_prev = tk
		var kk := Input.is_physical_key_pressed(KEY_K) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)
		var k_just := kk and not _k_prev
		_k_prev = kk

		if debug_auto_combo and _demo_clicks < 12 and _demo_time > 1.0 + _demo_clicks * 0.5:
			_demo_clicks += 1
			lmb_just = true
		if debug_auto_walk and _demo_time > 2.5 and not _demo_rj:
			_demo_rj = true
			sp_just = true
		if debug_crawl:
			_crawling = true
		if debug_swim:
			_in_water = true
			_water_surface = 3.0

		var raw := _input_dir()
		moving = raw.length() > 0.01
		var run_held := Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		running = run_held and moving and not _crawling and not _in_water

		if k_just and _state != St.ACTION and _downed_timer <= 0.0:
			_toggle_downed()
		if not _downed:
			if c_just and _state != St.ACTION and not _talking and not _in_water:
				_crawling = not _crawling
			if t_just and _talk_lock <= 0.0 and _state != St.ACTION and not _crawling and not _in_water:
				_talking = not _talking
			if is_archer:
				# Arco: mantener clic para cargar, soltar para disparar.
				if lmb_just and _can_start():
					_start_draw()
				elif lmb_released and _charging:
					_release_shot()
				if q_just and _has_guanaco:
					if _guanaco_beside and is_instance_valid(_guanaco):
						_guanaco_charge()  # 2ª pulsacion: embiste y desaparece
					elif (_guanaco == null or not is_instance_valid(_guanaco)) and _can_start():
						if _spend(GUANACO_COST):
							_summon_guanaco_beside()  # 1ª pulsacion: aparece al costado
				if e_just and _guanaco_beside and is_instance_valid(_guanaco) and _can_start():
					_mount_guanaco()  # montar (E de nuevo desmonta, dentro de _ride_process)
				if g_just and _unlock_triple and _can_start():
					_triple_shot()  # flecha triple en abanico
				if f_just and _has_vines and _can_start() and _spend(VINES_COST):
					_cast_vines()
				if sp_just and _can_start():
					_try_jump()
			else:
				if lmb_just:
					if _state == St.ACTION:
						if _is_combo:
							_attack_queued = true
					elif _can_start():
						if running:
							_begin_flying_kick()
						else:
							_begin_combo()
				elif sp_just and _can_start():
					_try_jump()
				if g_just and _has_fire:
					_toggle_fire()  # activar/apagar puños de fuego (drenan energia)
				if f_just and _has_lava and _can_start():
					_begin_lava_dash()  # embestida de lava
		if moving:
			move_world = raw.normalized().rotated(Vector3.UP, deg_to_rad(cam_yaw_deg))
	else:
		# --- IA aliada ---
		_ai_decide(delta)
		move_world = _ai_dir
		moving = move_world.length() > 0.01

	_try_cancel_advance()
	_update_strike()

	var busy := _state == St.ACTION or _downed or _talking

	var cur_speed := speed
	if _in_water:
		cur_speed = swim_speed
	elif _crawling:
		cur_speed = crawl_speed
	elif running:
		cur_speed = run_speed

	var dir := Vector3.ZERO
	if moving and not busy:
		dir = move_world
	if _kick_momentum:
		if is_on_floor() and velocity.y <= 0.1:
			velocity.x = move_toward(velocity.x, 0.0, kick_land_brake * delta)
			velocity.z = move_toward(velocity.z, 0.0, kick_land_brake * delta)
	else:
		var target := dir * cur_speed
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)

	if _in_water:
		if (active and Input.is_physical_key_pressed(KEY_SPACE)) or debug_swim:
			velocity.y = swim_up_speed
		else:
			velocity.y = -swim_sink_speed
	elif not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y <= 0.0:  # no pisar el suelo si acaba de saltar
			velocity.y = -0.1
			_jumps_used = 0
	move_and_slide()

	if _in_water:
		var top := _water_surface - swim_surface_offset  # flota cerca de la superficie
		if global_position.y > top:
			global_position.y = top
			if velocity.y > 0.0:
				velocity.y = 0.0

	_visual.position.y = _visual_base_y + (crawl_lift if _crawling else 0.0)
	if _crawling != _crawl_col_state:
		_crawl_col_state = _crawling
		_set_crawl_collision(_crawling)

	# --- Animacion ---
	if _downed or _state == St.ACTION:
		return
	if _talking:
		_play("talking", 0.2)
		return
	# Arquero tensando: apunta caminando (a_walk) o quieto (a_aim). No bloquea.
	if is_archer and _charging and is_on_floor() and not _in_water:
		var pv := Vector2(velocity.x, velocity.z)
		if pv.length() > 0.3:
			var ayaw := atan2(velocity.x, velocity.z) + deg_to_rad(facing_offset_deg)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, ayaw, rot_speed * delta)
			_state = St.WALK
			_play("a_walk", 0.15)
		else:
			_state = St.IDLE
			_play("a_aim", 0.12)
		return
	if not _in_water and not is_on_floor():
		# En el aire: salto (running_jump si lleva impulso horizontal).
		var av := Vector2(velocity.x, velocity.z)
		if av.length() > 0.2:
			var jyaw := atan2(velocity.x, velocity.z) + deg_to_rad(facing_offset_deg)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, jyaw, rot_speed * delta)
		_play("running_jump" if av.length() > 1.5 else "jump", 0.1)
		return
	var planar := Vector2(velocity.x, velocity.z)
	if planar.length() > 0.2:
		_state = St.WALK
		var yaw := atan2(velocity.x, velocity.z) + deg_to_rad(facing_offset_deg)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, rot_speed * delta)
		var loco := "swim" if _in_water else ("crawl" if _crawling else ("run" if running else "walk"))
		_play(loco, 0.15)
	else:
		_state = St.IDLE
		var idle_anim := "swim" if _in_water else ("crawl" if _crawling else "idle")
		_play(idle_anim, 0.2)
