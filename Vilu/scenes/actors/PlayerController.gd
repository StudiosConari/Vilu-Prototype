extends CharacterBody3D

## Protagonista de VILU. Hay dos en el party: Emilia (melee) y Benjamín (arquero).
##
## MODO DE CONTROL:
##  - PLAYER: lo controlás con teclado/mouse (activo, con cámara).
##  - IA COMBAT: pelea solo (persigue, ataca básico, esquiva telegrafiados).
##  - FROZEN: se queda quieto (para puzzles).
## Game cambia el activo con R (deja al otro en IA) o T (deja al otro QUIETO).
##
## HABILIDADES (por personaje, algunas las entrega La Tirana / Carmen = has_bow):
##  - Emilia: base 1 golpe -> tras la Tirana, COMBO de 4 golpes. Alas: doble
##    salto + planeo.
##  - Benjamín: base flecha normal + flecha CARGADA (mantener clic). Tras la
##    Tirana: FLECHA TRIPLE (activable con clic der, gasta energía). Guanaco:
##    montura (Q).
##
## Controles (activo): WASD mover, Shift correr, Espacio saltar (doble con alas),
## clic izq atacar (melee o flecha, mantener = cargada), clic der flecha triple,
## Q montar (Benjamín), E interactuar.

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal died
signal melee_hit(step: int)
signal arrow_fired

const ARROW_SCRIPT := preload("res://scenes/Arrow.gd")
const GUANACO_COMP_SCR := preload("res://scenes/actors/GuanacoCompanion.gd")

enum AiMode { COMBAT, FROZEN }

@export_group("Rol")
@export var is_archer := false

@export_group("Movimiento")
@export var walk_speed := 4.0
@export var run_speed := 7.5
@export var acceleration := 12.0
@export var jump_velocity := 6.0
@export var gravity := 18.0
@export var turn_speed := 14.0
@export var updraft_speed := 6.0    # velocidad de ascenso en una corriente (Emilia planeando)

@export_group("Vida y energía")
@export var max_health := 100
@export var max_energy := 100
@export var energy_regen := 18.0
@export var triple_cost := 35

@export_group("Combate")
@export var combo_window := 0.6
@export var attack_cooldown := 0.28
@export var melee_damage: Array[float] = [8.0, 8.0, 12.0, 18.0]   # combo de 4 (Emilia, tras la Tirana)
@export var melee_range := 1.1
@export var arrow_speed := 26.0
@export var arrow_damage := 10.0
@export var charge_time := 0.4      # mantener el clic este tiempo = flecha cargada
@export var defense_radius := 3.0   # en modo QUIETO, defiende si un enemigo entra a este rango
@export var guard_leash := 14.0     # persigue y REMATA al objetivo hasta esta distancia del puesto
@export var ai_attack_cooldown := 0.45   # cadencia de ataque de la IA

var health: int
var energy: float
var input_locked := false
var active := true
var ai_mode: int = AiMode.COMBAT

# Estados de habilidad
var can_glide := false
var glide_gravity_scale := 0.35
var mounted := false
var in_updraft := false             # dentro de una corriente ascendente (lo setea Updraft.gd)

# Interacción
var hud: CanvasLayer
var _interactable: Node = null

@onready var _visual: Node3D = $Visual
@onready var _wings_vis: Node3D = get_node_or_null("Visual/Wings")
@onready var _guanaco_vis: Node3D = get_node_or_null("Visual/Guanaco")

var _jumps_done := 0
var _jump_held_prev := false
var _e_held_prev := false
var _q_held_prev := false
var _combo_step := 0
var _combo_timer := 0.0
var _attack_cd := 0.0
var _ai_atk_cd := 0.0
var _charging := false
var _charge_t := 0.0
var _energy_shown := -1
var forced_run_dir := Vector3.ZERO  # cuando no es ZERO, el personaje corre en esa dirección sin input (huida)
var _hold_pos := Vector3.ZERO      # puesto a defender en modo QUIETO
var _guard_target: Node3D = null   # enemigo con el que el guardia se compromete


