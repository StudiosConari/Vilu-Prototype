extends Node3D

## Raíz jugable del MVP. Contenedor persistente: entorno, luz, un holder de
## región y el PARTY de dos protagonistas (melee + arquero), intercambiables
## con R. Solo el activo recibe input y tiene cámara current. Ambos persisten
## entre regiones (se reubican en el spawn al viajar).

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const WORLD_SCENE := preload("res://scenes/core/World.tscn")
const TOON_SKIN := preload("res://scenes/core/ToonSkin.gd")
const ARCHER_MAT := preload("res://art_placeholders/mat_player_b.tres")

## Zonas que NO son parte del mundo continuo: se cargan aparte al entrar.
const INTERIORES := ["Mina", "Final"]

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
var _cam_override: Node3D = null   # si está seteado, la cámara sigue a este nodo

@export var fall_limit := -8.0   # por debajo de esto = cayó al vacío -> reinicia la zona
var _resetting := false

var player: CharacterBody3D          # personaje primario/activo de referencia
var hud: CanvasLayer
var world: Node3D                    # WorldRoot: todas las zonas al aire libre

var _respawn_pos := Vector3.ZERO      # dónde reaparecer al caer al vacío
var _interior := ""                   # interior abierto ("" = estás en el mundo)
var _volviendo_de := ""               # interior del que se está saliendo
var _pos_antes_interior := Vector3.ZERO

## Party controlable (2 protagonistas). Solo el activo recibe input.
var party: Array = []
var active_index := 0

var _r_prev := false
var _t_prev := false


func _ready() -> void:
	# La historia abre en la fiesta de La Tirana, con Carmen: es la secuencia 1
	# del relato. El Poblado es el centro geográfico del mapa, pero empezar ahí
	# dejaba al jugador parado en mitad de la trama, con la Bruja pidiéndole un
	# talismán que todavía no fue a buscar.
	var start := "Region1_Tarapaca"
	if GameManager.debug_start_zone != "":
		start = GameManager.debug_start_zone
		GameManager.debug_start_zone = ""

	# El mundo abierto (todas las zonas al aire libre) vive siempre.
	world = WORLD_SCENE.instantiate()
	add_child(world)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	_spawn_party_open(start)

	# Arrancar en un interior (Mina/Final) desde el selector de debug.
	if not world.has_zone(start):
		enter_interior(start)

	var act := active_character()
	if act != null:
		_cam_focus = act.global_position + Vector3(0.0, 1.5, 0.0)
	_update_camera()


func _spawn_party_open(zona: String) -> void:
	var a := _make_character(false, null)
	var b := _make_character(true, ARCHER_MAT)
	party = [a, b]
	player = a
	active_index = 0
	for c in party:
		c.hud = hud
	_apply_active()
	_colocar_en(world.spawn_point(zona if world.has_zone(zona) else "Region1_Tarapaca"))
	hud.show_swap_hint(party.size() > 1)


## Reubica al party alrededor de una posición mundial.
func _colocar_en(pos: Vector3) -> void:
	if pos == Vector3.INF:
		return
	var offsets := [Vector3.ZERO, Vector3(2.5, 0, 0), Vector3(-2.5, 0, 0)]
	for i in party.size():
		var off: Vector3 = offsets[i] if i < offsets.size() else Vector3(0, 0, i * 2.0)
		party[i].global_position = pos + off
		party[i].velocity = Vector3.ZERO
	_respawn_pos = pos


func _make_character(is_archer: bool, mat: Material) -> CharacterBody3D:
	var c := PLAYER_SCENE.instantiate()
	c.is_archer = is_archer
	add_child(c)
	if mat != null:
		var ph := c.get_node_or_null("Visual/Placeholder")
		if ph and ph.has_method("set_surface_override_material"):
			ph.set_surface_override_material(0, mat)
	# Mismo sombreado escalonado que el mundo: si no, los protagonistas quedan
	# con luz PBR suave sobre un fondo cel-shaded y se ven pegoteados encima.
	TOON_SKIN.new().aplicar(c)
	return c


