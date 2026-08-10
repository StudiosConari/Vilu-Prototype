extends AnimatableBody3D

## Ascensor vertical. Arranca INACTIVO (quieto en su base). Al ACTIVARSE (por el
## cubo del OTRO personaje) oscila hacia arriba y abajo (sube y baja) para que el
## personaje se suba y viaje al piso de arriba. Arrastra a quien va encima.
## collision_layer 1.

@export var active := false
@export var travel := 6.0     # cuánto sube desde la base
@export var speed := 1.1      # velocidad de la oscilación

var _t := 0.0
var _base := Vector3.ZERO


func _ready() -> void:
	_base = position


func set_active(on: bool) -> void:
	active = on


func is_active() -> bool:
	return active


func _physics_process(delta: float) -> void:
	if active:
		_t += delta
		# (1 - cos)/2 va 0 -> 1 -> 0: arranca abajo, sube y vuelve.
		position.y = _base.y + (1.0 - cos(_t * speed)) * 0.5 * travel
	else:
		position.y = move_toward(position.y, _base.y, 4.0 * delta)