func _ready() -> void:
	health = max_health
	energy = float(max_energy)
	health_changed.emit(health, max_health)
	energy_changed.emit(int(energy), max_energy)
	DialogueManager.dialogue_started.connect(func(_r: Resource) -> void: input_locked = true)
	DialogueManager.dialogue_ended.connect(func(_r: Resource) -> void: input_locked = false)
	can_glide = (not is_archer) and GameManager.has_ability("wings")
	GameManager.ability_unlocked.connect(_on_ability_unlocked)
	TravelManager.region_changed.connect(func(_r: String) -> void: forced_run_dir = Vector3.ZERO)


func _on_ability_unlocked(ability: String) -> void:
	if ability == "wings" and not is_archer:
		can_glide = true


# La Tirana (Carmen) mejora el combate: Emilia combo x4, Benjamín flecha triple.
func _upgraded() -> bool:
	return GameManager.has_ability("bow")


func _physics_process(delta: float) -> void:
	_combo_timer = max(0.0, _combo_timer - delta)
	_attack_cd = max(0.0, _attack_cd - delta)
	_ai_atk_cd = max(0.0, _ai_atk_cd - delta)
	if _charging:
		_charge_t += delta
	energy = min(float(max_energy), energy + energy_regen * delta)
	if int(energy) != _energy_shown:
		_energy_shown = int(energy)
		energy_changed.emit(_energy_shown, max_energy)

	# --- Gravedad / planeo / corriente ascendente + reset de saltos ---
	if active and in_updraft and can_glide and Input.is_action_pressed("jump"):
		velocity.y = move_toward(velocity.y, updraft_speed, 40.0 * delta)   # Emilia sube en la corriente
		_jumps_done = 0
	elif is_on_floor():
		_jumps_done = 0
	else:
		var g := gravity
		if active and can_glide and Input.is_action_pressed("jump") and velocity.y < 0.0:
			g *= glide_gravity_scale
		velocity.y -= g * delta

	# --- Dirección según el modo ---
	var dir := Vector3.ZERO
	if input_locked:
		dir = Vector3.ZERO
	elif active:
		dir = _player_input()
		# Strafe durante auto-run: el activo controla izquierda/derecha.
		if forced_run_dir != Vector3.ZERO:
			var ix := 0.0
			if Input.is_action_pressed("move_right"): ix += 1.0
			if Input.is_action_pressed("move_left"): ix -= 1.0
			var right := forced_run_dir.cross(Vector3.UP).normalized()
			dir = (forced_run_dir + right * ix * 0.5).normalized()
	elif forced_run_dir != Vector3.ZERO:
		dir = forced_run_dir   # huida forzada: corre sin pasar por _ai_behavior (evita ataques al aire)
	elif ai_mode == AiMode.COMBAT:
		dir = _ai_behavior()
	else:
		dir = _hold_behavior()   # QUIETO: defiende el puesto y vuelve

	# La IA/guardia no se tira a los vacíos: si no hay piso adelante, se frena.
	if not active and forced_run_dir == Vector3.ZERO and dir != Vector3.ZERO and not _has_ground_ahead(dir):
		dir = Vector3.ZERO

	# El personaje inactivo detecta obstáculos y salta solo (huida forzada o follow normal).
	if not active and is_on_floor():
		var check_dir := forced_run_dir if forced_run_dir != Vector3.ZERO else dir
		if check_dir != Vector3.ZERO:
			var space := get_world_3d().direct_space_state
			for ry in [0.3, 0.7]:
				var ori := global_position + Vector3(0.0, ry, 0.0)
				var tgt := ori + check_dir.normalized() * 1.2
				var q := PhysicsRayQueryParameters3D.create(ori, tgt)
				q.collision_mask = 1
				q.exclude = [get_rid()]
				if not space.intersect_ray(q).is_empty():
					velocity.y = jump_velocity
					_jumps_done = 1
					break

	var speed := walk_speed
	if forced_run_dir != Vector3.ZERO:
		speed = run_speed
	elif active and not input_locked and Input.is_action_pressed("run"):
		speed = run_speed
	elif not active and ai_mode == AiMode.COMBAT:
		speed = _velocidad_de_escolta()
	if mounted:
		speed *= 1.5

	velocity.x = move_toward(velocity.x, dir.x * speed, acceleration * speed * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, acceleration * speed * delta)
	move_and_slide()

	# --- Encarar el movimiento (solo el Visual rota; -Z adelante) ---
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() > 0.15:
		var target_yaw := atan2(-hv.x, -hv.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, turn_speed * delta)

	if _wings_vis:
		_wings_vis.visible = can_glide
	# El cubo café placeholder ya no se usa: la montura es el guanaco compañero real.
	if _guanaco_vis:
		_guanaco_vis.visible = false

	# Si el guanaco desapareció (cambio de zona, etc.) dejamos de estar montados.
	if mounted and guanaco_companion() == null:
		mounted = false
	# Montado: el jinete se eleva para quedar sobre el lomo del guanaco.
	_visual.position.y = lerp(_visual.position.y, 0.75 if mounted else 0.0, 12.0 * delta)