func _process(_delta: float) -> void:
	# R = cambiar dejando al otro en IA de combate; T = dejándolo QUIETO (puzzles).
	var r := Input.is_action_pressed("swap_ai")
	if r and not _r_prev:
		_swap(true)
	_r_prev = r
	var t := Input.is_action_pressed("swap_hold")
	if t and not _t_prev:
		_swap(false)
	_t_prev = t
	_update_camera()
	_check_fall()


## Si algún personaje cae al vacío, reaparece el party en el último punto seguro.
func _check_fall() -> void:
	if _resetting:
		return
	for c in party:
		if is_instance_valid(c) and c.global_position.y < fall_limit:
			_respawn()
			return


## MUNDO ABIERTO: ya no existe "recargar la zona actual" — el mundo entero está
## siempre cargado y recargarlo reiniciaría guiones de zonas lejanas. En su
## lugar se devuelve al party al último spawn pisado.
func _respawn() -> void:
	_resetting = true
	if hud and hud.has_method("show_banner"):
		hud.show_banner("Caíste — volvés al último punto seguro")

	var destino := _respawn_pos
	if _interior == "":
		# Preferir el spawn de la zona en la que estaba parado
		var z: String = world.current_zone() if world else ""
		if z != "":
			var sp: Vector3 = world.spawn_point(z)
			if sp != Vector3.INF:
				destino = sp
	_colocar_en(destino)

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
	if event.is_action_pressed("cam_zoom_in"):
		cam_distance = clampf(cam_distance - cam_zoom_step, cam_zoom_min, cam_zoom_max)
	elif event.is_action_pressed("cam_zoom_out"):
		cam_distance = clampf(cam_distance + cam_zoom_step, cam_zoom_min, cam_zoom_max)
	elif event.is_action_pressed("cam_orbit"):
		_cam_rotating = true
	elif event.is_action_released("cam_orbit"):
		_cam_rotating = false
	elif event is InputEventMouseMotion and _cam_rotating:
		_cam_yaw -= event.relative.x * cam_rotate_speed
		_cam_pitch = clampf(_cam_pitch - event.relative.y * cam_rotate_speed, -1.4, -0.15)


## Hace que la cámara siga a otro nodo (un NPC en una escena guionada) en vez
## del personaje activo. Con duration > 0 vuelve sola al jugador al terminar.
func focus_camera_on(node: Node3D, duration := 0.0) -> void:
	_cam_override = node
	if duration > 0.0:
		get_tree().create_timer(duration).timeout.connect(func() -> void:
			if _cam_override == node:
				_cam_override = null)


func clear_camera_focus() -> void:
	_cam_override = null


func _update_camera() -> void:
	var target := active_character()
	if is_instance_valid(_cam_override):
		target = _cam_override
	if target == null or _camera == null:
		return
	_cam_focus = _cam_focus.lerp(target.global_position + Vector3(0.0, 1.5, 0.0), cam_follow_lerp)
	var offset := Vector3(0.0, 0.0, cam_distance)
	offset = offset.rotated(Vector3.RIGHT, _cam_pitch)
	offset = offset.rotated(Vector3.UP, _cam_yaw)
	_camera.global_position = _cam_wall_check(_cam_focus + offset)
	_camera.look_at(_cam_focus, Vector3.UP)


