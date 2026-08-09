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


func _ready() -> void:
	var region := TravelManager.load_region(_region_holder, "Region1_Tarapaca")
	_spawn_player(region)
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.bind_player(player)
	player.hud = hud


func _spawn_player(region: Node) -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	_move_to_spawn(region)


## Coloca al Player en el Marker3D "PlayerSpawn" de la región (si existe).
func _move_to_spawn(region: Node) -> void:
	if region == null:
		return
	var spawn := region.get_node_or_null("PlayerSpawn") as Node3D
	if spawn != null:
		player.global_position = spawn.global_position
