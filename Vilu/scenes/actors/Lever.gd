extends Area3D

## Palanca que Emilia (o quien sea) activa con [E]. Emite 'activated' una vez.
## Requiere collision_mask con la capa del jugador (2).

signal activated

@export var prompt := "[E] Activar palanca"

var _done := false
var _mat: StandardMaterial3D

@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.9, 0.85, 0.2)
	if _mesh:
		_mesh.material_override = _mat


func _on_enter(body: Node3D) -> void:
	if not _done and body.is_in_group("player") and body.has_method("set_interactable"):
		body.set_interactable(self)


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("clear_interactable"):
		body.clear_interactable(self)


func interact(player: Node) -> void:
	if _done:
		return
	_done = true
	if _mat:
		_mat.albedo_color = Color(0.2, 0.9, 0.3)
	if player.has_method("clear_interactable"):
		player.clear_interactable(self)
	activated.emit()


func is_done() -> bool:
	return _done