# --- Control del jugador (WASD/salto/mount/interact) ---
func _player_input() -> Vector3:
	var iz := 0.0   # adelante/atrás (relativo a la cámara)
	var ix := 0.0   # derecha/izquierda
	if Input.is_action_pressed("move_forward"): iz += 1.0
	if Input.is_action_pressed("move_back"): iz -= 1.0
	if Input.is_action_pressed("move_right"): ix += 1.0
	if Input.is_action_pressed("move_left"): ix -= 1.0
	var dir := _camera_relative(ix, iz)

	# Salto (doble con alas)
	var jump_held := Input.is_action_pressed("jump")
	if jump_held and not _jump_held_prev:
		if is_on_floor():
			velocity.y = jump_velocity * (1.15 if mounted else 1.0)
			_jumps_done = 1
		elif can_glide and _jumps_done < 2:
			velocity.y = jump_velocity
			_jumps_done = 2
	_jump_held_prev = jump_held

	# Interacción (E)
	var e_held := Input.is_action_pressed("interact")
	if e_held and not _e_held_prev and _interactable != null and _interactable.has_method("interact"):
		_interactable.interact(self)
	_e_held_prev = e_held

	# Guanaco (Q) — solo Benjamín. Ciclo: invocar -> montar -> guardar.
	if is_archer and GameManager.has_ability("guanaco"):
		var q_held := Input.is_action_pressed("guanaco")
		if q_held and not _q_held_prev:
			_cycle_guanaco()
		_q_held_prev = q_held

	return dir


# --- Guanaco compañero (Benjamín, tras la bendición del Yastay) ---
## Q alterna entre los tres estados: sin guanaco -> invocado -> montado -> guardado.
func _cycle_guanaco() -> void:
	var g := guanaco_companion()
	if g == null:
		_summon_guanaco()
	elif not mounted:
		mounted = true
		if g.has_method("set_mounted"):
			g.set_mounted(true)
		_banner("Guanaco: MONTADO · [Q] guardar")
	else:
		mounted = false
		if g.has_method("set_mounted"):
			g.set_mounted(false)
		g.queue_free()
		_banner("Guanaco guardado · [Q] invocar")


func _summon_guanaco() -> void:
	var g := Node3D.new()
	g.set_script(GUANACO_COMP_SCR)
	get_tree().current_scene.add_child(g)
	g.global_position = global_position + _visual.global_transform.basis.x * 1.8
	_banner("Guanaco invocado · [Q] montar · [G] embestir")


func guanaco_companion() -> Node3D:
	for g in get_tree().get_nodes_in_group("guanaco_companion"):
		if is_instance_valid(g):
			return g
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not active or input_locked:
		return
	# Ataque (melee, o flecha normal/cargada del arquero).
	if event.is_action_pressed("attack"):
		if is_archer:
			_charging = true
			_charge_t = 0.0
		else:
			_melee_attack()
	elif event.is_action_released("attack"):
		if is_archer and _charging:
			var charged := _charge_t >= charge_time
			_charging = false
			_shoot_arrow(charged)
	# Flecha triple (Benjamín). El clic derecho quedó para rotar la cámara.
	elif event.is_action_pressed("triple_arrow") and not event.is_echo():
		if is_archer:
			_triple_arrow()


