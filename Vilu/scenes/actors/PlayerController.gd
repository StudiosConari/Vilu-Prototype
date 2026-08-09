extends CharacterBody3D

## Controlador del Player (greybox). Movimiento cenital (WASD relativo al mundo),
## correr (Shift), salto (Espacio). Combate desbloqueado por Carmen (has_bow):
## clic izq = combo melee (cadena de 3 con ventana de input), clic der = flecha.
## Interacción con [T]. Solo el nodo Visual rota para encarar (-Z adelante); el
## cuerpo queda alineado para que la cámara hija no gire. Habilidades =
## ESTADOS (planeo con alas, montura guanaco), no arte.

signal health_changed(current: int, maximum: int)
signal died
signal melee_hit(step: int)      # paso de combo alcanzado (0..N-1); N-1 = combo completo
signal arrow_fired

const ARROW_SCRIPT := preload("res://scenes/Arrow.gd")

@export_group("Movimiento")
@export var walk_speed := 4.0
@export var run_speed := 7.5
@export var acceleration := 12.0
@export var jump_velocity := 6.0
@export var gravity := 18.0
@export var turn_speed := 14.0

@export_group("Rol")
@export var is_archer := false     # false = melee (combos); true = arquero (flechas)

@export_group("Vida")
@export var max_health := 100

@export_group("Combate")
@export var combo_window := 0.6
@export var attack_cooldown := 0.28
@export var melee_damage: Array[float] = [8.0, 8.0, 14.0]
@export var melee_range := 1.1
@export var arrow_speed := 26.0
@export var arrow_damage := 10.0

var health: int
var input_locked := false
var active := true          # false = personaje inactivo del party (no recibe input)

# Estados de habilidad (activados desde beats posteriores).
var can_glide := false
var glide_gravity_scale := 0.35
var mounted := false

# Interacción
var hud: CanvasLayer
var _interactable: Node = null

@onready var _visual: Node3D = $Visual

var _jump_held_prev := false
var _t_held_prev := false
var _q_held_prev := false
var _combo_step := 0
var _combo_timer := 0.0
var _attack_cd := 0.0


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	# Bloquear input mientras haya diálogo abierto (el balloon no pausa el árbol).
	DialogueManager.dialogue_started.connect(func(_r: Resource) -> void: input_locked = true)
	DialogueManager.dialogue_ended.connect(func(_r: Resource) -> void: input_locked = false)
	# Habilidades como estados: alas = planeo pasivo. Sincronizar del progreso.
	can_glide = GameManager.has_ability("wings")
	GameManager.ability_unlocked.connect(_on_ability_unlocked)


func _on_ability_unlocked(ability: String) -> void:
	if ability == "wings":
		can_glide = true


func _physics_process(delta: float) -> void:
	_combo_timer = max(0.0, _combo_timer - delta)
	_attack_cd = max(0.0, _attack_cd - delta)

	# --- Gravedad (con planeo opcional si tiene alas) ---
	if not is_on_floor():
		var g := gravity
		if can_glide and Input.is_physical_key_pressed(KEY_SPACE) and velocity.y < 0.0:
			g *= glide_gravity_scale
		velocity.y -= g * delta

	# --- Entrada de movimiento ---
	var controllable := active and not input_locked
	var dir := Vector3.ZERO
	if controllable:
		if Input.is_physical_key_pressed(KEY_W): dir.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S): dir.z += 1.0
		if Input.is_physical_key_pressed(KEY_A): dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): dir.x += 1.0
		dir = dir.normalized()

		# Salto (flanco)
		var jump_held := Input.is_physical_key_pressed(KEY_SPACE)
		if jump_held and not _jump_held_prev and is_on_floor():
			velocity.y = jump_velocity * (1.15 if mounted else 1.0)
		_jump_held_prev = jump_held

		# Interacción (flanco de T)
		var t_held := Input.is_physical_key_pressed(KEY_T)
		if t_held and not _t_held_prev and _interactable != null and _interactable.has_method("interact"):
			_interactable.interact(self)
		_t_held_prev = t_held

		# Montura guanaco (toggle con Q; solo si se desbloqueó)
		if GameManager.has_ability("guanaco"):
			var q_held := Input.is_physical_key_pressed(KEY_Q)
			if q_held and not _q_held_prev:
				mounted = not mounted
			_q_held_prev = q_held

	var speed := run_speed if (controllable and Input.is_physical_key_pressed(KEY_SHIFT)) else walk_speed
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


func _unhandled_input(event: InputEvent) -> void:
	if input_locked or not active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not GameManager.has_ability("bow"):
			return  # el combate lo entrega Carmen
		# Cada personaje tiene UN estilo: el arquero dispara, el melee encadena combos.
		if is_archer:
			_shoot_arrow()
		else:
			_melee_attack()


# --- Dirección de encare en el mundo (-Z del Visual) ---
func _facing() -> Vector3:
	return (-_visual.global_transform.basis.z).normalized()


func _melee_attack() -> void:
	if _attack_cd > 0.0:
		return
	if _combo_timer > 0.0 and _combo_step < melee_damage.size() - 1:
		_combo_step += 1
	else:
		_combo_step = 0
	_combo_timer = combo_window
	_attack_cd = attack_cooldown

	var dmg: float = melee_damage[_combo_step]
	Sfx.play("punch" if _combo_step < 2 else "kick", -3.0, 1.0 + _combo_step * 0.12)
	_squash()
	_spawn_melee_hit(dmg)
	melee_hit.emit(_combo_step)


func _spawn_melee_hit(dmg: float) -> void:
	var hit := Area3D.new()
	hit.collision_mask = 4  # capa de enemigos
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
		if b.is_in_group("enemies") and b.has_method("take_damage"):
			b.take_damage(dmg, hit_pos, 5.0))
	get_tree().create_timer(0.12).timeout.connect(hit.queue_free)


func _shoot_arrow() -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = 0.2
	var fwd := _facing()
	var arrow := Area3D.new()
	arrow.set_script(ARROW_SCRIPT)
	get_tree().current_scene.add_child(arrow)
	arrow.add_to_group("arrow")
	arrow.global_position = global_position + Vector3(0.0, 1.2, 0.0) + fwd * 0.6
	arrow.setup(fwd, arrow_speed, arrow_damage, false)
	Sfx.play("fire", -3.0)
	arrow_fired.emit()


func _squash() -> void:
	_visual.scale = Vector3(1.2, 0.8, 1.2)
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector3.ONE, 0.15)


# --- Interacción (llamado por Interactable.gd) ---
func set_interactable(node: Node) -> void:
	_interactable = node
	if hud and hud.has_method("show_prompt"):
		var text: String = node.prompt if "prompt" in node else "[T] Interactuar"
		hud.show_prompt(text)


func clear_interactable(node: Node) -> void:
	if _interactable == node:
		_interactable = null
		if hud and hud.has_method("hide_prompt"):
			hud.hide_prompt()


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


## Activa/desactiva el control de este personaje (sistema de party/swap).
## El activo toma input y su cámara pasa a current; el inactivo se queda quieto.
func set_active(a: bool) -> void:
	active = a
	var cam := get_node_or_null("Camera") as Camera3D
	if cam:
		cam.current = a
	if not a:
		velocity.x = 0.0
		velocity.z = 0.0
		if hud and hud.has_method("hide_prompt"):
			hud.hide_prompt()
		_interactable = null
