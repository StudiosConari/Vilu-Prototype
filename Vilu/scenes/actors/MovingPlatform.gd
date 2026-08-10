extends AnimatableBody3D

## Plataforma móvil. Se mueve del 'dock' al 'dest' mientras un personaje MONTADO
## (Benjamín con guanaco) esté parado sobre ella (detectado por el Area hija
## "Rider"); vuelve al dock si no. Al ser AnimatableBody3D, arrastra al personaje
## que va encima. collision_layer 1 (para que el jugador se pare y viaje).

@export var dock: NodePath      # posición inicial (junto a la plataforma de partida)
@export var dest: NodePath      # destino
@export var speed := 4.0

var _t := 0.0

@onready var _dock: Node3D = get_node_or_null(dock)
@onready var _dest: Node3D = get_node_or_null(dest)
@onready var _rider: Area3D = get_node_or_null("Rider")


func _physics_process(delta: float) -> void:
	if _dock == null or _dest == null:
		return
	var target := 1.0 if _has_mounted_rider() else 0.0
	var d := _dock.global_position.distance_to(_dest.global_position)
	if d > 0.01:
		_t = move_toward(_t, target, (speed / d) * delta)
	global_position = _dock.global_position.lerp(_dest.global_position, _t)


func _has_mounted_rider() -> bool:
	if _rider == null:
		return false
	for b in _rider.get_overlapping_bodies():
		if b.is_in_group("player") and "mounted" in b and b.mounted:
			return true
	return false