## Raycast desde el foco hacia la posición deseada. Si hay geometría en el camino,
## mueve la cámara hasta el punto de impacto (con un pequeño margen) para que nunca
## atraviese paredes ni techo.
func _cam_wall_check(desired: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(_cam_focus, desired)
	params.collision_mask = 1   # solo entorno (layer 1); jugadores/enemigos ignorados
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return desired
	# Retroceder 0.25 m desde el punto de impacto para evitar z-fighting
	return hit["position"] - (desired - _cam_focus).normalized() * 0.25


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


## Reubica a todo el party cerca del spawn de la región.
## use_travel_spawn=true: prefiere TravelSpawn (fast-travel desde el mapa).
## use_travel_spawn=false: usa siempre PlayerSpawn (salida normal de zona).
func _move_to_spawn(region: Node, use_travel_spawn: bool = false) -> void:
	if region == null:
		return
	var spawn: Node3D = null
	if use_travel_spawn:
		spawn = region.get_node_or_null("TravelSpawn") as Node3D
	if spawn == null:
		spawn = region.get_node_or_null("PlayerSpawn") as Node3D
	if spawn == null:
		return
	var offsets := [Vector3.ZERO, Vector3(2.5, 0, 0), Vector3(-2.5, 0, 0)]
	for i in party.size():
		var off: Vector3 = offsets[i] if i < offsets.size() else Vector3(0, 0, i * 2.0)
		party[i].global_position = spawn.global_position + off
		party[i].velocity = Vector3.ZERO


## Punto de entrada único para "ir a X". Enruta según el tipo de destino:
##   · INTERIOR (Mina, Final)  -> carga la escena aparte, con fundido.
##   · zona del mundo abierto  -> si venías de un interior, sale; si ya estabas
##     en el mundo, es un teletransporte (viaje rápido del mapa de Chile).
## use_travel_spawn elige el marcador TravelSpawn (junto al guardián).
func go_to(region_name: String, use_travel_spawn: bool = false) -> void:
	if hud:
		if hud.has_method("clear_hint"):
			hud.clear_hint()
		if hud.has_method("clear_banner"):
			hud.clear_banner()

	if region_name in INTERIORES:
		await enter_interior(region_name)
	elif _interior != "":
		_volviendo_de = _interior
		await exit_interior(region_name, use_travel_spawn)
		_volviendo_de = ""
	else:
		await teleport_to(region_name, use_travel_spawn)

	for i in party.size():
		if i != active_index and party[i].has_method("set_ai_mode"):
			party[i].set_ai_mode(true)


## Entra a un interior: oculta el mundo y carga la escena en el holder.
func enter_interior(id: String) -> void:
	_pos_antes_interior = active_character().global_position if active_character() else _respawn_pos
	await TravelManager.travel_to_then(_region_holder, id, func(r: Node) -> void:
		_interior = id
		if world:
			world.visible = false
			world.process_mode = Node.PROCESS_MODE_DISABLED
		# El interior se construye recién ahora, así que se lo viste acá.
		if r != null:
			TOON_SKIN.new().aplicar(r)
		_move_to_spawn(r))


## Sale del interior de vuelta al mundo, aterrizando en la zona indicada.
func exit_interior(zona: String, use_travel_spawn := false) -> void:
	await TravelManager.fade_then(func() -> void:
		TravelManager.clear_region(_region_holder)
		_interior = ""
		if world:
			world.visible = true
			world.process_mode = Node.PROCESS_MODE_INHERIT
		# Al salir de la Mina se reaparece frente a su boca (al este del
		# poblado), no en el centro del pueblo: entrás y salís por el mismo lado.
		var destino := Vector3.INF
		if world:
			if _volviendo_de == "Mina" and world.has_method("mine_mouth"):
				destino = world.mine_mouth()
			else:
				var marcador := "TravelSpawn" if use_travel_spawn else "PlayerSpawn"
				destino = world.spawn_point(zona, marcador)
		_colocar_en(destino if destino != Vector3.INF else _pos_antes_interior))


## Teletransporte dentro del mundo abierto (viaje rápido de los Guardianes).
## No hay carga de escena: sólo fundido y reubicación.
func teleport_to(zona: String, use_travel_spawn := false) -> void:
	if world == null or not world.has_zone(zona):
		push_warning("Game: zona desconocida para teletransporte '%s'" % zona)
		return
	var marcador := "TravelSpawn" if use_travel_spawn else "PlayerSpawn"
	var destino: Vector3 = world.spawn_point(zona, marcador)
	await TravelManager.fade_then(func() -> void: _colocar_en(destino))
