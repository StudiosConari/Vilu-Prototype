extends Node3D

## Raíz jugable del MVP. Contenedor persistente: entorno, luz, un holder de
## región y el PARTY de dos protagonistas (melee + arquero), intercambiables
## con R. Solo el activo recibe input y tiene cámara current. Ambos persisten
## entre regiones (se reubican en el spawn al viajar).

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const ARCHER_MAT := preload("res://art_placeholders/mat_player_b.tres")

@onready var _region_holder: Node3D = $RegionHolder
@onready var _camera: Camera3D = $Camera

@export_group("Cámara")
@export var cam_distance := 18.0
@export var cam_zoom_min := 4.0
@export var cam_zoom_max := 70.0
@export var cam_zoom_step := 3.0
@export var cam_rotate_speed := 0.006
@export var cam_follow_lerp := 0.18

var _cam_yaw := 0.0
var _cam_pitch := -0.6
var _cam_focus := Vector3.ZERO
var _cam_rotating := false

@export var fall_limit := -8.0   # por debajo de esto = cayó al vacío -> reinicia la zona
var _resetting := false

var player: CharacterBody3D          # personaje primario/activo de referencia
var hud: CanvasLayer

## Party controlable (2 protagonistas). Solo el activo recibe input.
var party: Array = []
var active_index := 0

var _r_prev := false
var _t_prev := false


func _ready() -> void:
	var start := "Region1_Tarapaca"
	if GameManager.debug_start_zone != "":
		start = GameManager.debug_start_zone
		GameManager.debug_start_zone = ""
	var region := TravelManager.load_region(_region_holder, start)
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	_spawn_party(region)
	var act := active_character()
	if act != null:
		_cam_focus = act.global_position + Vector3(0.0, 1.5, 0.0)
	_update_camera()


func _spawn_party(region: Node) -> void:
	# A = melee (azul), B = arquero (teal). Ambos desde el inicio.
	var a := _make_character(false, null)
	var b := _make_character(true, ARCHER_MAT)
	party = [a, b]
	player = a
	active_index = 0
	for c in party:
		c.hud = hud
	_apply_active()
	_move_to_spawn(region)
	hud.show_swap_hint(party.size() > 1)


func _make_character(is_archer: bool, mat: Material) -> CharacterBody3D:
	var c := PLAYER_SCENE.instantiate()
	c.is_archer = is_archer
	add_child(c)
	if mat != null:
		var ph := c.get_node_or_null("Visual/Placeholder")
		if ph and ph.has_method("set_surface_override_material"):
			ph.set_surface_override_material(0, mat)
	return c


func _process(_delta: float) -> void:
	# R = cambiar dejando al otro en IA de combate; T = dejándolo QUIETO (puzzles).
	var r := Input.is_physical_key_pressed(KEY_R)
	if r and not _r_prev:
		_swap(true)
	_r_prev = r
	var t := Input.is_physical_key_pressed(KEY_T)
	if t and not _t_prev:
		_swap(false)
	_t_prev = t
	_update_camera()
	_check_fall()


## Si algún personaje cae al vacío, reinicia la zona actual (recarga + respawn).
func _check_fall() -> void:
	if _resetting:
		return
	for c in party:
		if is_instance_valid(c) and c.global_position.y < fall_limit:
			_reset_zone()
			return


func _reset_zone() -> void:
	if TravelManager.current_region == "":
		return
	_resetting = true
	if hud and hud.has_method("show_banner"):
		hud.show_banner("Caíste — reiniciando la zona")
	var region := TravelManager.load_region(_region_holder, TravelManager.current_region)
	_move_to_spawn(region)
	for c in party:
		if c.has_method("set_ai_mode"):
			c.set_ai_mode(true)
		if c.has_method("heal"):
			c.heal(c.max_health)
	_apply_active()
	if hud and hud.has_method("clear_banner"):
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if is_instance_valid(hud) and hud.has_method("clear_banner"):
				hud.clear_banner())
	_resetting = false


func _unhandled_input(event: InputEvent) -> void:
	# Cámara: rueda = zoom, clic derecho (arrastrar) = orbitar alrededor del activo.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_distance = clampf(cam_distance - cam_zoom_step, cam_zoom_min, cam_zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_distance = clampf(cam_distance + cam_zoom_step, cam_zoom_min, cam_zoom_max)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cam_rotating = event.pressed
	elif event is InputEventMouseMotion and _cam_rotating:
		_cam_yaw -= event.relative.x * cam_rotate_speed
		_cam_pitch = clampf(_cam_pitch - event.relative.y * cam_rotate_speed, -1.4, -0.15)


func _update_camera() -> void:
	var target := active_character()
	if target == null or _camera == null:
		return
	_cam_focus = _cam_focus.lerp(target.global_position + Vector3(0.0, 1.5, 0.0), cam_follow_lerp)
	var offset := Vector3(0.0, 0.0, cam_distance)
	offset = offset.rotated(Vector3.RIGHT, _cam_pitch)
	offset = offset.rotated(Vector3.UP, _cam_yaw)
	_camera.global_position = _cam_focus + offset
	_camera.look_at(_cam_focus, Vector3.UP)


## Compat: cambia dejando al otro en IA de combate.
func swap_character() -> void:
	_swap(true)


func _swap(combat: bool) -> void:
	if party.size() <= 1:
		return
	var leaving := active_character()
	active_index = (active_index + 1) % party.size()
	_apply_active()
	if leaving != null and leaving.has_method("set_ai_mode"):
		leaving.set_ai_mode(combat)


func add_party_member(character: Node) -> void:
	if character in party:
		return
	if "hud" in character:
		character.hud = hud
	party.append(character)
	_apply_active()
	if hud and hud.has_method("show_swap_hint"):
		hud.show_swap_hint(party.size() > 1)


func remove_party_member(character: Node) -> void:
	party.erase(character)
	if active_index >= party.size():
		active_index = 0
	_apply_active()
	if hud and hud.has_method("show_swap_hint"):
		hud.show_swap_hint(party.size() > 1)


func active_character() -> Node:
	return party[active_index] if active_index < party.size() else null


func _apply_active() -> void:
	for i in party.size():
		party[i].set_active(i == active_index)
	var act := active_character()
	if act != null and hud != null:
		hud.bind_player(act)


## Reubica a todo el party cerca del Marker3D "PlayerSpawn" de la región.
func _move_to_spawn(region: Node) -> void:
	if region == null:
		return
	var spawn := region.get_node_or_null("PlayerSpawn") as Node3D
	if spawn == null:
		return
	var offsets := [Vector3.ZERO, Vector3(2.5, 0, 0), Vector3(-2.5, 0, 0)]
	for i in party.size():
		var off: Vector3 = offsets[i] if i < offsets.size() else Vector3(0, 0, i * 2.0)
		party[i].global_position = spawn.global_position + off
		party[i].velocity = Vector3.ZERO


## Viaja a otra zona/región (con fundido) y reubica al party en su spawn.
func go_to(region_name: String) -> void:
	# Limpiar avisos/instrucciones de la zona anterior.
	if hud:
		if hud.has_method("clear_hint"):
			hud.clear_hint()
		if hud.has_method("clear_banner"):
			hud.clear_banner()
	var region := await TravelManager.travel_to(_region_holder, region_name)
	_move_to_spawn(region)
	# Al cambiar de zona, el compañero vuelve a IA de combate (no se queda
	# "congelado" corriendo hacia un puesto de la zona anterior).
	for i in party.size():
		if i != active_index and party[i].has_method("set_ai_mode"):
			party[i].set_ai_mode(true)
