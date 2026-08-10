extends Area3D

## Cuerda que un personaje "arriba" lanza por el borde. Se ARMA cuando el
## controlador lo indica (p.ej. Emilia llegó a la plataforma). Entonces el otro
## personaje, parado en la base y pulsando [E], sube al top_marker.
## Requiere collision_mask con la capa del jugador (2).

signal climbed(player: Node)

@export var prompt := "[E] Subir por la cuerda"
@export var top_marker: NodePath

var armed := false

@onready var _mesh: Node3D = get_node_or_null("Mesh")


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_show(false)


func arm(on := true) -> void:
	armed = on
	_show(on)
	if on:
		# Si ya hay alguien en la base, mostrarle el prompt de una.
		for b in get_overlapping_bodies():
			if b.is_in_group("player") and b.has_method("set_interactable"):
				b.set_interactable(self)


func _show(v: bool) -> void:
	if _mesh:
		_mesh.visible = v


func _on_enter(body: Node3D) -> void:
	if armed and body.is_in_group("player") and body.has_method("set_interactable"):
		body.set_interactable(self)


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("clear_interactable"):
		body.clear_interactable(self)


# Llamado por el Player al pulsar [E].
func interact(player: Node) -> void:
	if not armed:
		return
	var m := get_node_or_null(top_marker) as Node3D
	if m != null and "global_position" in player:
		player.global_position = m.global_position
		player.velocity = Vector3.ZERO
	if player.has_method("clear_interactable"):
		player.clear_interactable(self)
	climbed.emit(player)
