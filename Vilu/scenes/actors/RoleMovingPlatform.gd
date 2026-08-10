extends AnimatableBody3D

## Plataforma móvil ligada a UN personaje: solo se mueve si el que va encima es
## del rol correcto (Emilia = melee, Benjamín = arquero). Si sube el otro, no se
## mueve. Detecta al pasajero con el Area hija "Rider". collision_layer 1.

@export var for_archer := false   # false = solo Emilia (melee); true = solo Benjamín (arquero)
@export var dock: NodePath
@export var dest: NodePath
@export var speed := 4.0

var _t := 0.0

@onready var _dock: Node3D = get_node_or_null(dock)
@onready var _dest: Node3D = get_node_or_null(dest)
@onready var _rider: Area3D = get_node_or_null("Rider")


func _physics_process(delta: float) -> void:
	if _dock == null or _dest == null:
		return
	var target := 1.0 if _has_right_rider() else 0.0
	var d := _dock.global_position.distance_to(_dest.global_position)
	if d > 0.01:
		_t = move_toward(_t, target, (speed / d) * delta)
	global_position = _dock.global_position.lerp(_dest.global_position, _t)


func _has_right_rider() -> bool:
	if _rider == null:
		return false
	for b in _rider.get_overlapping_bodies():
		if b.is_in_group("player") and "is_archer" in b and b.is_archer == for_archer:
			return true
	return false
