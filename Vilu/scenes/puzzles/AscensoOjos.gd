extends Node3D

## Beat 5 — Ascenso del Ojos del Salado. PLAN B (por turnos, obligatorio como red
## de seguridad): dos personajes controlables (swap con R). Uno debe SOSTENER la
## placa (PlateA) para que el Bridge cruce el vacío; el otro CRUZA hasta la cima.
## Al llegar a la cima se supera el ascenso y se entra al Beat 5.
##
## El compañero se instancia aquí y se registra en el party de Game (swap con R).
## Al superar, se devuelve el control a un solo personaje en la cima.

signal solved

const COMPANION_SCENE := preload("res://scenes/actors/Player.tscn")
const ALLY_MAT := preload("res://art_placeholders/mat_npc.tres")

@export var advance_to_beat := 5

var _companion: Node = null
var _is_solved := false
var _on_plate := 0

@onready var _plate: Area3D = get_node_or_null("PlateA")
@onready var _bridge_mesh: Node3D = get_node_or_null("Bridge/Mesh")
@onready var _bridge_shape: CollisionShape3D = get_node_or_null("Bridge/Shape")
@onready var _summit: Area3D = get_node_or_null("SummitTrigger")


func _ready() -> void:
	_spawn_companion()
	if _plate:
		_plate.body_entered.connect(_on_plate_enter)
		_plate.body_exited.connect(_on_plate_exit)
	if _summit:
		_summit.body_entered.connect(_on_summit)
	_set_bridge(false)
	_banner("Ascenso del Ojos del Salado — uno sostiene la placa, el otro cruza. [R] cambia de personaje")


func _spawn_companion() -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return  # contexto de test sin Game
	_companion = COMPANION_SCENE.instantiate()
	add_child(_companion)
	var sb := get_node_or_null("SpawnB") as Node3D
	if sb:
		_companion.global_position = sb.global_position
	var ph := _companion.get_node_or_null("Visual/Placeholder")
	if ph and ph.has_method("set_surface_override_material"):
		ph.set_surface_override_material(0, ALLY_MAT)  # aliado verde
	if game.has_method("add_party_member"):
		game.add_party_member(_companion)


func _on_plate_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_plate += 1
		_set_bridge(_on_plate > 0)


func _on_plate_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_plate = max(0, _on_plate - 1)
		_set_bridge(_on_plate > 0)


func _set_bridge(up: bool) -> void:
	if _bridge_mesh:
		_bridge_mesh.visible = up
	if _bridge_shape:
		_bridge_shape.set_deferred("disabled", not up)


func _on_summit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_solve()


func _solve() -> void:
	if _is_solved:
		return
	_is_solved = true
	_banner("¡Cima alcanzada! Ascenso del Ojos del Salado superado.", 3.0)
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	# Devolver el control a un solo personaje, ya en la cima.
	var game := get_tree().get_first_node_in_group("game")
	if game and _companion and game.has_method("remove_party_member"):
		game.remove_party_member(_companion)
		_companion.queue_free()
		_companion = null
	var summit_mark := get_node_or_null("SummitMarker") as Node3D
	if game and summit_mark and "player" in game and game.player:
		game.player.global_position = summit_mark.global_position
	solved.emit()


func is_solved() -> bool:
	return _is_solved


func _banner(text: String, auto_clear := 0.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(text)
		if auto_clear > 0.0:
			get_tree().create_timer(auto_clear).timeout.connect(func() -> void:
				if is_instance_valid(hud) and hud.has_method("clear_banner"):
					hud.clear_banner())