## Convierte input WASD (ix derecha, iz adelante) a dirección en el mundo relativa
## a hacia dónde mira la cámara (para que W sea "hacia adentro de la pantalla").
func _camera_relative(ix: float, iz: float) -> Vector3:
	if ix == 0.0 and iz == 0.0:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	var fwd := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)
	if cam:
		fwd = -cam.global_transform.basis.z
		fwd.y = 0.0
		right = cam.global_transform.basis.x
		right.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)
		right = right.normalized() if right.length() > 0.01 else Vector3(1, 0, 0)
	var d := fwd * iz + right * ix
	return d.normalized() if d.length() > 1.0 else d


func _facing() -> Vector3:
	return (-_visual.global_transform.basis.z).normalized()


func _face(to: Vector3) -> void:
	to.y = 0.0
	if to.length() > 0.05:
		_visual.rotation.y = atan2(-to.x, -to.z)


## Dirección de apuntado del jugador: del personaje hacia el punto del mundo bajo
## el MOUSE (proyección de la cámara sobre el plano del pecho). Si no se puede,
## cae al encare actual.
func _aim_direction() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return _facing()
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var ray := cam.project_ray_normal(mouse)
	var plane_y := global_position.y + 1.0
	if absf(ray.y) < 0.0001:
		return _facing()
	var t := (plane_y - from.y) / ray.y
	if t <= 0.0:
		return _facing()
	var point := from + ray * t
	var dir := point - (global_position + Vector3(0.0, 1.0, 0.0))
	dir.y = 0.0
	if dir.length() < 0.15:
		return _facing()
	return dir.normalized()


func _face_aim() -> Vector3:
	var d := _aim_direction()
	_visual.rotation.y = atan2(-d.x, -d.z)
	return d


# --- Melee (Emilia): combo de 4 golpes tras la Tirana; 1 golpe antes ---
func _melee_attack() -> void:
	if _attack_cd > 0.0:
		return
	var max_step := (melee_damage.size() - 1) if _upgraded() else 0
	if _combo_timer > 0.0 and _combo_step < max_step:
		_combo_step += 1
	else:
		_combo_step = 0
	_combo_timer = combo_window
	_attack_cd = attack_cooldown

	var dmg: float = melee_damage[_combo_step]
	Sfx.play("punch" if _combo_step < 2 else "kick", -3.0, 1.0 + _combo_step * 0.1)
	_face_aim()                # encara hacia el mouse antes de golpear
	_squash()
	_spawn_melee_hit(dmg)
	melee_hit.emit(_combo_step)


func _spawn_melee_hit(dmg: float) -> void:
	var hit := Area3D.new()
	hit.collision_mask = 4
	hit.monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = melee_range
	cs.shape = sh
	hit.add_child(cs)
	get_tree().current_scene.add_child(hit)
	hit.global_position = global_position + Vector3(0.0, 0.9, 0.0) + _facing() * 1.0
	var hit_pos := hit.global_position
	hit.body_entered.connect(func(b: Node3D) -> void:
		if (b.is_in_group("enemies") or b.is_in_group("hittable")) and b.has_method("take_damage"):
			b.take_damage(dmg, hit_pos, 5.0))
	get_tree().create_timer(0.12).timeout.connect(hit.queue_free)


# --- Arco (Benjamín) ---
func _shoot_arrow(charged: bool) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = 0.4 if charged else 0.22
	_spawn_arrow(_face_aim(), charged)   # apunta hacia el mouse
	Sfx.play("fire", -3.0, 0.8 if charged else 1.0)
	arrow_fired.emit()


func _triple_arrow() -> void:
	if not _upgraded():
		_banner("Flecha triple: habla con La Tirana")
		return
	if energy < float(triple_cost):
		_banner("Sin energía para la flecha triple")
		return
	if _attack_cd > 0.0:
		return
	_attack_cd = 0.3
	energy -= float(triple_cost)
	var fwd := _face_aim()      # apunta el abanico hacia el mouse
	for ang in [-0.22, 0.0, 0.22]:
		_spawn_arrow(fwd.rotated(Vector3.UP, ang), false)
	Sfx.play("fire", -2.0)
	arrow_fired.emit()


