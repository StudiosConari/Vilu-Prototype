extends Node3D

## Raíz jugable del MVP. Contenedor persistente: entorno, luz, un holder de
## región y el PARTY de dos protagonistas (melee + arquero), intercambiables
## con R. Solo el activo recibe input y tiene cámara current. Ambos persisten
## entre regiones (se reubican en el spawn al viajar).

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const ARCHER_MAT := preload("res://art_placeholders/mat_player_b.tres")

@onready var _region_holder: Node3D = $RegionHolder

var player: CharacterBody3D          # personaje primario/activo de referencia
var hud: CanvasLayer

## Party controlable (2 protagonistas). Solo el activo recibe input/cámara.
var party: Array = []
var active_index := 0

var _r_prev := false
var _t_prev := false


func _ready() -> void:
	var region := TravelManager.load_region(_region_holder, "Region1_Tarapaca")
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	_spawn_party(region)


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
