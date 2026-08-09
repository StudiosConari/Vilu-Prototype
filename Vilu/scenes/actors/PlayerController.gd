extends CharacterBody3D

## Controlador del Player para el núcleo jugable (greybox). Movimiento en el
## plano (WASD relativo al mundo, la cámara es de ángulo fijo cenital), correr
## con Shift, salto con Espacio. Solo el nodo Visual rota para encarar el
## movimiento (-Z adelante); el cuerpo se mantiene alineado para que la cámara
## hija no gire. Preparado para extenderse con habilidades como ESTADOS
## (arco/alas/guanaco) segun el contrato — no como arte.

signal health_changed(current: int, maximum: int)
signal died

@export_group("Movimiento")
@export var walk_speed := 4.0
@export var run_speed := 7.5
@export var acceleration := 12.0
@export var jump_velocity := 6.0
@export var gravity := 18.0
@export var turn_speed := 14.0

@export_group("Vida")
@export var max_health := 100

var health: int

# Estados de habilidad (se activan desde GameManager en beats posteriores).
var can_glide := false      # alas: menor gravedad al mantener salto
var glide_gravity_scale := 0.35
var mounted := false        # guanaco: montura (mas velocidad/salto)

@onready var _visual: Node3D = $Visual

var _jump_held_prev := false


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	# --- Gravedad (con planeo opcional si tiene alas) ---
	if not is_on_floor():
		var g := gravity
		if can_glide and Input.is_physical_key_pressed(KEY_SPACE) and velocity.y < 0.0:
			g *= glide_gravity_scale
		velocity.y -= g * delta

	# --- Salto (deteccion de flanco) ---
	var jump_held := Input.is_physical_key_pressed(KEY_SPACE)
	if jump_held and not _jump_held_prev and is_on_floor():
		velocity.y = jump_velocity * (1.15 if mounted else 1.0)
	_jump_held_prev = jump_held

	# --- Direccion de entrada (relativa al mundo; -Z = lejos de la camara) ---
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): dir.x += 1.0
	dir = dir.normalized()

	var speed := run_speed if Input.is_physical_key_pressed(KEY_SHIFT) else walk_speed
	if mounted:
		speed *= 1.5

	var target_vx := dir.x * speed
	var target_vz := dir.z * speed
	velocity.x = move_toward(velocity.x, target_vx, acceleration * speed * delta)
	velocity.z = move_toward(velocity.z, target_vz, acceleration * speed * delta)

	move_and_slide()

	# --- Encarar el movimiento (solo el Visual rota; -Z adelante) ---
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() > 0.15:
		var target_yaw := atan2(-hv.x, -hv.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, turn_speed * delta)


## API para combate/daño (usada en beats posteriores).
func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = max(0, health - amount)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()


func heal(amount: int) -> void:
	health = min(max_health, health + amount)
	health_changed.emit(health, max_health)
