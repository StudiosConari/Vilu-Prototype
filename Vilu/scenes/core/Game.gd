extends Node3D

## Raíz jugable del MVP. Contenedor persistente: entorno, luz, un holder de
## región y el Player. Delega la carga de región en TravelManager y lee el
## progreso de GameManager. El Player se instancia una vez y persiste entre
## regiones (se re-posiciona en el spawn de cada región al viajar).

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")

@onready var _region_holder: Node3D = $RegionHolder

var player: CharacterBody3D
var hud: CanvasLayer

## Party controlable (personajes con swap). Beats 1-4 tienen 1; el Ascenso
## agrega un compañero. Solo el activo recibe input y tiene cámara current.
var party: Array = []
var active_index := 0


func _ready() -> void:
	var region := TravelManager.load_region(_region_holder, "Region1_Tarapaca")
	_spawn_player(region)
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	player.hud = hud
	hud.bind_player(player)


func _spawn_player(region: Node) -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	party = [player]
	active_index = 0
	_apply_active()
	_move_to_spawn(region)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			swap_character()


## Cambia al siguiente personaje del party (no-op si hay 1 solo).
func swap_character() -> void:
	if party.size() <= 1:
		return
	active_index = (active_index + 1) % party.size()
	_apply_active()


func add_party_member(character: Node) -> void:
	if character in party:
		return
	if "hud" in character:
		character.hud = hud
	party.append(character)
	# Re-asegura cámaras/estado: el nuevo Player trae su cámara con current=true
	# y le robaría la vista al activo; _apply_active deja solo la del activo.
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


## Coloca al Player en el Marker3D "PlayerSpawn" de la región (si existe).
func _move_to_spawn(region: Node) -> void:
	if region == null:
		return
	var spawn := region.get_node_or_null("PlayerSpawn") as Node3D
	if spawn != null:
		player.global_position = spawn.global_position
		player.velocity = Vector3.ZERO


## Viaja a otra zona/región (con fundido) y reubica al Player en su spawn.
## Llamado por ZoneExit al entrar el Player en una salida.
func go_to(region_name: String) -> void:
	var region := await TravelManager.travel_to(_region_holder, region_name)
	_move_to_spawn(region)