func _spawn_arrow(dir: Vector3, pierce: bool) -> void:
	var arrow := Area3D.new()
	arrow.set_script(ARROW_SCRIPT)
	get_tree().current_scene.add_child(arrow)
	arrow.add_to_group("arrow")
	arrow.global_position = global_position + Vector3(0.0, 1.2, 0.0) + dir * 0.6
	arrow.setup(dir, arrow_speed * (1.3 if pierce else 1.0), arrow_damage * (1.8 if pierce else 1.0), pierce)


func _squash() -> void:
	_visual.scale = Vector3(1.2, 0.8, 1.2)
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector3.ONE, 0.15)


# --- IA de combate del compañero (ataques básicos + esquiva) ---
## A partir de esta distancia del líder el compañero deja de caminar y trota.
const ESCOLTA_TROTE := 3.0
## Y a partir de ésta corre más rápido que nadie, para recuperar terreno.
const ESCOLTA_SPRINT := 8.0
## Cuánto se le permite pasarse de run_speed mientras recupera.
const ESCOLTA_SOBREPASO := 1.3


## Velocidad del compañero, acompasada a la del líder.
##
## Iba siempre a walk_speed (4.0) mientras el activo corre a run_speed (7.5) con
## Shift: bastaba con mantener la tecla apretada para dejarlo atrás y perderlo de
## vista, y en la huida de la mina se quedaba con el Chupacabras.
##
## Tres tramos. Al lado camina, para que no vaya dando tirones cuando el líder
## se para. Descolgado corre. Y ya lejos corre un poco MÁS rápido que el
## máximo del jugador, que es la única forma de recortar distancia en vez de
## conservar la que quedó; el sobrepaso se apaga solo a los 8 m, así que nunca
## se le echa encima.
func _velocidad_de_escolta() -> float:
	var lider := _leader()
	if lider == null:
		return walk_speed
	var d := Vector2(lider.global_position.x - global_position.x,
		lider.global_position.z - global_position.z).length()
	if d >= ESCOLTA_SPRINT:
		return run_speed * ESCOLTA_SOBREPASO
	if d >= ESCOLTA_TROTE:
		return run_speed
	# Pegado, pero el líder viene lanzado: igualarle el paso antes de descolgarse,
	# en vez de esperar a estar a tres metros para reaccionar.
	var vl := Vector2(lider.velocity.x, lider.velocity.z).length()
	return clampf(vl, walk_speed, run_speed)


func _ai_behavior() -> Vector3:
	var enemy := _nearest_enemy()
	if enemy != null:
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		# Esquivar telegrafiados
		if enemy.has_method("is_telegraphing") and enemy.is_telegraphing():
			var danger := 2.0
			if enemy.has_method("danger_radius"):
				danger = enemy.danger_radius()
			if dist < danger + 1.2:
				return (-to).normalized()
		var atk_range := 6.5 if is_archer else 1.5
		if dist > atk_range:
			return to.normalized()
		_face(to)
		_ai_attack(enemy)
		if is_archer and dist < 3.5:
			return (-to).normalized()   # el arquero mantiene distancia
		return Vector3.ZERO
	# Sin enemigos: ir al costado del líder (paralelo, no atrás).
	var leader := _leader()
	if leader != null:
		var lv := Vector3(leader.velocity.x, 0.0, leader.velocity.z)
		# Perpendicular derecha al movimiento; si el líder está quieto usa +X global.
		var side: Vector3
		if lv.length() > 0.5:
			side = Vector3.UP.cross(lv.normalized())
		else:
			side = Vector3(1.0, 0.0, 0.0)
		var target := leader.global_position + side * 1.5
		var to := target - global_position
		to.y = 0.0
		if to.length() > 0.4:
			return to.normalized()
	return Vector3.ZERO


func _ai_attack(enemy: Node3D) -> void:
	if _ai_atk_cd > 0.0:
		return
	_ai_atk_cd = ai_attack_cooldown
	if is_archer:
		var d: Vector3 = enemy.global_position - global_position
		d.y = 0.0
		_spawn_arrow(d.normalized(), false)   # básico: flecha normal
		Sfx.play_at("fire", global_position, -9.0)
	else:
		_squash()
		_spawn_melee_hit(melee_damage[0])      # básico: 1 golpe
		Sfx.play_at("punch", global_position, -7.0)


func _nearest_enemy(max_dist := 12.0) -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	if best != null and bd <= max_dist:
		return best
	return null


## Modo QUIETO (tras T): defiende el puesto. Si un enemigo entra en
## defense_radius, se COMPROMETE a derrotarlo (lo persigue hasta guard_leash del
## puesto) antes de volver; luego atiende al siguiente. Emilia se acerca a
## golpear; Benjamín dispara desde el sitio.
func _hold_behavior() -> Vector3:
	# Soltar el objetivo si murió (nodo liberado) o se alejó demasiado del puesto.
	if _guard_target != null and not is_instance_valid(_guard_target):
		_guard_target = null
	if _guard_target != null and _hold_pos.distance_to(_guard_target.global_position) > guard_leash:
		_guard_target = null
	# Adquirir un objetivo nuevo solo si entra al rango de defensa.
	if _guard_target == null:
		_guard_target = _nearest_enemy(defense_radius)

	if _guard_target != null:
		var to: Vector3 = _guard_target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if _guard_target.has_method("is_telegraphing") and _guard_target.is_telegraphing():
			var danger := 2.0
			if _guard_target.has_method("danger_radius"):
				danger = _guard_target.danger_radius()
			if dist < danger + 0.8:
				return (-to).normalized()
		if is_archer:
			_face(to)
			_ai_attack(_guard_target)   # dispara desde el sitio
			return Vector3.ZERO
		if dist > 1.4:
			return to.normalized()      # Emilia se acerca a rematar
		_face(to)
		_ai_attack(_guard_target)
		return Vector3.ZERO

	# Sin objetivo: volver al puesto.
	var back := _hold_pos - global_position
	back.y = 0.0
	if back.length() > 0.4:
		return back.normalized()
	return Vector3.ZERO


## ¿Hay piso ~1.1m adelante en 'dir'? Evita que la IA/guardia se tire a un vacío.
func _has_ground_ahead(dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + dir.normalized() * 1.1 + Vector3(0.0, 0.5, 0.0)
	var to := from + Vector3(0.0, -2.0, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1        # entorno
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	return not hit.is_empty()


func _leader() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p != self and p.get("active"):
			return p
	return null


# --- Interacción (llamado por Interactable.gd) ---
func set_interactable(node: Node) -> void:
	_interactable = node
	if hud and hud.has_method("show_prompt"):
		var text: String = node.prompt if "prompt" in node else "[E] Interactuar"
		hud.show_prompt(text)


func clear_interactable(node: Node) -> void:
	if _interactable == node:
		_interactable = null
		if hud and hud.has_method("hide_prompt"):
			hud.hide_prompt()


# --- Control (party/swap) ---
func set_active(a: bool) -> void:
	active = a
	var cam := get_node_or_null("Camera") as Camera3D
	if cam:
		cam.current = a
	if not a:
		velocity.x = 0.0
		velocity.z = 0.0
		_charging = false
		if hud and hud.has_method("hide_prompt"):
			hud.hide_prompt()
		_interactable = null


## true = IA de combate (pelea solo); false = QUIETO/guardia (defiende su puesto).
func set_ai_mode(combat: bool) -> void:
	ai_mode = AiMode.COMBAT if combat else AiMode.FROZEN
	_guard_target = null
	if not combat:
		_hold_pos = global_position   # fija el puesto a defender
		velocity.x = 0.0
		velocity.z = 0.0


# --- Vida ---
func take_damage(amount: float, _from: Vector3 = Vector3.ZERO) -> void:
	if health <= 0:
		return
	health = max(0, health - int(round(amount)))
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()


func heal(amount: int) -> void:
	health = min(max_health, health + amount)
	health_changed.emit(health, max_health)


func is_dead() -> bool:
	return health <= 0


func _banner(text: String) -> void:
	if hud and hud.has_method("show_banner"):
		hud.show_banner(text)


## Orienta al personaje hacia un rumbo, en radianes.
##
## Sigue la convención de Godot y la del resto de este script: yaw 0 mira a -Z.
## Lo usa Game al colocar la party en un punto de aparición, para que el rumbo
## del Marker3D se respete en vez de arrastrar el que traía de la zona anterior.
func orientar_hacia(yaw: float) -> void:
	if _visual != null:
		_visual.rotation.y = yaw
